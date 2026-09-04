-- Mermaid helpers for ```mermaid fences in markdown and standalone `mermaid`
-- buffers (attached from after/ftplugin/{markdown,mermaid}.lua).
--
-- Two renderers, both on demand and neither touching the buffer text:
--   * text (uppercase keys) — pipe the fence under the cursor through a
--     stdin→stdout CLI (`termaid`; `M.opts.cmd` is the whole coupling) into a
--     float or virtual lines below the fence, ANSI colours translated to
--     highlight groups. Works wherever the CLI runs — Termux and SSH included.
--   * image (lowercase keys) — render the fence to a PNG with a second CLI
--     (`M.opts.image_cmds`, first on PATH wins: mermaidx, the real mermaid.js
--     in an embedded JS engine, else the pure-Rust mmdr; no browser either
--     way), themed from the colorscheme, then hand the PNG to snacks.image's
--     placement API. snacks' own automatic doc modes are switched off in
--     lazyvim-adjustments/snacks.lua so nothing pops up on its own. The float
--     works in any kitty-graphics terminal (Zellij included); inline needs
--     unicode placeholders, so bare Ghostty only until Zellij ships them.
--     PNGs are cached on disk by content, so a diagram is rendered once and
--     every later view is a file read; the cache sweeps itself (M.opts.cache).

local api = vim.api

local M = {}

M.opts = {
    -- Renderer: reads mermaid on stdin, prints text on stdout, ANSI colours
    -- welcome (see the ANSI section below). `{width}` is replaced with the
    -- available width in columns and `{theme}` with `text_theme` for the
    -- current 'background' (the pair is dropped when that is nil). The tighter
    -- gap/padding roughly halve the height of termaid's default layout, which
    -- matters when the drawing sits inline below the fence.
    cmd = { "termaid", "--width", "{width}", "--gap", "2", "--padding-y", "1", "--theme", "{theme}" },
    -- termaid only colours its output when a theme is set (needs its `rich`
    -- extra). `default` colour-codes the drawing itself — cyan borders and
    -- edges, yellow arrowheads, bold white labels — from the 16-colour palette,
    -- so it follows the colorscheme's terminal colours; mermaid's own classDef /
    -- style / linkStyle colours layer on top. `mono` is bold-only, and the
    -- "solid" themes (nord, gruvbox, …) paint node backgrounds but override
    -- classDef fills. `termaid --themes` lists them all. Tag nodes with
    -- `:::name` or one `class X name` per line — 0.8 ignores `class A,B name`.
    text_theme = { dark = "default", light = "terra" },
    -- Image renderers, first one on PATH wins. Each must write a PNG to
    -- `{file}` from the mermaid file `{src}`. `{theme}` is mermaid's built-in
    -- base theme for the current 'background' (dark / default), `{config}` a
    -- mermaid config JSON whose themeVariables come from the colorscheme
    -- (image_theme below) and override the base, `{background}` the editor
    -- background. mermaid-cli takes the same shape if ever wanted:
    -- { "mmdc", "-i", "{src}", "-o", "{file}", "-t", "{theme}", "-c", "{config}", "-b", "{background}", "-s", "2" }
    image_cmds = {
        -- the real mermaid.js in an embedded JS engine (QuickJS + resvg), no
        -- browser: full syntax, kanban / mindmap palettes; about a second on
        -- a first render, cached after that
        { "mermaidx", "-q", "-i", "{src}", "-o", "{file}", "-t", "{theme}", "-c", "{config}", "-b", "{background}" },
        -- pure-Rust reimplementation: milliseconds, but uniform kanban columns
        -- and stricter parsing
        { "mmdr", "-i", "{src}", "-o", "{file}", "-e", "png", "-t", "{theme}", "-c", "{config}" },
    },
    -- Appended when a canvas size in pixels is wanted (the float asks for the
    -- size of its box, so the drawing is scaled up to fit it). Same flags for
    -- all of the renderers above.
    image_size = { "-w", "{width}", "-H", "{height}" },
    -- The PNG cache (stdpath("cache")/mermaid). A hit touches its files, so
    -- `max_age_days` counts from the last time a diagram was *viewed*, not
    -- from the render — a diagram you keep coming back to never expires, one
    -- you edited away from is gone a fortnight later. The sweep runs at most
    -- once per nvim session and once per `sweep_every_hours` across sessions
    -- (a stamp file in the cache is the clock), deferred by `sweep_delay_ms`
    -- past the buffer attaching so it never competes with opening a file.
    cache = { max_age_days = 14, sweep_every_hours = 24, sweep_delay_ms = 2000 },
}

local ns = api.nvim_create_namespace("mermaid_inline")
-- Same look as markview's code blocks; falls through to plain text elsewhere.
api.nvim_set_hl(0, "MermaidInline", { link = "MarkviewCode", default = true })

local function notify(msg, level)
    vim.notify(msg, level or vim.log.levels.WARN, { title = "Mermaid" })
end

---------------------------------------------------------------------------
-- Fence lookup
---------------------------------------------------------------------------

---@class mermaid.Fence
---@field src string diagram source; fence markers and any list/blockquote prefix stripped
---@field start_row integer 0-based row of the opening fence (0 for a whole-buffer diagram)
---@field end_row integer 0-based row of the closing fence (last line for a whole-buffer diagram)
---@field indent integer display width of the prefix the fence sits behind

local fence_query -- parsed lazily: the markdown parser may not exist at require time

--- Strip the opening fence's list/blockquote prefix from one content line.
local function strip_prefix(line, prefix)
    if prefix == "" then
        return line
    end
    if line:sub(1, #prefix) == prefix then
        return line:sub(#prefix + 1)
    end
    -- Shorter or blank continuation lines (blockquotes often drop the trailing
    -- space): remove whatever leading indent/quote markers there are, but never
    -- more than the prefix's length, so indentation-sensitive diagrams survive.
    local lead = line:match("^[%s>]*")
    return line:sub(math.min(#lead, #prefix) + 1)
end

--- Every ```mermaid fence in the buffer, or the whole buffer for the `mermaid`
--- filetype.
---@return mermaid.Fence[]
local function fences(buf)
    if vim.bo[buf].filetype == "mermaid" then
        local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
        return { { src = table.concat(lines, "\n"), start_row = 0, end_row = #lines - 1, indent = 0 } }
    end
    local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
    if not ok or not parser then
        return {}
    end
    fence_query = fence_query
        or vim.treesitter.query.parse("markdown", "(fenced_code_block (info_string (language) @lang)) @block")
    parser:parse(true)
    local found = {}
    for _, tree in pairs(parser:trees()) do
        for _, match in fence_query:iter_matches(tree:root(), buf, 0, -1) do
            local block, lang
            for id, nodes in pairs(match) do
                local name = fence_query.captures[id]
                if name == "block" then
                    block = nodes[1]
                elseif name == "lang" then
                    lang = nodes[1]
                end
            end
            if vim.treesitter.get_node_text(lang, buf) == "mermaid" then
                local sr, _, er, ec = block:range()
                if ec == 0 then
                    er = er - 1 -- the node's range ends at the start of the next line
                end
                local lines = api.nvim_buf_get_lines(buf, sr, er + 1, false)
                local prefix = lines[1]:match("^[%s>]*")
                local last = #lines
                if not lines[last]:match("^[%s>]*[`~][`~][`~]") then
                    last = last + 1 -- unclosed fence (still being typed): keep its final line
                end
                local src = {}
                for i = 2, last - 1 do
                    src[#src + 1] = strip_prefix(lines[i], prefix)
                end
                found[#found + 1] = {
                    src = table.concat(src, "\n"),
                    start_row = sr,
                    end_row = er,
                    indent = vim.fn.strdisplaywidth(prefix),
                }
            end
        end
    end
    return found
end

--- The fence containing 0-based `row`, if any.
---@return mermaid.Fence?
local function fence_at(buf, row)
    for _, fence in ipairs(fences(buf)) do
        if row >= fence.start_row and row <= fence.end_row then
            return fence
        end
    end
    return nil
end

--- The fence under the cursor, warning when there is none.
---@return integer buf, mermaid.Fence? fence
local function current_fence()
    local buf = api.nvim_get_current_buf()
    local fence = fence_at(buf, api.nvim_win_get_cursor(0)[1] - 1)
    if not fence then
        notify("No ```mermaid fence under the cursor")
    end
    return buf, fence
end

---------------------------------------------------------------------------
-- ANSI colour → highlight chunks
---------------------------------------------------------------------------

-- The text renderers colour their output with SGR escape sequences: a palette
-- theme plus mermaid's own classDef / style / linkStyle colours. A normal
-- buffer can't show those, so each distinct fg/bg/attribute combination
-- becomes a highlight group created on demand.

---@alias mermaid.Chunk {[1]: string, [2]?: string} text and its highlight group

local ansi_groups = {} ---@type table<string, string> SGR state key → group name
api.nvim_create_autocmd("ColorScheme", {
    group = api.nvim_create_augroup("MermaidAnsi", { clear = true }),
    callback = function()
        ansi_groups = {} -- `hi clear` dropped them; recreate on the next render
    end,
})

local base16 = {
    "#000000",
    "#cd3131",
    "#0dbc79",
    "#e5e510",
    "#2472c8",
    "#bc3fbc",
    "#11a8cd",
    "#e5e5e5",
    "#666666",
    "#f14c4c",
    "#23d18b",
    "#f5f543",
    "#3b8eea",
    "#d670d6",
    "#29b8db",
    "#ffffff",
}

--- Colour `n` of the 256-colour palette as "#rrggbb"; the first sixteen
--- follow the colorscheme's terminal colours when it sets them.
local function palette(n)
    if n < 16 then
        return vim.g["terminal_color_" .. n] or base16[n + 1]
    elseif n < 232 then
        n = n - 16
        local levels = { 0, 95, 135, 175, 215, 255 }
        local r = levels[math.floor(n / 36) + 1]
        local g = levels[math.floor(n / 6) % 6 + 1]
        local b = levels[n % 6 + 1]
        return ("#%02x%02x%02x"):format(r, g, b)
    end
    local v = 8 + (n - 232) * 10
    return ("#%02x%02x%02x"):format(v, v, v)
end

---@class mermaid.Sgr
---@field fg? string
---@field bg? string
---@field bold? boolean
---@field italic? boolean
---@field underline? boolean

--- The SGR state after applying one parameter list to `state`.
---@param state mermaid.Sgr
---@param params integer[]
---@return mermaid.Sgr
local function apply_sgr(state, params)
    state = vim.deepcopy(state)
    local i = 1
    while i <= #params do
        local p = params[i]
        if p == 0 then
            state = {}
        elseif p == 1 then
            state.bold = true
        elseif p == 3 then
            state.italic = true
        elseif p == 4 then
            state.underline = true
        elseif p == 22 then
            state.bold = nil
        elseif p == 23 then
            state.italic = nil
        elseif p == 24 then
            state.underline = nil
        elseif p >= 30 and p <= 37 then
            state.fg = palette(p - 30)
        elseif p >= 90 and p <= 97 then
            state.fg = palette(p - 90 + 8)
        elseif p == 39 then
            state.fg = nil
        elseif p >= 40 and p <= 47 then
            state.bg = palette(p - 40)
        elseif p >= 100 and p <= 107 then
            state.bg = palette(p - 100 + 8)
        elseif p == 49 then
            state.bg = nil
        elseif (p == 38 or p == 48) and params[i + 1] == 5 then
            state[p == 38 and "fg" or "bg"] = palette(params[i + 2] or 0)
            i = i + 2
        elseif (p == 38 or p == 48) and params[i + 1] == 2 then
            state[p == 38 and "fg" or "bg"] = ("#%02x%02x%02x"):format(
                params[i + 2] or 0,
                params[i + 3] or 0,
                params[i + 4] or 0
            )
            i = i + 4
        end
        i = i + 1
    end
    return state
end

--- Highlight group for an SGR state, nil for plain text.
---@param state mermaid.Sgr
local function sgr_group(state)
    if not next(state) then
        return nil
    end
    local key = table.concat({
        state.fg or "",
        state.bg or "",
        state.bold and "b" or "",
        state.italic and "i" or "",
        state.underline and "u" or "",
    }, "_")
    local name = ansi_groups[key]
    if not name then
        name = "MermaidAnsi" .. vim.fn.sha256(key):sub(1, 8)
        api.nvim_set_hl(0, name, {
            fg = state.fg,
            bg = state.bg,
            bold = state.bold,
            italic = state.italic,
            underline = state.underline,
        })
        ansi_groups[key] = name
    end
    return name
end

--- Split one line of ANSI-coloured text into highlight chunks. The SGR state
--- carries across lines (termaid resets after every cell; others may not).
---@param state mermaid.Sgr
---@return mermaid.Chunk[] chunks, mermaid.Sgr state
local function parse_ansi_line(line, state)
    line = line:gsub("\27%[[%d;?]*[A-Za-ln-z]", "") -- any CSI that isn't SGR (cursor moves etc.)
    local chunks = {} ---@type mermaid.Chunk[]
    local function push(text)
        if text == "" then
            return
        end
        local group = sgr_group(state)
        local last = chunks[#chunks]
        if last and last[2] == group then
            last[1] = last[1] .. text -- merge runs; termaid escapes every cell
        else
            chunks[#chunks + 1] = { text, group }
        end
    end
    local pos = 1
    while pos <= #line do
        local s, e, params = line:find("\27%[([%d;]*)m", pos)
        if not s then
            push(line:sub(pos))
            break
        end
        push(line:sub(pos, s - 1))
        local nums = {}
        for n in params:gmatch("%d+") do
            nums[#nums + 1] = tonumber(n)
        end
        state = apply_sgr(state, #nums > 0 and nums or { 0 })
        pos = e + 1
    end
    return chunks, state
end

---@param row mermaid.Chunk[]
local function row_text(row)
    local parts = {}
    for _, chunk in ipairs(row) do
        parts[#parts + 1] = chunk[1]
    end
    return table.concat(parts)
end

---------------------------------------------------------------------------
-- The preview float
---------------------------------------------------------------------------

local float_win ---@type snacks.win? the one preview float; opening another replaces it

--- Set a Snacks.win scratch buffer's lines (it keeps them read-only).
local function set_lines(win, lines)
    vim.bo[win.buf].modifiable = true
    api.nvim_buf_set_lines(win.buf, 0, -1, false, lines)
    vim.bo[win.buf].modifiable = false
end

--- Size a float to `width` × `height` cells (kept inside the editor) and re-centre it.
local function resize(win, width, height)
    win.opts.width = math.max(1, math.min(width, vim.o.columns - 4))
    win.opts.height = math.max(1, math.min(height, vim.o.lines - 4))
    win:update()
end

--- A preview float that opens at once with a spinner when the render takes
--- longer than a blink, and gets its content swapped in by the caller.
---@param title string
---@return { win: fun(): snacks.win?, fail: fun(msg: string) }
local function loading_float(title)
    local win ---@type snacks.win?
    local timer ---@type uv.uv_timer_t?
    local pending = true

    local function stop_spinner()
        if timer then
            timer:stop()
            timer:close()
            timer = nil
        end
    end

    -- the window; nil once the user has closed it
    local function ensure()
        if win then
            return win:valid() and win or nil
        end
        if float_win and float_win:valid() then
            float_win:close()
        end
        win = Snacks.win({
            position = "float",
            relative = "editor",
            border = "rounded",
            title = title,
            title_pos = "center",
            width = 24,
            height = 1,
            enter = true,
            wo = { wrap = false, winblend = 0 },
            keys = { q = "close", ["<Esc>"] = "close" },
            on_close = stop_spinner,
        })
        float_win = win
        return win
    end

    -- show the spinner only if the render is still pending after a grace
    -- period, so cache hits never flash an empty popup
    vim.defer_fn(function()
        if not pending then
            return
        end
        local w = ensure()
        if not w then
            return
        end
        timer = vim.uv.new_timer()
        timer:start(
            0,
            80,
            vim.schedule_wrap(function()
                if not w:valid() then
                    return stop_spinner()
                end
                set_lines(w, { " " .. Snacks.util.spinner() .. " rendering…" })
            end)
        )
    end, 150)

    return {
        --- The window, ready for content (opened now if the grace period hasn't
        --- elapsed); nil when the user closed it while waiting.
        win = function()
            pending = false
            stop_spinner()
            return ensure()
        end,
        --- Show an error in the float if it's open, else as a notification.
        fail = function(msg)
            pending = false
            stop_spinner()
            if not (win and win:valid()) then
                return notify(msg, vim.log.levels.ERROR)
            end
            local lines = vim.split(msg, "\n", { plain = true })
            set_lines(win, lines)
            local w = 0
            for _, l in ipairs(lines) do
                w = math.max(w, vim.fn.strdisplaywidth(l))
            end
            resize(win, w, #lines)
        end,
    }
end

---------------------------------------------------------------------------
-- Text rendering
---------------------------------------------------------------------------

--- The renderer command for `width` columns: placeholders substituted, the
--- theme pair dropped when no theme applies.
local function text_cmd(width)
    local theme = M.opts.text_theme[vim.o.background]
    local cmd = {}
    for _, arg in ipairs(M.opts.cmd) do
        if arg == "{theme}" then
            if theme then
                cmd[#cmd + 1] = theme
            else
                table.remove(cmd) -- the flag before the placeholder
            end
        elseif arg == "{width}" then
            cmd[#cmd + 1] = tostring(math.max(width, 20))
        else
            cmd[#cmd + 1] = arg
        end
    end
    return cmd
end

---@param cb fun(rows: mermaid.Chunk[][]?, err: string?)
local function render(src, width, cb)
    local exe = M.opts.cmd[1]
    if vim.fn.executable(exe) ~= 1 then
        return cb(nil, ("`%s` (the mermaid text renderer) is not on PATH"):format(exe))
    end
    -- stdout is a pipe here, so colour-aware CLIs (termaid via rich) would
    -- drop their escapes unless told otherwise — the parser below handles them
    -- — and rich would also soft-wrap every line at its 80-column default.
    -- A huge COLUMNS switches that off; `{width}` alone decides the layout,
    -- and anything still wider scrolls in the float / virtual lines.
    local env = { FORCE_COLOR = "1", COLORTERM = "truecolor", COLUMNS = "4096" }
    vim.system(text_cmd(width), { stdin = src .. "\n", text = true, env = env }, function(res)
        vim.schedule(function()
            local stderr = vim.trim(res.stderr or "")
            if res.code ~= 0 then
                return cb(nil, stderr ~= "" and stderr or (exe .. " failed with exit code " .. res.code))
            end
            local lines = vim.split(res.stdout or "", "\n", { plain = true })
            local function blank(l)
                return l:gsub("\27%[[%d;]*m", ""):match("^%s*$") ~= nil
            end
            while #lines > 0 and blank(lines[#lines]) do
                table.remove(lines)
            end
            while #lines > 0 and blank(lines[1]) do
                table.remove(lines, 1)
            end
            if #lines == 0 then
                -- termaid exits 0 on input it can't parse and prints nothing
                return cb(nil, exe .. " produced no output: unsupported diagram type or a syntax error")
            end
            local rows, state = {}, {}
            for _, line in ipairs(lines) do
                rows[#rows + 1], state = parse_ansi_line(line, state)
            end
            cb(rows)
        end)
    end)
end

--- Render the fence under the cursor in a floating window.
function M.float()
    local _, fence = current_fence()
    if not fence then
        return
    end
    local max_w, max_h = math.floor(vim.o.columns * 0.9), math.floor(vim.o.lines * 0.85)
    local loader = loading_float(" mermaid ")
    render(fence.src, max_w, function(rows, err)
        if not rows then
            return loader.fail(err)
        end
        local win = loader.win()
        if not win then
            return
        end
        local lines = vim.tbl_map(row_text, rows)
        local w = 0
        for _, l in ipairs(lines) do
            w = math.max(w, vim.fn.strdisplaywidth(l))
        end
        set_lines(win, lines)
        -- colour the chunks in place
        api.nvim_buf_clear_namespace(win.buf, ns, 0, -1)
        for r, row in ipairs(rows) do
            local col = 0
            for _, chunk in ipairs(row) do
                if chunk[2] then
                    api.nvim_buf_set_extmark(
                        win.buf,
                        ns,
                        r - 1,
                        col,
                        { end_col = col + #chunk[1], hl_group = chunk[2] }
                    )
                end
                col = col + #chunk[1]
            end
        end
        resize(win, math.min(w, max_w), math.min(#lines, max_h))
    end)
end

---------------------------------------------------------------------------
-- Inline: virtual lines below the closing fence
---------------------------------------------------------------------------

local function inline_mark(buf, row)
    local marks = api.nvim_buf_get_extmarks(buf, ns, { row, 0 }, { row, -1 }, {})
    return marks[1] and marks[1][1]
end

local function render_inline(buf, fence, win)
    local textoff = vim.fn.getwininfo(win)[1].textoff
    local width = api.nvim_win_get_width(win) - textoff - fence.indent
    render(fence.src, width, function(rows, err)
        if not rows then
            return notify(err, vim.log.levels.ERROR)
        end
        if not api.nvim_buf_is_valid(buf) then
            return
        end
        local pad = (" "):rep(fence.indent)
        local virt = {}
        for _, row in ipairs(rows) do
            -- the block background stays; a coloured chunk stacks its group on top
            local line = { { pad, "MermaidInline" } }
            for _, chunk in ipairs(row) do
                line[#line + 1] = { chunk[1], chunk[2] and { "MermaidInline", chunk[2] } or "MermaidInline" }
            end
            virt[#virt + 1] = line
        end
        api.nvim_buf_set_extmark(buf, ns, fence.end_row, 0, {
            id = inline_mark(buf, fence.end_row),
            virt_lines = virt,
            virt_lines_overflow = "scroll",
        })
    end)
end

--- Toggle a rendering of the fence under the cursor as virtual lines below it.
function M.toggle_inline()
    local buf, fence = current_fence()
    if not fence then
        return
    end
    local id = inline_mark(buf, fence.end_row)
    if id then
        api.nvim_buf_del_extmark(buf, ns, id)
        return
    end
    render_inline(buf, fence, api.nvim_get_current_win())
end

---------------------------------------------------------------------------
-- Image rendering (snacks.image, on demand)
---------------------------------------------------------------------------

-- Inline image placements made by <localleader>mi, per buffer, keyed by the
-- rendered source. snacks names that file by a hash of the fence content, so
-- an edited fence is simply a new key and its old placement goes stale.
local image_inline = {} ---@type table<integer, table<string, snacks.image.Placement>>

local function inline_images(buf)
    image_inline[buf] = image_inline[buf] or {}
    return image_inline[buf]
end

--- Mermaid themeVariables taken from the colorscheme, so diagrams match the
--- editor in light and dark. Mermaid derives most per-diagram colours from
--- `primaryColor` and friends, but the renderers don't all follow those
--- derivations (mmdr left sequence actors on its stock grey, with light text
--- on a light box), so the per-diagram text and box variables are spelled out
--- too. Unknown names are ignored, so this is safe across renderers.
local function image_theme()
    local function color(group, attr)
        local hl = api.nvim_get_hl(0, { name = group, link = false })
        return hl[attr] and ("#%06x"):format(hl[attr]) or nil
    end
    local light = vim.o.background == "light"
    local bg = color("Normal", "bg") or (light and "#ffffff" or "#1e1e2e")
    local fg = color("Normal", "fg") or (light and "#000000" or "#cdd6f4")
    local box = color("CursorLine", "bg") or color("Visual", "bg") or bg
    local box2 = color("StatusLine", "bg") or box
    local accent = color("Function", "fg") or fg
    return {
        themeVariables = {
            background = bg,
            -- general
            primaryColor = box,
            primaryBorderColor = accent,
            primaryTextColor = fg,
            secondaryColor = box2,
            tertiaryColor = box2,
            mainBkg = box,
            nodeBorder = accent,
            textColor = fg,
            titleColor = fg,
            lineColor = fg,
            edgeLabelBackground = bg,
            -- flowchart subgraphs and kanban columns (mmdr draws those as
            -- clusters, uniformly — no per-column palette like mermaid.js)
            clusterBkg = box2,
            clusterBorder = accent,
            -- sequence
            actorBkg = box,
            actorBorder = accent,
            actorTextColor = fg,
            actorLineColor = fg,
            signalColor = fg,
            signalTextColor = fg,
            labelBoxBkgColor = box,
            labelTextColor = fg,
            loopTextColor = fg,
            noteBkgColor = box2,
            noteBorderColor = accent,
            noteTextColor = fg,
            activationBkgColor = box2,
            activationBorderColor = accent,
            -- class / state
            classText = fg,
            labelColor = fg,
            -- pie
            pieTitleTextColor = fg,
            pieLegendTextColor = fg,
            pieStrokeColor = bg,
            -- gantt
            sectionBkgColor = box2,
            altSectionBkgColor = bg,
            sectionBkgColor2 = box,
            taskTextColor = fg,
            taskTextOutsideColor = fg,
            taskTextLightColor = fg,
            taskTextDarkColor = bg,
            taskBorderColor = accent,
            gridColor = color("Comment", "fg") or fg,
            todayLineColor = accent,
            -- gitGraph
            commitLabelColor = fg,
            commitLabelBackground = box,
            tagLabelColor = fg,
            tagLabelBackground = box,
            tagLabelBorder = accent,
        },
    }
end

---@class mermaid.ImageSize
---@field width integer canvas width in pixels
---@field height integer canvas height in pixels

--- The first image renderer preset whose binary is on PATH, or nil.
local function image_cmd()
    for _, preset in ipairs(M.opts.image_cmds) do
        if vim.fn.executable(preset[1]) == 1 then
            return preset
        end
    end
    return nil
end

local cache_dir = vim.fn.stdpath("cache") .. "/mermaid"

--- Cache paths for a diagram, keyed by renderer, theme, canvas size, and
--- source: a renderer or theme switch, a resize, or an edit is a fresh render,
--- everything else is a hit.
---@param size? mermaid.ImageSize
---@param preset? string[] renderer command; defaults to the first available
local function image_paths(src, size, preset)
    preset = preset or image_cmd() or {}
    local theme = image_theme()
    local config = vim.json.encode(theme)
    local canvas = size and (size.width .. "x" .. size.height) or "natural"
    local key = vim.fn.sha256(table.concat(preset, "\1") .. "\n" .. config .. "\n" .. canvas .. "\n" .. src):sub(1, 16)
    local base = cache_dir .. "/" .. key
    return {
        base = base,
        mmd = base .. ".mmd",
        config = config,
        config_file = base .. ".json",
        png = base .. ".png",
        background = theme.themeVariables.background,
    }
end

--- Bump a cache entry's timestamps. The sweep goes by mtime, so without this
--- a diagram you open every day would still expire on the render's schedule.
local function touch(paths)
    local now = os.time()
    for _, path in ipairs({ paths.png, paths.mmd, paths.config_file }) do
        vim.uv.fs_utime(path, now, now) -- missing files just fail, which is fine
    end
end

--- Delete every cache file untouched for `max_age_days` and restamp the clock.
--- Whole entries go together because their three files are touched together;
--- the debris a failed render leaves behind (a `.mmd`/`.json` whose PNG never
--- appeared) ages out the same way, having nothing to touch it.
local function sweep_cache()
    if not vim.uv.fs_stat(cache_dir) then
        return
    end
    local stamp = cache_dir .. "/last-sweep"
    local fd = vim.uv.fs_open(stamp, "w", tonumber("644", 8))
    if fd then
        vim.uv.fs_close(fd)
    end
    local scan = vim.uv.fs_scandir(cache_dir)
    if not scan then
        return
    end
    local cutoff = os.time() - M.opts.cache.max_age_days * 86400
    while true do
        local name = vim.uv.fs_scandir_next(scan)
        if not name then
            return
        end
        local path = cache_dir .. "/" .. name
        local stat = path ~= stamp and vim.uv.fs_stat(path)
        if stat and stat.type == "file" and stat.mtime.sec < cutoff then
            vim.uv.fs_unlink(path)
        end
    end
end

local swept = false

--- Queue the sweep: once per nvim session, and once per `sweep_every_hours`
--- across sessions, so opening a markdown file usually costs one stat.
local function schedule_sweep()
    if swept then
        return
    end
    swept = true
    local last = vim.uv.fs_stat(cache_dir .. "/last-sweep")
    if last and os.time() - last.mtime.sec < M.opts.cache.sweep_every_hours * 3600 then
        return
    end
    vim.defer_fn(sweep_cache, M.opts.cache.sweep_delay_ms)
end

local function write_file(path, text)
    local fd = assert(io.open(path, "w"), "cannot write " .. path)
    fd:write(text)
    fd:close()
end

---@param size? mermaid.ImageSize canvas in pixels; nil renders at the diagram's natural size
---@param cb fun(png: string?, err: string?)
local function render_image(src, size, cb)
    local preset = image_cmd()
    if not preset then
        local names = vim.tbl_map(function(p)
            return p[1]
        end, M.opts.image_cmds)
        return cb(nil, "no mermaid image renderer on PATH (" .. table.concat(names, " or ") .. ")")
    end
    local exe = preset[1]
    local paths = image_paths(src, size, preset)
    if vim.fn.filereadable(paths.png) == 1 then
        touch(paths) -- viewed today, so keep it for another `max_age_days`
        return cb(paths.png)
    end
    vim.fn.mkdir(vim.fs.dirname(paths.base), "p")
    write_file(paths.mmd, src .. "\n")
    write_file(paths.config_file, paths.config)
    local subst = {
        ["{src}"] = paths.mmd,
        ["{file}"] = paths.png,
        ["{config}"] = paths.config_file,
        ["{theme}"] = vim.o.background == "light" and "default" or "dark",
        ["{background}"] = paths.background,
        ["{width}"] = size and tostring(size.width),
        ["{height}"] = size and tostring(size.height),
    }
    local template = vim.list_extend(vim.deepcopy(preset), size and M.opts.image_size or {})
    local cmd = vim.tbl_map(function(arg)
        return subst[arg] or arg
    end, template)
    vim.system(cmd, { text = true }, function(res)
        vim.schedule(function()
            if res.code ~= 0 or vim.fn.filereadable(paths.png) == 0 then
                local msg = vim.trim(res.stderr or "")
                if msg == "" then
                    msg = vim.trim(res.stdout or "")
                end
                return cb(nil, msg ~= "" and msg or (exe .. " produced no image"))
            end
            cb(paths.png)
        end)
    end)
end

--- Placement options: snacks' doc settings (size limits etc.) plus ours.
local function image_opts(extra)
    return Snacks.config.merge({}, Snacks.image.config.doc, extra)
end

--- Render the fence under the cursor as an image in a floating window.
function M.image_float()
    if not Snacks.image.supports_terminal() then
        return notify("No kitty graphics in this terminal; <localleader>mM gives the text rendering")
    end
    local _, fence = current_fence()
    if not fence then
        return
    end
    -- A centred float filling nearly the whole editor (the border takes two
    -- cells each way). The diagram is rendered onto a canvas of exactly that
    -- box in pixels, so the renderer scales it up to fill the area and centres
    -- it; the margins carry the editor background, so they're invisible.
    local max_w, max_h = math.floor(vim.o.columns * 0.9) - 2, math.floor(vim.o.lines * 0.9) - 2
    local cell = Snacks.image.terminal.size()
    local size = { width = max_w * cell.cell_width, height = max_h * cell.cell_height }
    local loader = loading_float(" mermaid ")
    render_image(fence.src, size, function(png, err)
        if not png then
            return loader.fail(err)
        end
        local win = loader.win()
        if not win then
            return
        end
        -- snacks fits an image to the windows showing its buffer, so the
        -- window is hidden while the placement sizes itself against the box,
        -- then shown at the fitted size — the same dance as snacks' hover
        win:hide()
        set_lines(win, {})
        local placement ---@type snacks.image.Placement?
        win.opts.on_close = function()
            if placement then
                placement:close()
                placement = nil
            end
        end
        local shown = false
        placement = Snacks.image.placement.new(
            win.buf,
            png,
            image_opts({
                inline = false,
                max_width = max_w,
                max_height = max_h,
                on_update_pre = function(p)
                    if shown then
                        return
                    end
                    shown = true
                    local loc = p:state().loc
                    win.opts.width = loc.width
                    win.opts.height = loc.height
                    win:show()
                end,
            })
        )
    end)
end

--- Toggle the fence under the cursor as an image below it.
function M.toggle_image_inline()
    if not Snacks.image.terminal.env().placeholders then
        return notify(
            "Inline images need unicode placeholders, which this terminal (Zellij?) lacks; <localleader>mm floats it instead"
        )
    end
    local buf, fence = current_fence()
    if not fence then
        return
    end
    render_image(fence.src, nil, function(png, err)
        if not png then
            return notify(err, vim.log.levels.ERROR)
        end
        local imgs = inline_images(buf)
        local existing = imgs[png]
        if existing then
            existing:close()
            imgs[png] = nil
            return
        end
        local closing = api.nvim_buf_get_lines(buf, fence.end_row, fence.end_row + 1, false)[1] or ""
        imgs[png] = Snacks.image.placement.new(
            buf,
            png,
            image_opts({
                pos = { fence.start_row + 1, fence.indent },
                range = { fence.start_row + 1, fence.indent, fence.end_row + 1, #closing },
                inline = true,
                conceal = false, -- keep the fence text; the picture goes in virtual lines below it
            })
        )
    end)
end

---------------------------------------------------------------------------
-- Saving
---------------------------------------------------------------------------

--- The diagram type of a fence, for file names: the first keyword after any
--- frontmatter or `%%` comments, lowercased, with `Diagram`, `-beta`, and
--- `-v2` dropped (`sequenceDiagram` → sequence, `treemap-beta` → treemap) and
--- `graph` reported as flowchart.
local function diagram_type(src)
    local in_frontmatter = false
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        local l = vim.trim(line)
        if l == "---" then
            in_frontmatter = not in_frontmatter
        elseif not in_frontmatter and l ~= "" and not l:match("^%%%%") then
            local word = (l:match("^([%w-]+)") or "diagram"):lower()
            word = word:gsub("%-beta$", ""):gsub("%-v2$", ""):gsub("diagram$", "")
            return word == "graph" and "flowchart" or word
        end
    end
    return "diagram"
end

--- Save the fence under the cursor as a PNG. Prompts for a name (the `.png`
--- is added; a name with `/` is a path, `~` expands), defaulting to
--- `mermaid-{type}_{YYYYMMDDHHmmss}` next to the markdown file.
function M.save_image()
    local buf, fence = current_fence()
    if not fence then
        return
    end
    local default = ("mermaid-%s_%s"):format(diagram_type(fence.src), os.date("%Y%m%d%H%M%S"))
    vim.ui.input({ prompt = "Save diagram as (.png added): ", default = default, completion = "file" }, function(name)
        name = name and vim.trim(name) or ""
        if name == "" then
            return
        end
        name = name:gsub("%.png$", "")
        local dir = vim.fs.dirname(api.nvim_buf_get_name(buf))
        if dir == "" or dir == "." then
            dir = vim.fn.getcwd()
        end
        local dest = vim.fn.expand(name) .. ".png"
        if not vim.startswith(dest, "/") then
            dest = vim.fs.joinpath(dir, dest)
        end
        if vim.uv.fs_stat(dest) and vim.fn.confirm(("Overwrite %s?"):format(dest), "&Yes\n&No", 2) ~= 1 then
            return
        end
        render_image(fence.src, nil, function(png, err)
            if not png then
                return notify(err, vim.log.levels.ERROR)
            end
            vim.fn.mkdir(vim.fs.dirname(dest), "p")
            local ok, cerr = vim.uv.fs_copyfile(png, dest)
            if not ok then
                return notify("Could not save the diagram: " .. tostring(cerr), vim.log.levels.ERROR)
            end
            notify("Saved " .. dest, vim.log.levels.INFO)
        end)
    end)
end

---------------------------------------------------------------------------
-- Clearing and refreshing
---------------------------------------------------------------------------

--- Remove every inline rendering, text and image, in the buffer.
function M.clear(buf)
    buf = buf or api.nvim_get_current_buf()
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, p in pairs(inline_images(buf)) do
        p:close()
    end
    image_inline[buf] = nil
end

--- Re-render every inline text diagram in the buffer (its source may have
--- changed), drop text renderings whose closing fence is gone, and drop image
--- placements whose fence content changed (they'd keep showing the old one).
function M.refresh(buf)
    buf = buf or api.nvim_get_current_buf()
    local win = api.nvim_get_current_win()
    for _, mark in ipairs(api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})) do
        local id, row = mark[1], mark[2]
        local fence = fence_at(buf, row)
        if fence and fence.end_row == row then
            render_inline(buf, fence, win)
        else
            api.nvim_buf_del_extmark(buf, ns, id)
        end
    end
    local imgs = inline_images(buf)
    if next(imgs) then
        local live = {}
        for _, fence in ipairs(fences(buf)) do
            live[image_paths(fence.src).png] = true
        end
        for png, p in pairs(imgs) do
            if not live[png] then
                p:close()
                imgs[png] = nil
            end
        end
    end
end

---------------------------------------------------------------------------
-- Buffer wiring
---------------------------------------------------------------------------

function M.attach()
    local buf = api.nvim_get_current_buf()
    local function map(lhs, fn, desc)
        vim.keymap.set("n", lhs, fn, { buffer = buf, desc = desc })
    end
    map("<localleader>mm", M.image_float, "Mermaid: image preview in a float")
    map("<localleader>mM", M.float, "Mermaid: text preview in a float")
    map("<localleader>mi", M.toggle_image_inline, "Mermaid: toggle image below the fence")
    map("<localleader>mI", M.toggle_inline, "Mermaid: toggle text render below the fence")
    map("<localleader>mc", M.clear, "Mermaid: clear inline renders")
    map("<localleader>ms", M.save_image, "Mermaid: save as PNG")
    pcall(function()
        require("which-key").add({ { "<localleader>m", buffer = buf, group = "mermaid" } })
    end)

    -- Inline renders go stale as the fence is edited; refresh them on save.
    local group = api.nvim_create_augroup("MermaidInline", { clear = false })
    api.nvim_clear_autocmds({ group = group, buffer = buf })
    api.nvim_create_autocmd("BufWritePost", {
        group = group,
        buffer = buf,
        callback = function()
            M.refresh(buf)
        end,
    })
    api.nvim_create_autocmd("BufWipeout", {
        group = group,
        buffer = buf,
        callback = function()
            image_inline[buf] = nil -- snacks closes the placements themselves
        end,
    })

    -- Housekeeping for the PNG cache, throttled to a stat in the common case.
    schedule_sweep()
end

M.fences = fences
M.fence_at = fence_at
M.render_text = render
M.render_image = render_image
M.sweep_cache = sweep_cache
M.diagram_type = diagram_type
--- The open preview float, if any (for scripting).
function M.preview_float()
    return float_win and float_win:valid() and float_win or nil
end

return M
