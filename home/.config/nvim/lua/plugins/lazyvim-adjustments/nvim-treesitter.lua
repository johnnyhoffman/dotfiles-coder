return {
    "nvim-treesitter/nvim-treesitter",
    opts = {
        ensure_installed = {
            "bash",
            "html",
            "javascript",
            "json",
            "lua",
            "markdown",
            "markdown_inline",
            "mermaid", -- highlights ```mermaid fences via the generic fence injection
            "python",
            "query",
            "regex",
            "tsx",
            "typescript",
            "vim",
            "yaml",
            "c",
            "c_sharp",
        },
    },
}
