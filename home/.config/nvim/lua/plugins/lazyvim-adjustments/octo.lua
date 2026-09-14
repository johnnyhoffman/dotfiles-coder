-- Workspace-only octo.nvim auth fix (lives in coder/overlay/, not shared/ —
-- personal machines log in with `gh auth login`, which needs nothing here).
--
-- The workspace authenticates gh purely through $GH_TOKEN (no hosts.yml).
-- octo runs gh with a hand-built environment allowlist that forwards
-- GITHUB_TOKEN but not GH_TOKEN, so every <leader>gh… picker hit "You are not
-- logged into any GitHub hosts" while `gh pr list` in the shell worked fine.
-- gh_env merges into that allowlist; the function form reads the variable at
-- each gh call rather than once at spec load.
return {
    {
        "pwntester/octo.nvim",
        opts = {
            gh_env = function()
                return { GH_TOKEN = vim.env.GH_TOKEN }
            end,
        },
    },
}
