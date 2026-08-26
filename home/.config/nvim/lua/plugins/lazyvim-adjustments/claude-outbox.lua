-- Workspace-only Claude Code hook (lives in coder/overlay/, not shared/):
-- run ~/.claude/nvim/outbox.lua if a Claude skill has installed one there.
-- The file is written at runtime into the workspace's ~/.claude, so absence
-- is the normal case and skipped silently; real load errors still surface.
-- Fires on VeryLazy to match config/autocmds.lua timing, where the hook was
-- originally tested.
vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
        local path = vim.fn.expand("~/.claude/nvim/outbox.lua")
        if vim.uv.fs_stat(path) then
            local ok, err = pcall(dofile, path)
            if not ok then
                vim.notify("~/.claude/nvim/outbox.lua failed to load: " .. tostring(err), vim.log.levels.ERROR)
            end
        end
    end,
})

return {}
