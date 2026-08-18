-- vim-dadbod-ui's default <Leader>S/W/E SQL-buffer maps are disabled via
-- g:db_ui_disable_mappings_sql (see extras/lang/sql.lua) because <leader>S is
-- now the scratch-buffer prefix. Re-bind the same <Plug> actions under
-- <localleader>, buffer-locally — runs after the plugin's ftplugin/sql.vim.

local function map(mode, lhs, plug, desc)
    vim.keymap.set(mode, lhs, plug, {
        buffer = true,
        silent = true,
        nowait = true,
        remap = true, -- rhs is a <Plug> mapping
        desc = desc,
    })
end

map({ "n", "x" }, "<localleader>e", "<Plug>(DBUI_ExecuteQuery)", "[e]xecute query (dadbod)")
map("n", "<localleader>s", "<Plug>(DBUI_SaveQuery)", "[s]ave query (dadbod)")
map("n", "<localleader>b", "<Plug>(DBUI_EditBindParameters)", "Edit [b]ind parameters (dadbod)")
