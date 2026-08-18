-- Rewrites TypeScript's dense diagnostic messages into plain English by
-- intercepting publishDiagnostics from TS-family language servers (vtsls,
-- svelte, etc. — see auto_override_publish_diagnostics defaults).
return {
    "dmmulroy/ts-error-translator.nvim",
    ft = {
        "typescript",
        "typescriptreact",
        "javascript",
        "javascriptreact",
        "svelte",
    },
    opts = {},
}
