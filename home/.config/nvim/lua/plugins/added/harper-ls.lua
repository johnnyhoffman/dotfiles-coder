-- harper-ls: the always-on grammar/spell checker for prose buffers.
--
-- Harper is a single Rust binary that re-checks in milliseconds, so unlike ltex
-- it needs none of the attach-gating, insert-mode suppression or progress
-- coalescing that ../added/ltex-ls-plus.lua carries -- it just runs. The two
-- split the work:
--     harper  always on, spelling plus the common grammar slips
--     ltex    on demand via <localleader>gg, full LanguageTool for a deep pass
-- Both can be attached at once; ltex will then re-report spelling that harper
-- already flagged, which is the price of the deeper sweep.
--
-- Dictionaries (user, workspace, file-local) live at harper's platform default
-- -- ~/Library/Application Support/harper-ls/ on macOS, ~/.config/harper-ls/ on
-- Linux -- so they are per-machine. Setting `userDictPath` to a file inside this
-- repo would make the vocabulary follow the dotfiles across hosts, at the cost
-- of a tracked file that the "add to dictionary" code action keeps rewriting.

return {
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                harper_ls = {
                    -- Prose only. lspconfig's default list also covers a couple
                    -- dozen programming languages (harper reads their comments),
                    -- which would put prose diagnostics in every code buffer --
                    -- a much larger change than swapping out ltex.
                    filetypes = { "markdown", "text", "gitcommit", "tex" },
                    on_attach = function(client, bufnr)
                        -- harper owns spelling now, so drop vim's own 'spell'
                        -- underline instead of double-underlining every typo.
                        -- Windows showing this buffer, not just the current one.
                        for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
                            vim.wo[win].spell = false
                        end
                        -- Squiggly underline only, no inline virtual text, so
                        -- prose stays readable -- the message is on demand from
                        -- the diagnostic float (LazyVim: <leader>cd). Scoped to
                        -- harper's own namespace, the same treatment ltex and
                        -- markdownlint get.
                        local ns = vim.lsp.diagnostic.get_namespace(client.id)
                        vim.diagnostic.config({ virtual_text = false, underline = true }, ns)
                    end,
                    settings = {
                        ["harper-ls"] = {
                            dialect = "American",
                            -- One notch above harper's own "hint" default, so an
                            -- always-on checker's findings stay legible at a
                            -- glance without reading as warnings.
                            diagnosticSeverity = "information",
                            -- Only deviations from harper's defaults belong here;
                            -- everything unlisted keeps its built-in setting.
                            linters = {
                                -- Notes are largely sentence fragments inside
                                -- bullets, so demanding a capital at the start of
                                -- every one is pure noise. Same call as the
                                -- punctuation rules disabled on the ltex side.
                                SentenceCapitalization = false,
                            },
                            markdown = {
                                -- Link text is usually a title, path or wikilink
                                -- target rather than English prose.
                                IgnoreLinkTitle = true,
                            },
                        },
                    },
                },
            },
        },
    },
    -- Ensure harper-ls is installed via mason
    {
        "mason-org/mason.nvim",
        opts = {
            ensure_installed = { "harper-ls" },
        },
    },
}
