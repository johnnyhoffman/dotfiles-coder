return {
    "nvim-zh/colorful-winsep.nvim",
    config = true,
    event = { "WinLeave" },
    opts = {

        indicator_for_2wins = {
            position = "center", -- false to disable or choose between "center", "start", "end" and "both"
        },
    },
}
