return {
    "nvim-mini/mini.move",
    keys = {
        { "<M-h>", "<Cmd>lua MiniMove.move_line('left')<CR>", mode = "i", desc = "Move line left" },
        { "<M-l>", "<Cmd>lua MiniMove.move_line('right')<CR>", mode = "i", desc = "Move line right" },
        { "<M-j>", "<Cmd>lua MiniMove.move_line('down')<CR>", mode = "i", desc = "Move line down" },
        { "<M-k>", "<Cmd>lua MiniMove.move_line('up')<CR>", mode = "i", desc = "Move line up" },
    },
}
