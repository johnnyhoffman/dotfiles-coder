-- Workspace-only marksman fix (lives in coder/overlay/, not shared/ — every
-- personal machine has ICU).
--
-- The Coder Ubuntu image ships without libicu, and mason's marksman is a
-- self-contained .NET binary: on startup it aborts (SIGABRT, exit 134) with
-- "Couldn't find a valid ICU package installed on the system" the moment a
-- markdown buffer opens. Invariant globalization mode sidesteps ICU entirely;
-- marksman doesn't need culture-aware string handling, and this is the
-- workaround its docs point to.
return {
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                marksman = {
                    cmd_env = { DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1" },
                },
            },
        },
    },
}
