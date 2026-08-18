-- minuet (AI completion) is disabled on mobile/Termux, and its spec file is
-- excluded entirely from the generated work dotfiles (coder/). Gate every
-- reference to it on availability — otherwise entering insert mode errors
-- when blink tries to activate a source whose module can't be loaded.
local has_minuet = not vim.g.mobile
    and vim.uv.fs_stat(vim.fn.stdpath("config") .. "/lua/plugins/added/minuet-ai.lua") ~= nil

local base_sources = { "lsp", "path", "buffer", "snippets" }
local default_sources = has_minuet and vim.list_extend(vim.deepcopy(base_sources), { "minuet" })
    or base_sources

local providers = {
    lsp = {
        transform_items = function(_, items)
            for _, item in ipairs(items) do
                if item.client_name == "obsidian-ls" and item.label:match("^Tag:") then
                    item.score_offset = (item.score_offset or 0) + 100
                    item.source_name = "Obsidian Tags"
                end
            end
            return items
        end,
    },
}
if has_minuet then
    providers.minuet = {
        name = "minuet",
        module = "minuet.blink",
        async = true,
        timeout_ms = 3000,
        score_offset = 50,
    }
end

return {
    "saghen/blink.cmp",
    opts = {
        -- experimental signature help support q
        signature = { enabled = true },
        keymap = {
            preset = "default",

            -- many of these are pasted from the default preset, just to be explicit about what the defaults are
            ["<C-space>"] = {
                function(cmp)
                    if require("blink.cmp").is_menu_visible() or require("blink.cmp").is_visible() then
                        cmp.show({ providers = default_sources })
                    else
                        cmp.show({ providers = base_sources })
                    end
                    cmp.show_documentation()
                    return true
                end,
            },

            ["<C-e>"] = { "hide", "fallback" },
            ["<C-y>"] = { "select_and_accept", "fallback" },

            ["<C-p>"] = { "select_prev", "fallback_to_mappings" },
            ["<C-n>"] = { "select_next", "fallback_to_mappings" },
            ["<Up>"] = false,
            ["<Down>"] = false,

            ["<C-6>"] = { "select_prev", "fallback_to_mappings" },
            ["<C-7>"] = { "show_documentation", "scroll_documentation_up", "fallback" },
            ["<C-8>"] = { "show_documentation", "scroll_documentation_down", "fallback" },
            ["<C-9>"] = { "select_next", "fallback_to_mappings" },

            ["<Tab>"] = { "snippet_forward", "fallback" },
            ["<S-Tab>"] = { "snippet_backward", "fallback" },

            ["<C-k>"] = { "show_signature", "hide_signature", "fallback" },
        },
        sources = {
            -- minuet (AI) added only when available — see has_minuet above.
            default = default_sources,
            providers = providers,
        },
        completion = {
            -- auto_insert conflicts with ghost text and is annoying when I didn't want something after cycling through
            list = { selection = { auto_insert = false } },
            -- Recommended to avoid unnecessary request
            trigger = { prefetch_on_insert = false },
        },
        appearance = {
            kind_icons = {
                openai = "󱢆",
                zai = "󱋒",
                fallback = "",
            },
        },
    },
}
