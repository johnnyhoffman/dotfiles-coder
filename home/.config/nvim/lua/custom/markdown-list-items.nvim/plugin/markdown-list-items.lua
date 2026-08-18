-- markdown-list-items.nvim entry point
-- Defines <Plug> mappings and triggers default keymap autocmd.
-- This file is loaded automatically by Neovim's plugin loader.

if vim.g.loaded_markdown_list_items then
  return
end
vim.g.loaded_markdown_list_items = true

-- <Plug> mappings — always available

vim.keymap.set("n", "<Plug>(markdown-list-cycle)", function()
  require("markdown-list-items.transforms").cycle()
end, { desc = "MarkdownList: cycle item type" })

local direct_types = {
  "plain",
  "bullet",
  "unchecked",
  "checked",
  "cancelled",
  "question",
  "in_progress",
  "rescheduled",
  "deferred",
  "important",
  "starred",
  "info",
  "reference",
  "note",
  "numbered",
}
for _, type_id in ipairs(direct_types) do
  vim.keymap.set("n", "<Plug>(markdown-list-" .. type_id .. ")", function()
    require("markdown-list-items.transforms").set_line_type(type_id)
  end, { desc = "MarkdownList: make " .. type_id })
end

vim.keymap.set("n", "<Plug>(markdown-list-secondary-x)", function()
  require("markdown-list-items.transforms").toggle_secondary_mark("x")
end, { desc = "MarkdownList: toggle secondary x" })

-- Default keymaps via FileType autocmd
require("markdown-list-items")._setup_keymaps()
