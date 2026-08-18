-- Project-wide TypeScript type checking. vtsls only diagnoses open buffers;
-- :TSC runs `tsc --noEmit` across the whole project (resolving the tsconfig
-- and the tsc binary from the project's node_modules, falling back to a
-- global install) and puts errors in the quickfix list via Trouble.
return {
    "dmmulroy/tsc.nvim",
    cmd = { "TSC", "TSCOpen", "TSCClose", "TSCStop" },
    keys = {
        {
            "<leader>ct",
            function()
                -- Clear any previous TSC results so the window doesn't show
                -- stale errors while the new check runs (mirrors the
                -- replace-vs-new logic in tsc.nvim's set_qflist).
                local qf_action = vim.fn.getqflist({ title = 0 }).title == "TSC" and "r" or " "
                vim.fn.setqflist({}, qf_action, { title = "TSC", items = {} })
                vim.cmd("TSC")
                -- Open the results window immediately, even with no items —
                -- tsc.nvim only auto-opens on errors, and its trouble.refresh()
                -- on completion updates this already-open view either way.
                -- "quickfix" (not the "qflist" alias) to match tsc.nvim's own
                -- open call so errors reuse this view instead of a second one.
                require("trouble").open({ mode = "quickfix", open_no_results = true, focus = false })
            end,
            desc = "Type-check project (tsc)",
        },
    },
    opts = {
        use_trouble_qflist = true,
        -- Suppress the spinner toasts (no top-anchored notification stacks).
        -- Progress is visible in the always-opened Trouble window.
        enable_progress_notifications = false,
    },
    config = function(_, opts)
        require("tsc").setup(opts)
        -- The plugin's "no errors" toast is gated behind
        -- enable_progress_notifications (off above, to kill the spinner),
        -- while error summaries have their own flag. Wrap set_qflist — called
        -- exactly once when a check completes — to restore the success
        -- notification without the spinner.
        local utils = require("tsc.utils")
        local set_qflist = utils.set_qflist
        utils.set_qflist = function(errors, ...)
            set_qflist(errors, ...)
            if #errors == 0 then
                vim.notify("Type-checking complete. No errors found", vim.log.levels.INFO, { title = "TSC" })
            end
        end
    end,
}
