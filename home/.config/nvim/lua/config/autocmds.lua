-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Register LSP progress tracker early — its autocmd must exist before any LSP
-- client attaches, otherwise the first begin/report events are lost.
require("scripts.lsp-progress")

-- Personal-machine-only autocmds (j-* tooling, Obsidian vault stack) — the
-- module is absent on work machines, where the generated dotfiles (coder/)
-- exclude it. Only a missing module is tolerated; real errors still surface.
local ok, err = pcall(require, "config.personal")
if not ok and not tostring(err):match("module 'config%.personal' not found") then
    vim.notify("config.personal failed to load: " .. tostring(err), vim.log.levels.ERROR)
end

-- Disable wrapping for Zellij pane dumps (*.dump files).
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("dump_nowrap", { clear = true }),
    pattern = "*.dump",
    callback = function()
        vim.opt_local.wrap = false
    end,
})

-- Wrap long lines in Neogit buffers so diffs don't get truncated. Covers the
-- status view, the commit view (vsplit), etc. Neogit hard-sets wrap=false at
-- buffer creation (lib/buffer.lua) right after FileType fires, so we defer with
-- vim.schedule to run after that and re-enable wrap on the buffer's window(s).
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("neogit_wrap", { clear = true }),
    pattern = "Neogit*",
    callback = function(args)
        vim.schedule(function()
            for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
                vim.wo[win].wrap = true
            end
        end)
    end,
})

-- Remove non-restorable buffers before session save so they don't
-- break session restore.
vim.api.nvim_create_autocmd("User", {
    pattern = "PersistenceSavePre",
    callback = function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            local name = vim.api.nvim_buf_get_name(buf)
            local ft = vim.bo[buf].filetype
            if name:match("claude%-prompt%-.*%.md") or ft == "NeogitStatus" or ft:match("^Neogit") then
                vim.api.nvim_buf_delete(buf, { force = true })
            end
        end
    end,
})

-- Order code actions by LSP server: ltex_plus (grammar/spelling fixes) before
-- the markdown servers. Neovim lists actions in client order and never sorts
-- them, so wrap vim.ui.select and stable-sort codeaction items by server
-- priority. This file loads on VeryLazy, after snacks has installed its
-- vim.ui.select at UIEnter, so the wrapper composes with the snacks picker.
do
    -- Unlisted servers sort after these, keeping their original order.
    local server_priority = { ltex_plus = 1, ["obsidian-ls"] = 2, marksman = 3 }
    local base_select = vim.ui.select
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.ui.select = function(items, opts, on_choice)
        if opts and opts.kind == "codeaction" then
            -- Each item is {action, ctx} (see vim.lsp.buf.code_action).
            local keyed = {}
            for i, item in ipairs(items) do
                local client = item.ctx and vim.lsp.get_client_by_id(item.ctx.client_id)
                local prio = (client and server_priority[client.name]) or math.huge
                keyed[i] = { item = item, prio = prio, idx = i }
            end
            table.sort(keyed, function(a, b)
                if a.prio ~= b.prio then
                    return a.prio < b.prio
                end
                return a.idx < b.idx
            end)
            items = {}
            for i, k in ipairs(keyed) do
                items[i] = k.item
            end
        end
        return base_select(items, opts, on_choice)
    end
end

-- Neogit integration: side-by-side diff for commit ranges.
-- Normal mode on a commit: diff against its parent.
-- Visual mode across commits: diff range between first and last selected.
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("neogit_range_diff", { clear = true }),
    pattern = { "NeogitStatus", "NeogitLogView" },
    callback = function(ev)
        local function get_ui()
            local ft = vim.bo.filetype
            local mod_name = ft == "NeogitStatus" and "neogit.buffers.status"
                or ft == "NeogitLogView" and "neogit.buffers.log_view"
            if not mod_name then
                return
            end
            local ok, mod = pcall(require, mod_name)
            if not ok then
                return
            end
            local inst = type(mod.instance) == "function" and mod.instance() or mod.instance
            return inst and inst.buffer and inst.buffer.ui
        end

        local function resolve_parent(oid)
            local parent = vim.fn.system({ "git", "rev-parse", "--verify", oid .. "^" }):gsub("%s+$", "")
            if vim.v.shell_error ~= 0 then
                return "4b825dc642cb6eb9a060e54bf899d69f82e3a8d5" -- empty tree (root commit)
            end
            return parent
        end

        local function collect_commits_in_range(ui, line_start, line_end)
            local save_cursor = vim.api.nvim_win_get_cursor(0)
            local commits, seen = {}, {}
            for line = line_start, line_end do
                vim.api.nvim_win_set_cursor(0, { line, 0 })
                local oid = ui:get_commit_under_cursor()
                if oid and not seen[oid] then
                    seen[oid] = true
                    commits[#commits + 1] = oid
                end
            end
            vim.api.nvim_win_set_cursor(0, save_cursor)
            return commits
        end

        vim.keymap.set("x", "d", function()
            -- Read visual bounds now (marks aren't set yet in x-mode Lua callbacks)
            local line_start = vim.fn.line("v")
            local line_end = vim.fn.line(".")
            if line_start > line_end then
                line_start, line_end = line_end, line_start
            end

            local ui = get_ui()
            if not ui then
                return vim.notify("Could not access Neogit UI", vim.log.levels.ERROR)
            end
            local commits = collect_commits_in_range(ui, line_start, line_end)
            if #commits == 0 then
                return vim.notify("No commits in selection", vim.log.levels.WARN)
            end
            -- Log views are newest-first: commits[1] = newest, commits[#] = oldest
            local oldest = commits[#commits]
            local newest = commits[1]
            require("config.git-range-diff").open(resolve_parent(oldest), newest)
        end, { buffer = ev.buf, desc = "Diff commit range (side-by-side)" })

        vim.keymap.set("n", "d", function()
            local ui = get_ui()
            if not ui then
                return vim.notify("Could not access Neogit UI", vim.log.levels.ERROR)
            end
            local oid = ui:get_commit_under_cursor()
            if not oid then
                return vim.notify("No commit under cursor", vim.log.levels.WARN)
            end
            require("config.git-range-diff").open(resolve_parent(oid), oid)
        end, { buffer = ev.buf, desc = "Diff commit (side-by-side)" })
    end,
})

-- Hand Neovim's final cwd back to the shell on exit. A child process can't move
-- its parent's shell, so the zsh `nvim` wrapper (zsh/shared/aliases.sh) passes a
-- temp file via $NVIM_CWD_FILE and cds to whatever we write into it. Point of
-- this: neogit's worktree popup (`w` from the status buffer) calls
-- nvim_set_current_dir on the worktree it checks out or visits, and this makes
-- that stick after you quit.
-- getcwd(-1, -1) is the global cwd, ignoring any tab/window-local :lcd.
vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("shell_cwd_handoff", { clear = true }),
    callback = function()
        local out = vim.env.NVIM_CWD_FILE
        if out and out ~= "" then
            pcall(vim.fn.writefile, { vim.fn.getcwd(-1, -1) }, out)
        end
    end,
})
