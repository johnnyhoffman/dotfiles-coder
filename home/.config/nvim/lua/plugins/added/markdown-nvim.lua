-- Inline-formatting engine behind the <localleader>f operators (see lua/config/markdown-format.lua).
-- All builtin keymaps are disabled; the operators call require("markdown.inline") directly.
-- Other features (TOC, links, list editing) stay inert without their keymaps —
-- obsidian.nvim and the custom bullet handling in after/ftplugin/markdown.lua cover those.
return {
    "tadmccorkle/markdown.nvim",
    ft = "markdown",
    opts = {
        mappings = false,
    },
}
