return {
    "folke/trouble.nvim",
    opts = {
        focus = true, -- focus the trouble window when opened
        -- Window-local keymap, merged into every Trouble view: toggle whether scans
        -- descend into hidden dot-dirs (like `.planning/`) and refresh. Only the
        -- filesystem-backed sources (todo, marks) change; it's a harmless no-op for
        -- diagnostics/symbols/etc.
        keys = {
            ["<M-h>"] = {
                action = function(view)
                    require("scripts.planning-marks").toggle_hidden()
                    view:refresh()
                end,
                desc = "Toggle hidden files (.planning etc.)",
            },
        },
        modes = {
            -- Combined list behind <leader>xt / xT: real TODO/FIX/FIXME comments plus
            -- open planning-doc marks (custom `marks` source, lua/trouble/sources/marks.lua).
            -- Two sections so each keeps its own grouping; buf=0 from xT flows into both.
            todo_marks = {
                desc = "Todo/Fix/Fixme + planning marks",
                sections = {
                    { mode = "todo", filter = { tag = { "TODO", "FIX", "FIXME" } } },
                    { mode = "marks" },
                },
            },
        },
    },
}
