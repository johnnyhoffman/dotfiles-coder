-- Shows dependency version info as virtual text in package.json (only for
-- outdated deps — hide_up_to_date keeps clean files clutter-free) with
-- buffer-local actions to update/delete/install/change-version.
return {
    "vuki656/package-info.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    event = "BufRead package.json",
    opts = {
        hide_up_to_date = true,
    },
    config = function(_, opts)
        require("package-info").setup(opts)

        -- Buffer-local keymaps; lazy.nvim re-fires the BufRead event after
        -- loading, so this also applies to the buffer that triggered the load.
        vim.api.nvim_create_autocmd("BufRead", {
            group = vim.api.nvim_create_augroup("package_info_keymaps", { clear = true }),
            pattern = "package.json",
            callback = function(ev)
                local pi = require("package-info")
                local function map(lhs, rhs, desc)
                    vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc, silent = true })
                end
                map("<leader>cpt", pi.toggle, "Toggle dep versions (package-info)")
                map("<leader>cpu", pi.update, "Update dep on line")
                map("<leader>cpd", pi.delete, "Delete dep on line")
                map("<leader>cpi", pi.install, "Install new dep")
                map("<leader>cpv", pi.change_version, "Change dep version")
            end,
        })
    end,
}
