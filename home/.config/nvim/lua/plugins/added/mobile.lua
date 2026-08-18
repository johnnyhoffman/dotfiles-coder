-- Mobile (Termux) overrides — active only when vim.g.mobile is set (see
-- lua/config/lazy.lua). The phone build is for MARKDOWN EDITING ONLY: the
-- entire dev stack is disabled, while everything markdown keeps working —
-- obsidian.nvim, obsidian-tasks.nvim, markdown-list-items, markview,
-- conform/nvim-lint (prettier + markdownlint-cli2 come from npm on PATH,
-- no Mason needed), and the BufWritePre metadata reorder (Lua fallback
-- when the tasks CLI is absent).
--
-- Rationale per the tasks repo's mobile planning research: Mason can't
-- install precompiled binaries on Android (marksman is verifiably broken
-- there), ltex needs a JVM, and none of them are load-bearing for markdown.

if not vim.g.mobile then
  return {}
end

return {
  -- Package manager + LSP infrastructure (binaries don't exist on Android)
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  { "neovim/nvim-lspconfig", enabled = false },

  -- Debugging / testing / language tooling (dev-only)
  { "mfussenegger/nvim-dap", enabled = false },
  { "rcarriga/nvim-dap-ui", enabled = false },
  { "nvim-neotest/neotest", enabled = false },
  { "marilari88/neotest-vitest", enabled = false },
  { "dmmulroy/tsc.nvim", enabled = false },
  { "dmmulroy/ts-error-translator.nvim", enabled = false },
  { "vuki656/package-info.nvim", enabled = false },

  -- Network/API-dependent or desktop-workflow plugins. (neogit stays
  -- enabled: pure Lua + the git binary, useful for on-device dotfiles work.)
  { "milanglacier/minuet-ai.nvim", enabled = false },
  { "pwntester/octo.nvim", enabled = false },

  -- Trim treesitter to the note-editing set: parsers are compiled on-device
  -- (pkg install clang), so keep the compile surface small. Replaces (not
  -- extends) the desktop ensure_installed list.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = {
        "bash",
        "lua",
        "markdown",
        "markdown_inline",
        "query",
        "regex",
        "vim",
        "yaml",
      }
    end,
  },
}
