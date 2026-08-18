return {
    "folke/lazydev.nvim",
    opts = function(_, opts)
        table.insert(opts.library, { path = "catppuccin", words = { "Catppuccin", "Ctp" } })
    end,
}
