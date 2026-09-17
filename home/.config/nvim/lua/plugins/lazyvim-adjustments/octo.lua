-- Workspace-only octo.nvim tweaks (lives in coder/overlay/, not shared/).
--
-- The workspace shell authenticates gh through the Coder-provisioned
-- $GH_TOKEN, which only carries repo + workflow (no read:org, so octo's
-- queries fail with it). Octo gets its own gh login instead, kept in a
-- dedicated config dir so it never mixes with the shell's token:
--
--   mkdir -m 700 ~/.coder-auth/gh-octo
--   GH_CONFIG_DIR=~/.coder-auth/gh-octo env -u GH_TOKEN gh auth login -s read:org
--
-- gh_env merges into the env allowlist octo hands its gh subprocesses.
-- Pinning GH_CONFIG_DIR there makes gh read that dir's hosts.yml directly:
-- no ~/.config/gh symlink involved, and if a future octo starts forwarding
-- GH_TOKEN it changes nothing, since GH_CONFIG_DIR is what selects the
-- account. ~/.coder-auth/ is synced to S3 by the workspace agent, so the
-- login carries over to new workspaces. Do NOT set GH_TOKEN here: an empty
-- value is "unset" in some gh versions and "bad token" in others.
--
-- default_to_projects_v2 (on in the LazyVim extra) needs read:project on
-- that login; keep it off unless you add the scope and want project fields.
return {
    {
        "pwntester/octo.nvim",
        opts = {
            default_to_projects_v2 = false,
            gh_env = { GH_CONFIG_DIR = vim.fn.expand("~/.coder-auth/gh-octo") },
        },
    },
}
