-- ltex-ls-plus: LanguageTool grammar/spell checking for markdown and TeX.
--
-- ltex is the DEEP pass, not the always-on one. ../added/harper-ls.lua runs
-- continuously and covers spelling plus the common grammar slips; ltex is a JVM
-- that re-checks the whole document on every change, so it is started by hand
-- when a document is worth a full LanguageTool sweep rather than left attached
-- to every prose buffer.
--
-- Keymaps, normal mode, in the prose filetypes below:
--     <localleader>gg  attach ltex to this buffer / detach it again
--     <localleader>gG  stop the ltex server outright, every buffer
--
-- Once attached it is a live checker -- squiggles clear as you fix things --
-- with insert-mode checks suppressed (see below) so typing stays smooth.
-- Detaching clears its diagnostics, which is what makes the toggle read as
-- "show me the grammar problems" / "put them away".

local LTEX_FILETYPES = { "markdown", "text", "plaintex", "tex", "gitcommit" }

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
                -- The client can be gone by now -- <localleader>gG, or a crash
                -- mid-edit -- and reattaching a dead id errors.
                if vim.lsp.get_client_by_id(id) then
                    vim.lsp.buf_attach_client(args.buf, id)
                end
            end
        end,
    })
end

---------------------------------------------------------------------------
-- On-demand start/stop
---------------------------------------------------------------------------

local function ltex_clients(bufnr)
    return vim.lsp.get_clients({ bufnr = bufnr, name = "ltex_plus" })
end

-- Start ltex for one buffer, from the config registered in `setup` below
-- (merged with the cmd/filetypes defaults lspconfig ships in lsp/ltex_plus.lua).
-- root_dir has to be a concrete path: vim.lsp.start does not run the root-marker
-- search that vim.lsp.enable's autocmd would, and cwd is what the auto-attaching
-- version resolved to anyway. Starting in a second buffer reuses the running
-- client rather than paying for another JVM.
local function ltex_start(bufnr)
    local config = vim.lsp.config.ltex_plus
    if not config then
        vim.notify("ltex: no LSP config registered for ltex_plus", vim.log.levels.ERROR)
        return
    end
    return vim.lsp.start(vim.tbl_extend("force", config, { root_dir = vim.fn.getcwd() }), { bufnr = bufnr })
end

local function ltex_toggle()
    local bufnr = vim.api.nvim_get_current_buf()
    local clients = ltex_clients(bufnr)
    if #clients == 0 then
        if ltex_start(bufnr) then
            vim.notify("ltex: checking " .. vim.fn.expand("%:t"), vim.log.levels.INFO)
        end
        return
    end
    -- Detaching clears this client's diagnostics for the buffer; stopping it
    -- once nothing is left attached keeps the JVM from idling on afterwards.
    vim.b[bufnr].ltex_suppressed_ids = nil
    for _, client in ipairs(clients) do
        vim.lsp.buf_detach_client(bufnr, client.id)
        if vim.tbl_isempty(client.attached_buffers or {}) then
            vim.lsp.stop_client(client.id)
        end
    end
    vim.notify("ltex: off", vim.log.levels.INFO)
end

local function ltex_stop_all()
    local clients = vim.lsp.get_clients({ name = "ltex_plus" })
    if #clients == 0 then
        vim.notify("ltex: not running", vim.log.levels.INFO)
        return
    end
    for _, client in ipairs(clients) do
        vim.lsp.stop_client(client.id)
    end
    vim.notify("ltex: stopped", vim.log.levels.INFO)
end

return {
    {
        "neovim/nvim-lspconfig",
        -- The keymaps have to exist before ltex does -- they are what starts it
        -- -- so they bind per prose buffer on FileType, not on LSP attach.
        init = function()
            vim.api.nvim_create_autocmd("FileType", {
                group = vim.api.nvim_create_augroup("LtexOnDemand", { clear = true }),
                pattern = LTEX_FILETYPES,
                callback = function(args)
                    vim.keymap.set("n", "<localleader>gg", ltex_toggle, {
                        buffer = args.buf,
                        desc = "Grammar: ltex deep check on this buffer (toggle)",
                    })
                    vim.keymap.set("n", "<localleader>gG", ltex_stop_all, {
                        buffer = args.buf,
                        desc = "Grammar: stop the ltex server",
                    })
                    pcall(function()
                        require("which-key").add({ { "<localleader>g", buffer = args.buf, group = "grammar" } })
                    end)
                end,
            })
        end,
        opts = {
            setup = {
                -- Register the config without enabling it. Returning true tells
                -- LazyVim to skip its own vim.lsp.enable() AND to exclude ltex
                -- from mason-lspconfig's automatic_enable, which leaves
                -- <localleader>gg as the only thing that starts the server. The
                -- config still has to be registered so that vim.lsp.config
                -- .ltex_plus resolves when the keymap fires.
                ltex_plus = function(server, sopts)
                    vim.lsp.config(server, sopts)
                    return true
                end,
            },
            servers = {
                ltex_plus = {
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
                        -- current). harper does the same on its own attach, so
                        -- this only matters where harper isn't running.
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
                    filetypes = LTEX_FILETYPES,
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
