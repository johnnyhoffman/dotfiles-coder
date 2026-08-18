return {
    "folke/todo-comments.nvim",
    -- stylua: ignore
    keys = {
        -- xt/xT list TODO/FIX/FIXME (what LazyVim put on xT), with xT buffer-scoped
        -- (mirrors xx/xX). The `todo_marks` mode (see ./trouble.lua) folds in open
        -- planning-doc marks as pseudo-TODOs; the "Todo/Fix/Fixme" name is kept.
        { "<leader>xt", "<cmd>Trouble todo_marks toggle<cr>", desc = "Todo/Fix/Fixme (Trouble)" },
        { "<leader>xT", "<cmd>Trouble todo_marks toggle filter.buf=0<cr>", desc = "Todo/Fix/Fixme Buffer (Trouble)" },
        -- ]t/[t jump to the next/prev real todo comment *or* open planning mark.
        { "]t", function() require("scripts.planning-marks").jump_next() end, desc = "Next Todo Comment / Mark" },
        { "[t", function() require("scripts.planning-marks").jump_prev() end, desc = "Previous Todo Comment / Mark" },
    },
    opts = {
        highlight = {
            -- default requires colon
            pattern = [[.*<(KEYWORDS):?\s]],
        },
        search = {
            -- default requires colon; make it optional so Trouble/search
            -- matches the highlight behavior (e.g. "TODO add" and "TODO: add")
            pattern = [[\b(KEYWORDS):?\s]],
        },
    },
    config = function(_, opts)
        require("todo-comments").setup(opts)
        -- Apply the default hidden-files state (see scripts/planning-marks.lua) to
        -- todo-comments' ripgrep args, so the todo half of Trouble views matches the
        -- marks half from the first search — not just after the <M-h> toggle.
        require("scripts.planning-marks").sync_todo_comments()
    end,
}
