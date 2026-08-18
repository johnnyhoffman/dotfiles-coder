-- <localleader>f formatting operators for markdown buffers (attached from after/ftplugin/markdown.lua).
--
-- All maps work like builtin operators (`gu`): visual mode acts on the selection,
-- normal mode enters operator-pending mode so any motion/text object works.
--
-- Bold/italic/strikethrough/inline-code delegate to markdown.nvim's treesitter-based
-- toggle. `markdown.inline` is an internal module, not documented API — if an update
-- breaks it, pin the plugin or rework the glue.
--
-- Highlight/equation/code-block are hand-rolled: markdown.nvim's inline styles are
-- hard-wired to markdown_inline treesitter node types, which don't cover these. Their
-- toggle is plain string matching on the range edges — good enough for markers with no
-- nesting ambiguity, unlike `*`/`**`.

local api = vim.api

local M = {}

-- Styles backed by markdown.nvim; key = the plugin's configured emphasis key.
local plugin_styles = {
    b = { key = "b", desc = "Bold" },
    i = { key = "i", desc = "Italic" },
    s = { key = "s", desc = "Strikethrough" },
    c = { key = "c", desc = "Inline code" },
}

-- Hand-rolled marker-pair styles.
local wrap_styles = {
    h = { marker = "==", desc = "Highlight" },
    e = { marker = "$", desc = "Equation" },
}

local OPFUNC = "v:lua.require'config.markdown-format'."

---------------------------------------------------------------------------
-- markdown.nvim glue: per-style operators with the style key pre-bound
---------------------------------------------------------------------------

local pending_plugin_key

function M._plugin_opfunc(motion)
    require("markdown.inline").toggle_emphasis(motion, pending_plugin_key)
end

---------------------------------------------------------------------------
-- Hand-rolled marker toggle
---------------------------------------------------------------------------

local function get_line(row)
    return api.nvim_buf_get_lines(0, row, row + 1, true)[1]
end

-- Advance a 0-based byte col past the (possibly multibyte) character starting at it.
local function advance_char(line, col)
    local b = line:byte(col + 1)
    if b == nil then
        return col
    elseif b >= 0xF0 then
        col = col + 4
    elseif b >= 0xE0 then
        col = col + 3
    elseif b >= 0xC0 then
        col = col + 2
    else
        col = col + 1
    end
    return math.min(col, #line)
end

-- Range over the last motion ('[ / ']) or visual selection ('< / '>),
-- as 0-based (srow, scol, erow, ecol) with ecol exclusive.
local function marks_range(start_mark, end_mark, linewise)
    local s = api.nvim_buf_get_mark(0, start_mark)
    local e = api.nvim_buf_get_mark(0, end_mark)
    local srow, scol, erow, ecol = s[1] - 1, s[2], e[1] - 1, e[2]
    local eline = get_line(erow)
    if linewise then
        scol = 0
        ecol = #eline
    else
        -- the end mark points at the first byte of the last character; include it
        ecol = advance_char(eline, math.min(ecol, math.max(#eline - 1, 0)))
    end
    return srow, scol, erow, ecol
end

-- Leave the cursor at the start of the affected text, like builtin operators do
-- (also keeps dot-repeat targets predictable).
local function set_cursor(row, col)
    vim.api.nvim_win_set_cursor(0, { row + 1, math.min(col, math.max(#get_line(row) - 1, 0)) })
end

-- Toggle `marker` around the range: strip it if found just inside or just outside
-- the range edges, otherwise wrap.
local function toggle_wrap(marker, srow, scol, erow, ecol)
    local n = #marker
    local inside = api.nvim_buf_get_text(0, srow, scol, erow, ecol, {})
    local first, last = inside[1], inside[#inside]

    -- markers included in the range (e.g. selection covers "==text==")
    if
        vim.startswith(first, marker)
        and vim.endswith(last, marker)
        and (srow ~= erow or #first >= 2 * n)
    then
        api.nvim_buf_set_text(0, erow, ecol - n, erow, ecol, {})
        api.nvim_buf_set_text(0, srow, scol, srow, scol + n, {})
        set_cursor(srow, scol)
        return
    end

    -- markers just outside the range (e.g. "iw" on "text" inside "==text==")
    if scol >= n and ecol + n <= #get_line(erow) then
        local before = api.nvim_buf_get_text(0, srow, scol - n, srow, scol, {})[1]
        local after = api.nvim_buf_get_text(0, erow, ecol, erow, ecol + n, {})[1]
        if before == marker and after == marker then
            api.nvim_buf_set_text(0, erow, ecol, erow, ecol + n, {})
            api.nvim_buf_set_text(0, srow, scol - n, srow, scol, {})
            set_cursor(srow, scol - n)
            return
        end
    end

    -- wrap (end first, so the start edit doesn't shift the end position)
    api.nvim_buf_set_text(0, erow, ecol, erow, ecol, { marker })
    api.nvim_buf_set_text(0, srow, scol, srow, scol, { marker })
    set_cursor(srow, scol)
end

local pending_marker

function M._wrap_opfunc(motion)
    toggle_wrap(pending_marker, marks_range("[", "]", motion == "line"))
end

function M._wrap_visual(style, visualmode)
    local marker = wrap_styles[style].marker
    toggle_wrap(marker, marks_range("<", ">", visualmode == "V"))
end

---------------------------------------------------------------------------
-- Code block: linewise motions fence/unfence whole lines; charwise motions
-- extract the range into its own fenced block, splitting the line
---------------------------------------------------------------------------

-- Pull the charwise range out into its own fenced block, leaving the
-- remainder of the split line(s) as separate paragraphs.
local function fence_extract(srow, scol, erow, ecol)
    local text = api.nvim_buf_get_text(0, srow, scol, erow, ecol, {})
    local before = get_line(srow):sub(1, scol):gsub("%s+$", "")
    local after = get_line(erow):sub(ecol + 1):gsub("^%s+", "")

    local repl = {}
    if before ~= "" then
        repl[#repl + 1] = before
        repl[#repl + 1] = ""
    end
    repl[#repl + 1] = "```"
    vim.list_extend(repl, text)
    repl[#repl + 1] = "```"
    if after ~= "" then
        repl[#repl + 1] = ""
        repl[#repl + 1] = after
    end
    api.nvim_buf_set_lines(0, srow, erow + 1, true, repl)

    -- cursor on the first extracted line (just past the opening fence)
    set_cursor(srow + (before ~= "" and 3 or 1), 0)
end

local function toggle_fence(srow, erow)
    local first, last = get_line(srow), get_line(erow)

    -- fences included in the range: strip them
    if erow > srow and first:match("^```") and last:match("^```%s*$") then
        api.nvim_buf_set_lines(0, erow, erow + 1, true, {})
        api.nvim_buf_set_lines(0, srow, srow + 1, true, {})
        return
    end

    -- fences just outside the range: strip them
    local before = srow > 0 and get_line(srow - 1) or nil
    local after = api.nvim_buf_get_lines(0, erow + 1, erow + 2, false)[1]
    if before and before:match("^```") and after and after:match("^```%s*$") then
        api.nvim_buf_set_lines(0, erow + 1, erow + 2, true, {})
        api.nvim_buf_set_lines(0, srow - 1, srow, true, {})
        return
    end

    api.nvim_buf_set_lines(0, erow + 1, erow + 1, true, { "```" })
    api.nvim_buf_set_lines(0, srow, srow, true, { "```" })
end

function M._fence_opfunc(motion)
    if motion == "char" then
        fence_extract(marks_range("[", "]", false))
    else
        toggle_fence(api.nvim_buf_get_mark(0, "[")[1] - 1, api.nvim_buf_get_mark(0, "]")[1] - 1)
    end
end

function M._fence_visual(visualmode)
    if visualmode == "v" then
        fence_extract(marks_range("<", ">", false))
    else
        toggle_fence(api.nvim_buf_get_mark(0, "<")[1] - 1, api.nvim_buf_get_mark(0, ">")[1] - 1)
    end
end

---------------------------------------------------------------------------
-- Keymaps
---------------------------------------------------------------------------

-- Build a normal-mode expr map that arms an operatorfunc, and a visual-mode map.
local function map_operator(lhs, desc, arm, visual_rhs)
    vim.keymap.set("n", "<localleader>f" .. lhs, function()
        arm()
        return "g@"
    end, { expr = true, silent = true, buffer = true, desc = desc })
    vim.keymap.set("x", "<localleader>f" .. lhs, visual_rhs, { silent = true, buffer = true, desc = desc })
end

function M.attach()
    for lhs, style in pairs(plugin_styles) do
        map_operator(lhs, style.desc, function()
            pending_plugin_key = style.key
            vim.o.operatorfunc = OPFUNC .. "_plugin_opfunc"
        end, ("<Esc>gv<Cmd>lua require('markdown.inline').toggle_emphasis_visual('%s')<CR>"):format(style.key))
    end

    for lhs, style in pairs(wrap_styles) do
        map_operator(lhs, style.desc, function()
            pending_marker = style.marker
            vim.o.operatorfunc = OPFUNC .. "_wrap_opfunc"
        end, ("<Esc><Cmd>lua require('config.markdown-format')._wrap_visual('%s', vim.fn.visualmode())<CR>"):format(
            lhs
        ))
    end

    map_operator("C", "Code block", function()
        vim.o.operatorfunc = OPFUNC .. "_fence_opfunc"
    end, "<Esc><Cmd>lua require('config.markdown-format')._fence_visual(vim.fn.visualmode())<CR>")

    local ok, wk = pcall(require, "which-key")
    if ok then
        wk.add({ { "<localleader>f", group = "format", mode = { "n", "x" }, buffer = api.nvim_get_current_buf() } })
    end
end

return M
