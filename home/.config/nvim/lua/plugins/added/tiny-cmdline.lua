-- Centered floating command line built on Neovim 0.12's native ui2.
--
-- Replaces noice's `command_palette` preset. We dropped noice because its
-- ext_cmdline confirm dialogs broke on nvim >= 0.11.3 (upstream PR 31525):
-- the confirm message body stopped being delivered to external UIs, leaving
-- blank y/n/c prompts. tiny-cmdline only repositions the *native* ui2 cmdline
-- window, so messages and prompts stay native and the "Save changes to ...?"
-- dialog keeps working.
--
-- Behavior:
--   - `:` commands    -> centered floating window
--   - `/` `?` search  -> stay at the bottom (native; matches the old noice
--                        `bottom_search` preset, via native_types below)
--   - confirm dialogs -> the [Y]es/[N]o/[C]ancel prompt floats centered (so a
--                        waiting prompt is noticeable), while its "Save
--                        changes...?" question renders in ui2's bottom message
--                        area. ui2 emits the question (msg_show kind="confirm")
--                        and the buttons (a cmdline prompt) as two separate
--                        events in two windows, and the question fires before
--                        the centered prompt window exists, so they can't be
--                        co-located. The centered buttons are the signal that a
--                        prompt is waiting; glance to the bottom for the text.
--   - idle            -> no command-line row (cmdheight = 0)
--
-- ui2 must be enabled explicitly, and ui2.enable() is a no-op until a UI is
-- attached (it early-returns on an empty nvim_list_uis()), so we enable it once
-- a UI exists: immediately if one is already attached, otherwise on UIEnter.
--
-- Requires Neovim >= 0.12. `vim._core.ui2` is an experimental, underscored API
-- and may change across nvim versions.
return {
    {
        "rachartier/tiny-cmdline.nvim",
        lazy = false,
        init = function()
            vim.o.cmdheight = 0
        end,
        config = function()
            local function enable_ui2()
                require("vim._core.ui2").enable({})
            end
            if #vim.api.nvim_list_uis() > 0 then
                enable_ui2()
            else
                vim.api.nvim_create_autocmd("UIEnter", { once = true, callback = enable_ui2 })
            end

            require("tiny-cmdline").setup({
                native_types = { "/", "?" },
            })
        end,
    },
}
