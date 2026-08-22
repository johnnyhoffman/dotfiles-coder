return {
    "folke/which-key.nvim",
    opts = {
        delay = 0,
        icons = {
            -- symbol used between a key and it's label
            separator = "- ",
            -- despite putting icons below they kinda just add clutter, so this removes them
            mappings = false,
        },
        win = {
            -- don't allow the popup to overlap with the cursor
            no_overlap = true,
            row = math.huge,
            padding = { 0, 3 },
            title = true,
            title_pos = "center",
        },
        spec = {
            {
                mode = { "n", "x" },
                -- valid colors are: `azure`, `blue`, `cyan`, `green`, `grey`, `orange`, `purple`, `red`, `yellow`, but I'm mostly opting for emojis so color is not applicable
                -- { "<leader>a", group = "+ai", icon = { icon = "󰧑", color = "red" } },
                { "<leader>a", group = "ai", icon = { icon = "🧠" } },
                { "<leader>e", group = "etc.", icon = { icon = "", color = "red" } },
                { "<leader>se", group = "etc.", icon = { icon = "", color = "red" } },
                { "<leader>et", group = "toggle" },
                { "<leader>.", group = "config" },
                { "<leader>.h", group = "health" },
                { "<leader>f", group = "file" },
                { "<leader>S", group = "scratch" },

                { "ga", group = "c[a]lls in/out", icon = { icon = "↔️", color = "purple" } },
                { "gC", group = "comments" },
                -- these are just so I don't have to let go of shift - they don't need to visibly be repeated
                { "gCJ", hidden = true },
                { "gCK", hidden = true },
                -- snacks gr overrides the base vim gr so these sub-maps aren't accessible anymore (I think, but maybe they are accessible in certain contexts?), but even if they aren't accessible, gr "References" still shows up as a "group" if the sub-maps aren't also hidden
                { "grn", hidden = true },
                { "grr", hidden = true },
                { "gra", hidden = true },
                { "gri", hidden = true },
                { "grt", hidden = true },
                -- TODO how do I get it to show my "around" options after doing something like this
                -- `[ - Move to left "around"`
                -- `] - Move to right "around"`
            },
        },
    },
}
