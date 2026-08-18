return {
    "akinsho/bufferline.nvim",
    optional = true,
    -- Merge into (not replace) the clone's bufferline opts, so its defaults
    -- survive: close_command = Snacks.bufdelete, diagnostics in the bufferline,
    -- always_show_bufferline = false, sidebar offsets, etc.
    opts = function(_, opts)
        local bufferline = require("bufferline")
        local mocha = require("catppuccin.palettes").get_palette("mocha")
        if (vim.g.colors_name or ""):find("catppuccin") then
            opts.highlights = require("catppuccin.special.bufferline").get_theme({
                styles = { "italic", "bold" },
                custom = {
                    all = {
                        buffer_selected = { fg = mocha.peach },
                        buffer_visible = { fg = mocha.peach },
                    },
                },
            })
        end
        opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
            style_preset = bufferline.style_preset.default,
            themeable = true,
            numbers = "none",
            separator_style = "slant",
            indicator = {
                -- style = 'underline',
                style = "none",
            },
            border = {
                -- `1` for top/bottom and `2` for left/right
                padding = { 1, 2 },
            },
        })
        return opts
    end,
}
