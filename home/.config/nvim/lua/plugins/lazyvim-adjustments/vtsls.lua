-- vtsls (TypeScript LSP) preference tweaks — checklist section D.
--
-- The base vtsls settings live in lua/LazyVim-clone/.../lang/typescript/vtsls.lua.
-- These deep-merge on top. D3 (keep minimal inlay hints) and D5
-- (updateImportsOnFileMove = "always") already match the base config, so they're
-- intentionally left untouched here.

local preferences = {
    -- D1: how auto-imports are written.
    importModuleSpecifier = "shortest",
    -- Alternative: prefer path aliases / package names over deep relative paths.
    -- Swap the line above for this to switch:
    -- importModuleSpecifier = "non-relative",

    -- D2: write auto-imported types as `import type { ... }`
    -- (pairs with the eslint `consistent-type-imports` rule).
    preferTypeOnlyAutoImports = true,
}

return {
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                vtsls = {
                    -- D4: Prettier (other filetypes) / ESLint Stylistic (TS/JS) own
                    -- formatting. Strip vtsls's formatting capability entirely so it
                    -- is never used as an LSP-format fallback and never errors. We do
                    -- this at the capability level (not just `format.enable = false`)
                    -- because vtsls still advertises the provider otherwise, which
                    -- triggers "Cannot find provider for documentRangeFormatting"
                    -- when conform's lsp_format fallback calls it.
                    on_attach = function(client)
                        client.server_capabilities.documentFormattingProvider = false
                        client.server_capabilities.documentRangeFormattingProvider = false
                    end,
                    settings = {
                        typescript = { preferences = preferences },
                        javascript = { preferences = preferences },
                    },
                },
            },
        },
    },
}
