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
    -- Stock `bD` / `wD` open the finder without `allow_multi`, so the snacks
    -- picker shows Tab-select but neogit only deletes the first pick. These
    -- overrides re-run the same finder with multi enabled and loop.
    config = function(_, opts)
        require("neogit").setup(opts)

        local Finder = require("neogit.buffers.fuzzy_finder")
        local git = require("neogit.lib.git")
        local input = require("neogit.lib.input")
        local notification = require("neogit.lib.notification")
        local event = require("neogit.lib.event")
        local status = require("neogit.buffers.status")

        local branch_actions = require("neogit.popups.branch.actions")
        branch_actions.delete_branch = function()
            local picked = Finder.new(git.refs.list_branches()):open_async({
                prompt_prefix = "Delete branch(es)",
                allow_multi = true,
                refocus_status = false,
            })
            if not picked or #picked == 0 then
                return
            end

            for _, ref in ipairs(picked) do
                local remote, name = git.branch.parse_remote_branch(ref)
                local ok = false
                if remote and remote ~= "." then
                    if input.get_permission(("Delete remote branch '%s/%s'?"):format(remote, name)) then
                        ok = git.cli.push.remote(remote).delete.to(name).call():success()
                    end
                elseif name == git.branch.current() then
                    notification.warn(("Skipping '%s': currently checked out"):format(name))
                elseif name then
                    ok = git.branch.delete(name) -- prompts itself when unmerged
                end
                if ok then
                    notification.info("Deleted branch " .. ref)
                    event.send("BranchDelete", { branch_name = name })
                end
            end
        end

        local worktree_actions = require("neogit.popups.worktree.actions")
        worktree_actions.delete = function()
            local options = vim.tbl_map(function(w)
                return w.path
            end, git.worktree.list({ include_main = false }))
            if #options == 0 then
                notification.info("No worktrees present")
                return
            end

            local picked = Finder.new(options):open_async({
                prompt_prefix = "Delete worktree(s)",
                allow_multi = true,
            })
            if not picked or #picked == 0 then
                return
            end

            local cwd = vim.fs.normalize(assert(vim.uv.cwd(), "cannot determine cwd"))
            local main = git.worktree.main()
            for _, path in ipairs(picked) do
                if input.get_permission(("Remove worktree at %q?"):format(path)) then
                    if vim.fs.normalize(path) == cwd and status.is_open() and main then
                        status.instance():chdir(main.path)
                    end
                    local ok = git.worktree.remove(path)
                    if
                        not ok
                        and input.get_permission(("%s has untracked or modified files. Remove anyway?"):format(path))
                    then
                        ok = git.worktree.remove(path, { "--force" })
                    end
                    if ok then
                        notification.info("Removed worktree " .. path)
                    end
                end
            end
        end
    end,
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
