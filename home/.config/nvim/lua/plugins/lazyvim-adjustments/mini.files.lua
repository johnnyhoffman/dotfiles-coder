-- there are some interesting "recipes" here: https://github.com/stevearc/oil.nvim?tab=readme-ov-file#recipes
return {
    "nvim-mini/mini.files",
    -- Load at startup so `use_as_default_explorer` can hijack a directory opened
    -- with `nvim <dir>` (its autocmd must be registered before the first BufEnter).
    -- No priority bump needed: snacks' explorer is disabled (enabled=false), so
    -- nothing else competes to be the default explorer.
    lazy = false,
    version = "*",
    opts = {
        windows = {
            width_focus = 35,
            width_preview = 35,
            width_nofocus = 35,
        },
        options = {
            use_as_default_explorer = true,
        },
    },
    keys = {
        {
            "<leader>fm",
            function()
                local buf_name = vim.api.nvim_buf_get_name(0)
                -- Non-file buffers (e.g. Neogit) have names that aren't real paths; fall back to cwd
                local path = (buf_name ~= "" and vim.uv.fs_stat(buf_name)) and buf_name or vim.uv.cwd()
                require("mini.files").open(path, true)
            end,
            desc = "Navigate files [m]ini (Directory of Current File)",
        },
        {
            "<leader>fM",
            function()
                require("mini.files").open(vim.uv.cwd(), true)
            end,
            desc = "Navigate files [m]ini (cwd)",
        },
    },
}
