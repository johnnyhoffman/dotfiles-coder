return {
    {
        "nvim-lualine/lualine.nvim",
        opts = function(_, opts)
            local progress = require("scripts.lsp-progress")
            opts.sections = opts.sections or {}
            opts.sections.lualine_x = opts.sections.lualine_x or {}
            table.insert(opts.sections.lualine_x, 1, {
                function()
                    -- obsidian-ls progress was suppressed by noice's route filter;
                    -- keep it out of the statusline now that progress flows here.
                    return progress.status({ exclude = { "obsidian-ls" }, exclude_in_insert = { "ltex_plus" } })
                end,
            })
        end,
    },
}
