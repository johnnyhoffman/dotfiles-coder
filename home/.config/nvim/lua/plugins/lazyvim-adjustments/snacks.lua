-- Splash screen style: true = dog photo header (pixel-perfect kitty graphics
-- via snacks.image where the terminal supports it, chafa-rendered ANSI
-- otherwise); false = minimal text splash showing cwd, git branch, and git
-- worktree (when on one), each on its own line, centered horizontally and
-- vertically. Falls back down the chain (image -> chafa -> minimal) when a
-- renderer's requirements aren't met.
local USE_DOG_SPLASH = false

-- Kitty-graphics capability, detected from env vars instead of snacks' own
-- detection (which is async and would have to be awaited here). Ghostty and
-- kitty are the only kitty-capable terminals in use; Zellij panes inherit
-- their env, and TERM survives ssh, so this covers all the real setups.
local HAS_KITTY_GRAPHICS = vim.env.KITTY_WINDOW_ID ~= nil
    or vim.env.GHOSTTY_RESOURCES_DIR ~= nil
    or (vim.env.TERM or ""):find("kitty") ~= nil
    or (vim.env.TERM or ""):find("ghostty") ~= nil

local SPLASH = (USE_DOG_SPLASH and HAS_KITTY_GRAPHICS) and "image"
    or (USE_DOG_SPLASH and vim.fn.executable("chafa") == 1) and "chafa"
    or "minimal"

return {
    "folke/snacks.nvim",
    opts = function(_, opts)
        -- snacks.image hard-codes Zellij as unsupported in its terminal env
        -- table, and that entry overrides the host terminal's when both are
        -- detected. Local Zellij builds include kitty graphics support
        -- (zellij#5428), so mark it supported before snacks caches its env
        -- detection. This enables snacks.image rendering inside Zellij
        -- (dashboard + markdown image floats). `placeholders` must stay
        -- false: zellij#5428 explicitly excludes unicode placeholders
        -- (U+10EEEE virtual placements), so snacks has to use its
        -- cursor-positioned fallback rendering — with placeholders on, the
        -- virtual placement is silently ignored and nothing is drawn.
        -- NOTE: a Zellij build without that change will print escape garbage
        -- instead of images.
        if vim.env.ZELLIJ then
            for _, e in ipairs(require("snacks.image.terminal").envs()) do
                if e.name == "zellij" then
                    e.supported = true
                end
            end
        end

        -- Make SnacksDim darker (lower blend = more dimmed, default is 80)
        local function setDimHighlightGroup()
            local comment = vim.api.nvim_get_hl(0, { name = "Comment" })
            local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
            if not normal.bg or not comment.fg then
                return nil
            end
            local blend = 0.7
            -- Blend comment.fg toward normal.bg: the result is `blend` parts
            -- normal.bg and `1 - blend` parts comment.fg (higher blend = dimmer).
            local bg_r = bit.rshift(normal.bg, 16)
            local bg_g = bit.band(bit.rshift(normal.bg, 8), 0xFF)
            local bg_b = bit.band(normal.bg, 0xFF)

            local fg_r = bit.rshift(comment.fg, 16)
            local fg_g = bit.band(bit.rshift(comment.fg, 8), 0xFF)
            local fg_b = bit.band(comment.fg, 0xFF)

            local r = math.floor(bg_r * blend + fg_r * (1 - blend))
            local g = math.floor(bg_g * blend + fg_g * (1 - blend))
            local b = math.floor(bg_b * blend + fg_b * (1 - blend))

            local blended_fg = string.format("#%02x%02x%02x", r, g, b)
            vim.api.nvim_set_hl(0, "SnacksDim", {
                fg = blended_fg,
            })
        end
        vim.api.nvim_create_autocmd("ColorScheme", {
            callback = setDimHighlightGroup,
        })
        -- Apply immediately for current colorscheme
        setDimHighlightGroup()

        -- Override snacks' markdown renderer to use markview.render instead of strict_render (fixes what seems like a bug with snacks where it wasn't using my config and would only render the first file)
        vim.api.nvim_create_autocmd("User", {
            pattern = "VeryLazy",
            once = true,
            callback = function()
                local md = require("snacks.picker.util.markdown")
                md.render = function(buf, o)
                    o = o or {}

                    if not vim.bo[buf].filetype:find("^markdown") then
                        local ei = vim.o.eventignore
                        vim.o.eventignore = "all"
                        vim.bo[buf].filetype = "markdown"
                        vim.o.eventignore = ei
                    end

                    pcall(vim.treesitter.start, buf, "markdown")

                    if o.images ~= false then
                        vim.b[buf].snacks_image_conceal = true
                        Snacks.image.doc.attach(buf)
                    end

                    require("markview").render(buf)
                end
            end,
        })

        -- Fix a filetype leak from `position = "current"` scratch buffers (see
        -- the `scratch` config below). snacks.scratch opens the scratch through
        -- a Snacks.win whose `bo` pins `filetype = "markdown"`. With a floating
        -- scratch the win is closed on leave; with a reused *current* window it
        -- is not — `fixbuf = false` just re-points the win's `self.buf` at
        -- whatever buffer you tab to, and the Snacks.win object lingers with its
        -- autocmds live (VimResized -> win:update(), BufWinEnter -> fixbuf).
        -- win:update() re-applies `bo` to `self.buf`, so a later resize (e.g. a
        -- Zellij pane resize) stamps `filetype = "markdown"` onto the .sh/.json
        -- file now in that window — dragging in markview rendering + markdownlint
        -- diagnostics. Fix: tear down the win object's autocmds as soon as we
        -- leave the scratch buffer. The window and buffer stay; only the zombie
        -- option-manager is removed (autowrite lives in its own augroup and is
        -- untouched). Wrapping .open covers every entry point (keymap + picker).
        vim.api.nvim_create_autocmd("User", {
            pattern = "VeryLazy",
            once = true,
            callback = function()
                local scratch = require("snacks.scratch")
                local orig_open = scratch.open
                scratch.open = function(...)
                    local win = orig_open(...)
                    -- nil when toggling an open scratch closed; guard for it.
                    if type(win) == "table" and win.buf then
                        vim.api.nvim_create_autocmd({ "BufWinLeave", "BufHidden" }, {
                            buffer = win.buf,
                            once = true,
                            callback = function()
                                if win.augroup then
                                    pcall(vim.api.nvim_del_augroup_by_id, win.augroup)
                                    win.augroup = nil
                                end
                                win.closed = true
                            end,
                        })
                    end
                    return win
                end
            end,
        })

        -- Use custom statuscolumn that collapses git + diagnostic signs into shared space
        vim.o.statuscolumn = [[%!v:lua.require'custom.statuscolumn'.get()]]

        -- Suppress the `[Process exited N]` virtual text inside dashboard
        -- terminal buffers. Neovim 0.10+ adds this via an extmark in the
        -- `nvim.terminal.exitmsg` namespace from a TermClose handler in
        -- `nvim.terminal` (see runtime `lua/vim/_core/defaults.lua`). We scope
        -- the suppression to `snacks_dashboard`-filetype buffers so other
        -- terminal buffers are unaffected. Renderer-agnostic: anything that
        -- runs as a snacks dashboard terminal section benefits.
        vim.api.nvim_create_autocmd("TermClose", {
            callback = function(ev)
                if vim.bo[ev.buf].filetype ~= "snacks_dashboard" then
                    return
                end
                local ns = vim.api.nvim_create_namespace("nvim.terminal.exitmsg")
                vim.schedule(function()
                    if vim.api.nvim_buf_is_valid(ev.buf) then
                        vim.api.nvim_buf_clear_namespace(ev.buf, ns, 0, -1)
                    end
                end)
            end,
        })

        -- Dashboard visual, kitty-graphics variant: a random dog photo rendered
        -- pixel-perfect through snacks.image's placement API. The section
        -- reserves a dashboard-sized block of blank lines (so snacks' vertical
        -- centering accounts for them); how the image lands on them depends on
        -- the terminal env:
        --   - placeholder terminals (kitty/Ghostty directly): `render` overlays
        --     the reserved lines with the placement's unicode-placeholder grid
        --     (`range` + `conceal = true` selects the overlay path in
        --     placement:render_grid; without conceal the grid would go into
        --     virtual lines below the anchor instead). Placements anchor
        --     top-left with no align option, so once the image loads and its
        --     fitted cell size is known, `on_update` re-anchors the grid to the
        --     center of the reserved box.
        --   - non-placeholder terminals (Zellij, wezterm): snacks falls back to
        --     cursor-positioned placement, but its stock render_fallback draws
        --     at the *window's* top-left (it assumes a dedicated image float),
        --     so the placement gets an instance-level render_fallback override
        --     that moves the terminal cursor to the centered cell within the
        --     reserved box before issuing the placement request.
        --
        -- Returns a function so snacks re-evaluates dimensions on every
        -- render (e.g. on VimResized). A dashboard update replaces all buffer
        -- lines (orphaning the placement extmarks) and re-runs the section, so
        -- the placement is closed on UpdatePre/Closed and a fresh one — with a
        -- freshly-random photo, like the chafa variant — is created per render.
        local function dog_image_section()
            return function(self)
                local size = self._size or { width = vim.o.columns, height = vim.o.lines }
                local w = math.max(size.width - 2, 20)
                local h = math.max(size.height - 2, 10)
                local srcs =
                    vim.fn.glob(vim.fn.stdpath("config") .. "/assets/header-chafa-sources/processed/*", false, true)
                if #srcs == 0 then
                    return {}
                end
                local src = srcs[vim.fn.rand() % #srcs + 1]
                return {
                    text = ("\n"):rep(h - 1),
                    render = function(_, pos)
                        local placement ---@type snacks.image.Placement?
                        local closed = false
                        local close = vim.schedule_wrap(function()
                            closed = true
                            if placement then
                                placement:close()
                                placement = nil
                            end
                        end)
                        self.on("UpdatePre", close, self.augroup)
                        self.on("Closed", close, self.augroup)
                        -- detect() is async only on its very first call and
                        -- invokes the callback synchronously afterwards.
                        -- Waiting for it keeps placement:update() from
                        -- blocking on — and permanently caching — a
                        -- half-finished terminal env detection.
                        local terminal = require("snacks.image.terminal")
                        terminal.detect(function()
                            if closed or not vim.api.nvim_buf_is_valid(self.buf) then
                                return
                            end
                            local row = pos[1]
                            local centered = false
                            placement = Snacks.image.placement.new(self.buf, src, {
                                pos = { row, 0 },
                                range = { row, 0, row + h - 1, 0 },
                                conceal = true,
                                -- inline keeps the loading/error states out of
                                -- the dashboard buffer (non-inline placements
                                -- wipe the buffer for a progress spinner)
                                inline = true,
                                width = w,
                                height = h,
                                on_update = function(p)
                                    -- re-center the placeholder grid; the
                                    -- fallback path centers per-render in
                                    -- render_fallback instead
                                    if not terminal.env().placeholders then
                                        return
                                    end
                                    local loc = p._state and p._state.loc
                                    if centered or not loc then
                                        return
                                    end
                                    centered = true
                                    local dy = math.max(math.floor((h - loc.height) / 2), 0)
                                    local dx = math.max(math.floor((w - loc.width) / 2) + 1, 0)
                                    p.opts.pos = { row + dy, dx }
                                    p.opts.range = { row + dy, dx, row + dy + math.min(loc.height, h) - 1, dx }
                                    p:update()
                                end,
                            })
                            -- Instance override (shadows the metatable method):
                            -- draw centered in the reserved box instead of at
                            -- the window's top-left. Cursor row/col math:
                            -- win_get_position() is 0-indexed screen cells,
                            -- buffer line `row` is 1-indexed and the dashboard
                            -- never scrolls, and set_cursor takes {1-indexed
                            -- row, 0-indexed col}.
                            placement.render_fallback = function(p, state)
                                if not vim.api.nvim_win_is_valid(self.win) then
                                    return
                                end
                                local win_pos = vim.api.nvim_win_get_position(self.win)
                                local dy = math.max(math.floor((h - state.loc.height) / 2), 0)
                                local dx = math.max(math.floor((w - state.loc.width) / 2) + 1, 0)
                                terminal.set_cursor({ win_pos[1] + row + dy, win_pos[2] + dx })
                                terminal.request({
                                    a = "p",
                                    i = p.img.id,
                                    p = p.id,
                                    C = 1,
                                    c = state.loc.width,
                                    r = state.loc.height,
                                })
                            end
                        end)
                    end,
                }
            end
        end

        -- Dashboard visual, chafa fallback: an ANSI-rendered still of one of
        -- the dog photos, used when the terminal lacks kitty graphics (chafa's
        -- own kitty output wouldn't help here either — this runs inside a
        -- nvim :terminal, whose emulator drops the graphics escape sequences).
        --
        -- Returns a function so snacks re-evaluates dimensions on every
        -- render (e.g. on VimResized), letting the image scale to the
        -- current dashboard window while preserving aspect ratio.
        local function dog_header_section()
            return function(self)
                local size = self._size or { width = vim.o.columns, height = vim.o.lines }
                local w = math.max(size.width - 2, 20)
                local h = math.max(size.height - 2, 10)
                return {
                    section = "terminal",
                    cmd = table.concat({
                        "clear;",
                        "chafa",
                        '"$(ls -1 -d $HOME/.config/nvim/assets/header-chafa-sources/processed/* | shuf -n 1)"',
                        "--format ansi",
                        ("--size=%dx%d"):format(w, h),
                        "--align center,center",
                        -- '--symbols "$(shuf -n 1 -e legacy geometric inverted narrow alpha alnum diagonal vhalf technical bad ascii ambiguous braille wedge hhalf extra dot digit)"',
                        -- '-c "$(shuf -n 1 -e 16 240 full)"',
                        -- "--color-space din99d",
                        "; sleep .1",
                    }, " "),
                    width = w,
                    height = h,
                    ttl = 0,
                }
            end
        end

        -- Minimal splash alternative (USE_DOG_SPLASH = false): cwd, git
        -- branch, and git worktree name (only when in a linked worktree),
        -- one per line. `align = "center"` centers each line within the
        -- dashboard width, and snacks centers the whole block vertically
        -- when `row` is unset, so no manual padding is needed.
        local function simple_info_section()
            return function()
                local lines = {
                    { vim.fn.fnamemodify(vim.fn.getcwd(), ":~"), "header" },
                }
                local branch = vim.fn.systemlist("git branch --show-current 2>/dev/null")[1]
                if vim.v.shell_error == 0 and branch and branch ~= "" then
                    table.insert(lines, { " " .. branch, "special" })
                end
                -- In a linked worktree, --git-dir and --git-common-dir differ
                local dirs = vim.fn.systemlist("git rev-parse --git-dir --git-common-dir 2>/dev/null")
                if
                    vim.v.shell_error == 0
                    and #dirs == 2
                    and vim.fn.fnamemodify(dirs[1], ":p") ~= vim.fn.fnamemodify(dirs[2], ":p")
                then
                    local toplevel = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
                    if toplevel then
                        table.insert(lines, { "worktree: " .. vim.fn.fnamemodify(toplevel, ":t"), "footer" })
                    end
                end
                local items = {}
                for _, line in ipairs(lines) do
                    table.insert(items, { text = { line[1], hl = line[2] }, align = "center" })
                end
                return items
            end
        end

        -- Hide bufferline on the dashboard. snacks sets showtabline=0 at
        -- startup (dashboard.lua ~1187) but bufferline loads on VeryLazy
        -- afterward and resets it. Force 0 while a snacks_dashboard buffer is
        -- current; restore to 2 on leave.
        local dashboard_tabline_group = vim.api.nvim_create_augroup("DashboardHideTabline", { clear = true })
        vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
            group = dashboard_tabline_group,
            callback = function()
                if vim.bo.filetype == "snacks_dashboard" then
                    vim.o.showtabline = 0
                end
            end,
        })
        vim.api.nvim_create_autocmd("User", {
            group = dashboard_tabline_group,
            pattern = "VeryLazy",
            callback = function()
                if vim.bo.filetype == "snacks_dashboard" then
                    vim.o.showtabline = 0
                end
            end,
        })
        vim.api.nvim_create_autocmd("BufLeave", {
            group = dashboard_tabline_group,
            callback = function(ev)
                if vim.bo[ev.buf].filetype == "snacks_dashboard" then
                    vim.o.showtabline = 2
                end
            end,
        })

        return vim.tbl_deep_extend("force", opts, {
            statuscolumn = { enabled = false },
            -- Until now snacks.image was only reached through the picker preview
            -- and the dashboard; declaring it here turns it on for real buffers.
            -- Both automatic doc modes are off on purpose: no images drawn inline
            -- on their own, and no hover float when the cursor lands on a fence.
            -- config/mermaid.lua renders ```mermaid fences to PNG itself (mmdr, no
            -- Chromium) and uses only the placement API here, on demand —
            -- <localleader>mm for a float, <localleader>mi for inline (needs
            -- unicode placeholders, i.e. bare Ghostty; the Zellij patch above
            -- leaves them off). Termux has no graphics protocol at all — the text
            -- renderer covers it there.
            image = {
                doc = {
                    inline = false,
                    float = false,
                },
            },
            ---@type snacks.scratch.Config
            scratch = {
                -- Markdown always, instead of inheriting the current buffer's
                -- filetype (scratches are used for notes, not code eval)
                ft = "markdown",
                filekey = {
                    cwd = true, -- scope per project
                    branch = false, -- but not per git branch
                    count = false,
                },
                win = {
                    -- Open the scratch in the current window as a normal
                    -- buffer (no float/split). buflisted = true so it shows
                    -- up as a bufferline chip like any other file; snacks'
                    -- autowrite unlists it again on hide, so leaving the
                    -- scratch (tab-switch or opening another) saves it and
                    -- drops the chip.
                    position = "current",
                    bo = { buflisted = true },
                    -- fixbuf guards a dedicated window by swapping other
                    -- buffers back out — meaningless in current-window mode,
                    -- and with two scratches sharing one window the guards
                    -- recurse (BufWinEnter -> nvim_win_set_buf, "nesting too
                    -- deep"). Off: switch buffers freely in this window.
                    fixbuf = false,
                },
            },
            styles = {
                zen = {
                    -- ctrl-tab exits while switching tabs rather than changing tab and maintaining the zen view
                    fixbuf = true,
                    -- no line numbers, git_signs, etc.
                    minimal = true,
                    -- minimal sets wrap = false, so re-enable it
                    -- TODO is there a way to do this only if wrap was originally set (or, if not, only for markdown files?)
                    wo = { wrap = true },
                    backdrop = {
                        transparent = false,
                        bg = (function()
                            local hl = vim.api.nvim_get_hl(0, { name = "Normal" })
                            if not hl.bg then
                                return nil
                            end
                            local r = math.floor(bit.rshift(hl.bg, 16) * 0.9)
                            local g = math.floor(bit.band(bit.rshift(hl.bg, 8), 0xFF) * 0.9)
                            local b = math.floor(bit.band(hl.bg, 0xFF) * 0.9)
                            return string.format("#%02x%02x%02x", r, g, b)
                        end)(),
                    },
                },
            },
            -- Disable snacks' explorer entirely. With enabled=false, snacks never
            -- runs explorer.setup(), so it never hijacks netrw / directory buffers
            -- (that hijack is gated solely on this flag). mini.files is the default
            -- explorer instead — see mini.files.lua.
            explorer = { enabled = false },
            ---@type snacks.dashboard
            dashboard = {
                preset = {
                    -- `pick` is inherited from the LazyVim-clone spec via deep
                    -- merge; only the empty `keys` override is needed here.
                    keys = {},
                },
                sections = {
                    SPLASH == "image" and dog_image_section()
                        or SPLASH == "chafa" and dog_header_section()
                        or simple_info_section(),
                    -- Hidden items: keys are bound but nothing renders.
                    { key = "s", section = "session", hidden = true },
                    { key = "q", action = ":qa", hidden = true },
                },
            },
            dim = {
                scope = {
                    min_size = 2,
                    max_size = 10,
                    siblings = true,
                },
                animate = {
                    enabled = true,
                    easing = "outQuad",
                    duration = {
                        step = 20,
                        total = 300,
                    },
                },
            },
            zen = {
                toggles = {
                    dim = true,
                },
                win = {
                    width = function()
                        return vim.o.columns > 130 and 120 or vim.o.columns - 10
                    end,
                },
                zoom = {
                    center = true,
                    win = {
                        backdrop = true,
                        width = function()
                            return vim.o.columns > 240 and 200 or vim.o.columns - 40
                        end,
                    },
                },
            },
        })
    end,
}
