-- ltex-ls-plus: Grammar/spell checking LSP for markdown
-- Uses LanguageTool under the hood

local LTEX_PROGRESS_TOKEN = "ltex_plus_progress"
local LTEX_END_DEBOUNCE_MS = 1500
local ltex_end_timer = nil

local function clear_ltex_end_timer()
    if ltex_end_timer then
        ltex_end_timer:stop()
        if not ltex_end_timer:is_closing() then
            ltex_end_timer:close()
        end
        ltex_end_timer = nil
    end
end

local function ltex_progress_handler(err, result, ctx, config)
    local default = vim.lsp.handlers["$/progress"]
    if not result or not result.value then
        return default(err, result, ctx, config)
    end
    result.token = LTEX_PROGRESS_TOKEN
    local kind = result.value.kind
    if kind == "begin" or kind == "report" then
        clear_ltex_end_timer()
        return default(err, result, ctx, config)
    elseif kind == "end" then
        clear_ltex_end_timer()
        ltex_end_timer = vim.uv.new_timer()
        ltex_end_timer:start(
            LTEX_END_DEBOUNCE_MS,
            0,
            vim.schedule_wrap(function()
                clear_ltex_end_timer()
                default(err, result, ctx, config)
            end)
        )
        return
    end
    return default(err, result, ctx, config)
end

-- Check if buffer front matter contains "ltex: false"
local function should_disable_ltex(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 30, false)
    local in_frontmatter = false
    for _, line in ipairs(lines) do
        if line:match("^%-%-%-$") then
            if in_frontmatter then
                return false
            end
            in_frontmatter = true
        elseif in_frontmatter and line:match("^ltex:%s*false") then
            return true
        end
    end
    return false
end

-- Skip ltex entirely for very large files. ltex checks the whole document at
-- once, and a single full-document pass on a huge buffer can stutter the UI.
-- This is gated at attach-decision time (via root_dir below) so the costly
-- initial check is never even dispatched. No general claim that large files
-- need less grammar checking -- this is purely a freeze-avoidance backstop.
local LTEX_MAX_LINES = 5000
local function is_too_large(bufnr)
    return vim.api.nvim_buf_line_count(bufnr) > LTEX_MAX_LINES
end

-- Suppress ltex while in insert mode. ltex re-checks the whole document on
-- every keystroke and emits a $/progress flood, yet `update_in_insert = false`
-- means the resulting diagnostics aren't applied until InsertLeave -- so the
-- in-insert checks are pure wasted work (and the main source of typing freezes).
-- We detach the ltex client on InsertEnter (stops didChange, hence no checks;
-- this also clears the squiggles, matching pre-existing behaviour) and reattach
-- on InsertLeave (one didOpen -> a single check once typing settles).
-- The augroup is created once, on first ltex attach, and matches ltex buffers
-- dynamically -- so it survives the detach/reattach cycle without duplicating.
local insert_autocmds_created = false
local function ensure_insert_autocmds()
    if insert_autocmds_created then
        return
    end
    insert_autocmds_created = true
    local group = vim.api.nvim_create_augroup("LtexInsertSuppress", { clear = true })
    vim.api.nvim_create_autocmd("InsertEnter", {
        group = group,
        callback = function(args)
            local clients = vim.lsp.get_clients({ bufnr = args.buf, name = "ltex_plus" })
            if #clients == 0 then
                return
            end
            local ids = {}
            for _, client in ipairs(clients) do
                ids[#ids + 1] = client.id
                vim.lsp.buf_detach_client(args.buf, client.id)
            end
            vim.b[args.buf].ltex_suppressed_ids = ids
        end,
    })
    vim.api.nvim_create_autocmd("InsertLeave", {
        group = group,
        callback = function(args)
            local ids = vim.b[args.buf].ltex_suppressed_ids
            if not ids then
                return
            end
            vim.b[args.buf].ltex_suppressed_ids = nil
            for _, id in ipairs(ids) do
                vim.lsp.buf_attach_client(args.buf, id)
            end
        end,
    })
end

return {
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                ltex_plus = {
                    -- Gate attachment: never attach (and so never run the costly
                    -- initial check) for very large files, or files that opt out
                    -- via `ltex: false` front matter. on_dir must be called for
                    -- the server to activate, so skipping it skips ltex entirely
                    -- -- which means there are no diagnostics to filter later.
                    root_dir = function(bufnr, on_dir)
                        if is_too_large(bufnr) or should_disable_ltex(bufnr) then
                            return
                        end
                        on_dir(vim.fn.getcwd())
                    end,
                    -- Coalesce normal-mode edit bursts (substitutions, paste,
                    -- macros, undo/redo) into fewer full-document checks. Default
                    -- is 150ms; ltex is heavy enough to warrant more. Insert-mode
                    -- checks are eliminated separately via detach/reattach.
                    flags = {
                        debounce_text_changes = 500,
                    },
                    on_attach = function(client, bufnr)
                        ensure_insert_autocmds()
                        -- Disable built-in spell in the window(s) actually showing
                        -- this buffer (not just whatever window happens to be
                        -- current). Disabled buffers never reach on_attach -- see
                        -- root_dir above.
                        for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
                            vim.wo[win].spell = false
                        end
                        -- Show ltex diagnostics as squiggly underline only, no
                        -- inline virtual-text overlay, so prose stays readable.
                        -- View the full message on demand with the diagnostic float
                        -- (LazyVim: <leader>cd, or hover). Scoped to ltex's own
                        -- namespace so other sources keep their virtual text.
                        local ns = vim.lsp.diagnostic.get_namespace(client.id)
                        vim.diagnostic.config({ virtual_text = false, underline = true }, ns)
                    end,
                    handlers = {
                        -- Coalesce per-keystroke progress into a single entry. ltex
                        -- emits a fresh begin/end token per check on every keystroke,
                        -- which the lualine progress display renders as a flood of
                        -- separate "completed" entries and prevents the spinner from
                        -- animating. We rewrite all tokens to one shared token, and
                        -- debounce "end" so the task only completes once ltex has
                        -- actually been idle for a moment.
                        ["$/progress"] = ltex_progress_handler,
                    },
                    filetypes = { "markdown", "text", "plaintex", "tex", "gitcommit" },
                    settings = {
                        ltex = {
                            language = "en-US",
                            -- commented out to use intern LanguageTool server
                            -- languageToolHttpServerUri = "http://jh:8010",
                            additionalRules = {
                                enablePickyRules = true,
                            },
                            -- Disable specific rules by ID
                            -- Find rule IDs in the diagnostic message (e.g., "EN_QUOTES")
                            disabledRules = {
                                ["en-US"] = { "EN_QUOTES", "DASH_RULE", "HYPHEN_TO_EN" },
                            },
                            -- Reduce noise for markdown-specific syntax
                            markdown = {
                                nodes = {
                                    CodeBlock = "ignore",
                                    FencedCodeBlock = "ignore",
                                    AutoLink = "dummy",
                                    Code = "dummy",
                                },
                            },
                            -- Hide false positives using Java regex patterns
                            -- Format: {"rule": "RULE_ID", "sentence": "java_regex"}
                            -- Backslashes: \\ in Lua raw string -> \ after JSON parse
                            hiddenFalsePositives = {
                                ["en-US"] = {
                                    -- Ignore Obsidian-style hashtags: #tag, #tag/subtag, #tag-name/sub/etc
                                    [[{"rule": "MORFOLOGIK_RULE_EN_US", "sentence": "#[\\w/-]+"}]],
                                },
                            },
                        },
                    },
                },
            },
        },
    },
    -- Ensure ltex-ls-plus is installed via mason
    {
        "mason-org/mason.nvim",
        opts = {
            ensure_installed = { "ltex-ls-plus" },
        },
    },
}
