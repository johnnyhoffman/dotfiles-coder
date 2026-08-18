-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
--
local opt = vim.opt
local o = vim.o
local g = vim.g

opt.exrc = true -- Source .nvim.lua from project directories (with trust prompt)

opt.shiftwidth = 4 -- Size of an indent
opt.tabstop = 4 -- Number of spaces tabs count for
opt.list = true -- Show some invisible characters (tabs...
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
o.shell = "/bin/zsh"

-- LazyVim completion engine to use.
-- Can be one of: nvim-cmp, blink.cmp
-- Leave it to "auto" to automatically use the completion engine
-- enabled with `:LazyExtras`
g.lazyvim_cmp = "blink.cmp"

-- TODO decide
--
-- if the completion engine supports the AI source,
-- use that instead of inline suggestions
g.ai_cmp = true

opt.scrolloff = 15 -- Lines of context
opt.sidescrolloff = 24 -- Columns of context

opt.wrap = true
-- wrap at word boundaries
-- preserve indentation
opt.linebreak = true
opt.breakindent = true
-- visual indicator
-- some I like: "--->", "--> ", "↪   ", "╰-> ", "🯒-> ", "╙-> ", "🮫-> ", "🯐->", "𜰼𜰽𜰾𜲂", "╰─𜲂 ", "🮡┉𜲂 "
opt.showbreak = "🮡┉┉𜲂"
-- Clipboard / OSC 52
--
-- OSC 52 lets remote Neovim send yanked text to the local terminal's
-- clipboard via escape sequences — no X11/Wayland display needed.
--
-- Since Zellij 0.44.1, Zellij reports OSC 52 support via DA1, so Neovim
-- auto-detects it inside Zellij. This means copy works even when attaching
-- to an existing Zellij session over SSH (where SSH_CONNECTION isn't
-- inherited from the new SSH shell).
--
-- We still explicitly override vim.g.clipboard when SSH_CONNECTION is set:
--   1. Without Zellij, wl-copy is installed on the Arch boxes and Neovim
--      prefers it over OSC 52. wl-copy silently fails over SSH (no
--      Wayland display), so we force OSC 52.
--   2. Inside Zellij, OSC 52 *paste* (read) times out because Zellij
--      doesn't relay read responses. The cache workaround lets `p` paste
--      text yanked within the same Neovim session. For external clipboard
--      inside Zellij over SSH, use Cmd+Shift+V.
--
-- Requires Ghostty clipboard-read/write = allow (see {mac,arch}/.config/ghostty/config).
if vim.env.SSH_CONNECTION then
    local osc52 = require("vim.ui.clipboard.osc52")
    local cache = {}

    local function cached_copy(reg)
        local osc_copy = osc52.copy(reg)
        return function(lines, regtype)
            cache[reg] = { lines, regtype }
            return osc_copy(lines, regtype)
        end
    end

    local function make_paste(reg)
        if vim.env.ZELLIJ then
            return function()
                return cache[reg]
            end
        end
        return osc52.paste(reg)
    end

    vim.g.clipboard = {
        name = "OSC 52",
        copy = {
            ["+"] = cached_copy("+"),
            ["*"] = cached_copy("*"),
        },
        paste = {
            ["+"] = make_paste("+"),
            ["*"] = make_paste("*"),
        },
    }
end

-- LazyVim sets clipboard="" over SSH (so only "+y uses the system clipboard).
-- We override to unnamedplus everywhere so regular y/p always sync.
opt.clipboard = "unnamedplus"

-- Markview hybrid mode: when true, the cursor line shows raw markdown in normal mode.
-- When false, normal mode is fully rendered with a manual toggle (<c-r>) for raw/rendered.
g.markview_use_hybrid_mode = false

-- Drop the native "progress:c" flag (nvim 0.12 default) that renders LSP
-- $/progress in the cmdline. With cmdheight=0 that draws over the statusline
-- (terminal bg, full width) -- a duplicate of the progress we already show in
-- lualine via scripts/lsp-progress.lua.
opt.messagesopt:remove("progress:c")
