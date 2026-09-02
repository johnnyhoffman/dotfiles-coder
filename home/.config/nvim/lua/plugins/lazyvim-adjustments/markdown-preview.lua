-- No browser previews: LazyVim's markdown extra ships iamcco/markdown-preview.nvim
-- on <leader>cp, which opens the document in a browser tab. Everything markdown
-- renders in the terminal instead (markview, snacks.image, config/mermaid.lua).
return {
    { "iamcco/markdown-preview.nvim", enabled = false },
}
