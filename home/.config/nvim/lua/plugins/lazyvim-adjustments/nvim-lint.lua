return {
    {
        "mfussenegger/nvim-lint",
        optional = true,
        init = function()
            -- Show markdownlint diagnostics as a squiggly underline only (no
            -- virtual text), the same treatment ltex gets. Scoped to this one
            -- linter's namespace (nvim-lint gives each linter its own, keyed by
            -- name), so every other linter keeps its virtual text. The namespace
            -- is created once and reused, so configuring it a single time on load
            -- sticks across all lint runs.
            LazyVim.on_load("nvim-lint", function()
                local ns = require("lint").get_namespace("markdownlint-cli2")
                vim.diagnostic.config({ virtual_text = false, underline = true }, ns)
            end)
        end,
        opts = {
            -- LazyVim markdown extra enables markdownlint for markdown (and mdx).
            -- Keep markdown diagnostics but silence a couple noisy rules.
            --
            -- markdownlint-cli2 has no --disable flag (that's markdownlint-cli v1),
            -- so rules are disabled via a lint-specific config file. The trailing
            -- "-" restores nvim-lint's builtin stdin arg (overriding args replaces
            -- it, which previously left it linting 0 files).
            linters = {
                ["markdownlint-cli2"] = {
                    args = {
                        "--config",
                        vim.fn.stdpath("config") .. "/lint.markdownlint-cli2.yaml",
                        "-",
                    },
                },
            },
        },
    },
}
