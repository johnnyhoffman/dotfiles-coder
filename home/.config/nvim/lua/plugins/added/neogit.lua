return {
    "NeogitOrg/neogit",
    lazy = true,
    dependencies = {
        "nvim-lua/plenary.nvim",
        -- "sindrets/diffview.nvim",
        -- Only one of these is needed.
        "folke/snacks.nvim",
    },
    cmd = "Neogit",
    keys = {
        { "<leader>gg", "<cmd>Neogit<cr>", desc = "Neogit" },
        {
            "<leader>gl",
            function()
                require("neogit").action(
                    "log",
                    "log_all_references",
                    { "--graph", "--decorate", "--topo-order", "--simplify-by-decoration" }
                )()
            end,
            desc = "log (all references)",
        },
        { "<leader>gL", "<cmd>Neogit log<cr>", desc = "log (menu)" },
    },
    opts = {
        mappings = {
            status = {
                ["l"] = "OpenFold",
                ["h"] = "CloseFold",
            },
            popup = {
                ["l"] = false, -- disable default (using l for OpenFold)
                ["L"] = "LogPopup",
                ["d"] = false, -- disable DiffPopup (using d for git-range-diff)
            },
        },
        -- "ascii"   is the graph the git CLI generates
        -- "unicode" is the graph like https://github.com/rbong/vim-flog
        -- "kitty"   is the graph like https://github.com/isakbm/gitgraph.nvim - use https://github.com/rbong/flog-symbols if you don't use Kitty
        graph_style = "unicode",
        kind = "replace",
        -- commit_editor = {
        --     kind = "floating_console",
        --     show_staged_diff = true,
        --     -- Accepted values:
        --     -- "split" to show the staged diff below the commit editor
        --     -- "vsplit" to show it to the right
        --     -- "split_above" Like :top split
        --     -- "vsplit_left" like :vsplit, but open to the left
        --     -- "auto" "vsplit" if window would have 80 cols, otherwise "split"
        --     staged_diff_split_kind = "split",
        --     spell_check = true,
        -- },
        -- floating = {
        --     relative = "editor",
        --     width = 0.9,
        --     height = 0.8,
        --     style = "minimal",
        --     border = "rounded",
        -- },
        -- commit_select_view = {
        --     kind = "floating",
        -- },
        -- commit_view = {
        --     kind = "floating",
        --     verify_commit = vim.fn.executable("gpg") == 1, -- Can be set to true or false, otherwise we try to find the binary
        -- },
        -- log_view = {
        --     kind = "floating",
        -- },
        -- rebase_editor = {
        --     kind = "floating",
        -- },
        -- reflog_view = {
        --     kind = "floating",
        -- },
        -- merge_editor = {
        --     kind = "floating",
        -- },
        -- preview_buffer = {
        --     kind = "floating_console",
        -- },
        -- popup = {
        --     kind = "floating",
        -- },
        -- stash = {
        --     kind = "floating",
        -- },
        -- refs_view = {
        --     kind = "floating",
        -- },
    },
}
