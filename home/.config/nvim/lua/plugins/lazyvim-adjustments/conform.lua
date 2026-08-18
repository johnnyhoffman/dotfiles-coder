---@module 'conform'

-- Path to the global Prettier config (stowed from dotfiles → ~/.config/prettier/).
-- Prettier never auto-loads a global/XDG config by design, so we inject it via
-- `--config` ONLY when a project has no Prettier config of its own. Projects with
-- their own .prettierrc / prettier.config.* win: we pass no --config and let
-- Prettier discover theirs (the "defer to project, else global" strategy).
local global_prettier_config = vim.fn.expand("~/.config/prettier/config.json")

-- Filetypes Prettier formats. For TS/JS (see ts_js_ft below) Prettier only runs
-- when the project ships its OWN Prettier config; otherwise TS/JS formatting is
-- handled by ESLint Stylistic (~/.config/eslint) — see eslint.lua. For the rest,
-- Prettier formats with the global config as a fallback. Markdown additionally
-- gets a markdownlint-fix pass (registered explicitly below).
local prettier_fts = {
    "typescript",
    "typescriptreact",
    "javascript",
    "javascriptreact",
    "json",
    "jsonc",
    "css",
    "scss",
    "yaml",
    "html",
}

-- TS/JS filetypes where ESLint Stylistic is the formatter of record, so Prettier
-- should only step in when the project explicitly opts into Prettier.
local ts_js_ft = {
    typescript = true,
    typescriptreact = true,
    javascript = true,
    javascriptreact = true,
    ["typescript.tsx"] = true,
    ["javascript.jsx"] = true,
}

-- Per-file check: does this file's project provide its own Prettier config?
-- Shared with eslint.lua so the two stay consistent (see scripts/prettier-config).
local has_project_config = require("scripts.prettier-config").has_project_config

-- Does this file sit under a project/directory that ships its OWN markdownlint
-- config? If so we skip our markdownlint-fix pass (below): markdownlint-cli2
-- auto-discovers a directory `.markdownlint(-cli2)?.*` file and merges it OVER
-- the `--config` we pass, which re-enables rules our fix-only config disables
-- (and can hard-error on a `customRules` path that doesn't resolve from here) —
-- surfacing as "Formatter failed". The Obsidian vault is the common case (it
-- ships `.markdownlint-cli2.jsonc` for the Obsidian plugin). Mirrors the
-- "defer to the project's own config" policy we use for Prettier/ESLint.
local markdownlint_config_files = {
    ".markdownlint-cli2.jsonc",
    ".markdownlint-cli2.yaml",
    ".markdownlint-cli2.cjs",
    ".markdownlint-cli2.mjs",
    ".markdownlint.jsonc",
    ".markdownlint.json",
    ".markdownlint.yaml",
    ".markdownlint.yml",
    ".markdownlint.cjs",
}
local function project_has_markdownlint_config(filename)
    return vim.fs.find(markdownlint_config_files, {
        path = vim.fs.dirname(filename),
        upward = true,
        limit = 1,
    })[1] ~= nil
end

local formatters_by_ft = {
    markdown = { "prettier", "markdownlint-fix" },
    ["markdown.mdx"] = { "prettier", "markdownlint-fix" },
}
for _, ft in ipairs(prettier_fts) do
    formatters_by_ft[ft] = { "prettier" }
end

return {
    {
        "stevearc/conform.nvim",
        optional = true,
        ---@type conform.setupOpts
        opts = {
            formatters_by_ft = formatters_by_ft,
            formatters = {
                prettier = {
                    ---@param ctx conform.Context
                    condition = function(_, ctx)
                        -- For TS/JS, only let Prettier run if the project opts in
                        -- with its own Prettier config; otherwise ESLint Stylistic
                        -- owns formatting. All other filetypes always use Prettier.
                        if ts_js_ft[vim.bo[ctx.buf].filetype] then
                            return has_project_config(ctx.filename)
                        end
                        return true
                    end,
                    ---@param ctx conform.Context
                    prepend_args = function(_, ctx)
                        if has_project_config(ctx.filename) then
                            return {}
                        end
                        return { "--config", global_prettier_config }
                    end,
                },
                ["markdownlint-fix"] = {
                    command = "markdownlint-cli2",
                    args = {
                        "--fix",
                        "--config",
                        vim.fn.stdpath("config") .. "/format.markdownlint-cli2.yaml",
                        "$FILENAME",
                    },
                    stdin = false,
                    ---@param ctx conform.Context
                    condition = function(_, ctx)
                        -- Skip when the project owns its markdownlint config (e.g.
                        -- the Obsidian vault) — see project_has_markdownlint_config.
                        return not project_has_markdownlint_config(ctx.filename)
                    end,
                },
            },
        },
    },
}
