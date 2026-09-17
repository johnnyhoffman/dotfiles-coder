-- Workspace-only octo.nvim tweaks (lives in coder/overlay/, not shared/).
--
-- The workspace shell authenticates gh through the Coder-provisioned
-- $GH_TOKEN, which only carries repo + workflow. Octo's gh calls run with a
-- hand-built env allowlist that forwards HOME but not GH_TOKEN, so they fall
-- through to ~/.config/gh/hosts.yml → ~/.coder-auth/gh-hosts.yml, where a
-- separate `env -u GH_TOKEN gh auth login` with read:org lives. Do NOT add a
-- gh_env override here: that would push the narrower token back into octo.
--
-- default_to_projects_v2 (on in the LazyVim extra) needs read:project, which
-- the login below may not carry; keep it off unless you want project fields.
return {
    {
        "pwntester/octo.nvim",
        opts = {
            default_to_projects_v2 = false,
        },
    },
}
