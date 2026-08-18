return {
    -- Not declared here are the items added through the Mason UI and dependencies inline with other plugins e.g. ../added/ltex-ls-plus.lua
    {
        "mason-org/mason.nvim",
        opts = {
            ensure_installed = { "prettier", "eslint-lsp" },
        },
    },
}
