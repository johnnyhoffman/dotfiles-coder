local custom_colors = {
    statuscolumn = {
        line_number = {
            ---@param colors CtpColors<string>
            active = function(colors)
                return colors.lavender
            end,
            ---@param colors CtpColors<string>
            inactive = function(colors)
                return colors.surface1
            end,
        },
    },
}
return {
    "catppuccin/nvim",
    ---@type CatppuccinOptions
    opts = {
        flavour = "mocha",
        custom_highlights = function(colors)
            return {
                -- Status column backgrounds
                -- SignColumn = { bg = "#1a1a2e" },
                -- LineNr = { fg = "#7f849c", bg = "#1e1e32" },
                LineNrAbove = {
                    fg = custom_colors.statuscolumn.line_number.inactive(colors),
                    -- bg = "#1e1e32"
                },
                LineNrBelow = {
                    fg = custom_colors.statuscolumn.line_number.inactive(colors),
                    -- bg = "#1e1e32"
                },
                CursorLineNr = {
                    fg = custom_colors.statuscolumn.line_number.active(colors),
                    -- bg = "#2a2a4a"
                },

                -- Markdown italic: use lavender instead of red (which clashes with bold/H1)
                ["@markup.italic"] = { fg = colors.lavender, italic = true },
                -- CursorLineNr = { fg = "#f5c2e7", bg = "#2a2a4a" },
                -- FoldColumn = { fg = "#89b4fa", bg = "#1a1a2e" },
                --
                -- -- Git sign highlights (fg = sign color, bg = gutter bg)
                -- GitSignsAdd = { fg = "#a6e3a1", bg = "#1a1a2e" },
                -- GitSignsChange = { fg = "#f9e2af", bg = "#1a1a2e" },
                -- GitSignsDelete = { fg = "#f38ba8", bg = "#1a1a2e" },
                -- GitSignsTopdelete = { fg = "#f38ba8", bg = "#1a1a2e" },
                -- GitSignsChangedelete = { fg = "#fab387", bg = "#1a1a2e" },
                -- GitSignsUntracked = { fg = "#94e2d5", bg = "#1a1a2e" },
                --
                -- -- Diagnostic sign highlights
                -- DiagnosticSignError = { fg = "#f38ba8", bg = "#1a1a2e" },
                -- DiagnosticSignWarn = { fg = "#f9e2af", bg = "#1a1a2e" },
                -- DiagnosticSignInfo = { fg = "#89b4fa", bg = "#1a1a2e" },
                -- DiagnosticSignHint = { fg = "#94e2d5", bg = "#1a1a2e" },
            }
        end,
        auto_integrations = true,
    },
}
