-- ESLint LSP — global fallback wiring.
--
-- The LazyVim `linting.eslint` extra (enabled in lazyvim.json) provides the base
-- eslint LSP setup plus the fix-on-save formatter registration (checklist C3).
--
-- Out of the box the eslint language server only attaches when a project has its
-- OWN eslint config, and lints using that config. We extend it so that:
--   * it also attaches to config-less JS/TS projects, and
--   * for those it lints with my global fallback config (~/.config/eslint),
--     resolving eslint + typescript-eslint from that package's node_modules.
--
-- Precedence (for the config-less fallback): project ESLint config wins; else a
-- project PRETTIER config wins (we stay out so conform/Prettier owns formatting,
-- avoiding two formatters fighting); else our global ESLint Stylistic config.
--   * project has eslint config        → attach, defer to it (no override)
--   * project has prettier config only → DON'T attach (Prettier owns it)
--   * project has neither              → attach with global config
--
-- Projects that DO ship their own eslint config are left untouched — we never set
-- overrideConfigFile for them, so the project's config always wins (checklist A3).
--
-- NOTE: the ESLINT config check is done at the resolved project root, so a
-- monorepo with only per-package eslint configs and no root config would get the
-- global fallback; add a root eslint config there if that's not wanted. The
-- PRETTIER check, by contrast, is per-file (shared with conform via
-- scripts/prettier-config) so per-package .prettierrc files are honoured and the
-- two formatters never disagree.

-- Shared per-file Prettier-config detection (also used by conform.lua) so the
-- two never disagree — see scripts/prettier-config for why this matters.
local prettier_config = require("scripts.prettier-config")

local global_eslint_dir = vim.fn.expand("~/.config/eslint")
local global_eslint_config = global_eslint_dir .. "/eslint.config.mjs"

-- Filenames that indicate a project manages its own linting.
local eslint_config_files = {
    ".eslintrc",
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.yaml",
    ".eslintrc.yml",
    ".eslintrc.json",
    "eslint.config.js",
    "eslint.config.mjs",
    "eslint.config.cjs",
    "eslint.config.ts",
    "eslint.config.mts",
    "eslint.config.cts",
}

-- Markers identifying a JS/TS project root, so we attach even without an eslint
-- config present.
local root_markers = {
    "package.json",
    "package-lock.json",
    "yarn.lock",
    "pnpm-lock.yaml",
    "bun.lockb",
    "bun.lock",
    "tsconfig.json",
    "jsconfig.json",
    ".git",
}

local function any_file_exists(root_dir, names)
    for _, name in ipairs(names) do
        if vim.uv.fs_stat(root_dir .. "/" .. name) then
            return true
        end
    end
    return false
end

local function project_has_own_eslint_config(root_dir)
    return any_file_exists(root_dir, eslint_config_files)
end

return {
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                eslint = {
                    -- Attach to any JS/TS project root, not only ones that already
                    -- have an eslint config (the upstream root_dir gates on the
                    -- latter, which would skip our fallback entirely).
                    root_dir = function(bufnr, on_dir)
                        -- Leave Deno projects alone.
                        if vim.fs.root(bufnr, { "deno.json", "deno.jsonc", "deno.lock" }) then
                            return
                        end
                        local root = vim.fs.root(bufnr, root_markers)
                        if not root then
                            return
                        end
                        -- If Prettier resolves a config for THIS file (per-file,
                        -- walking up — the exact check conform uses) and the
                        -- project has no eslint config, let Prettier own
                        -- formatting: don't attach (no conflict). Per-file (not
                        -- root-only) matching keeps us consistent with conform in
                        -- monorepos that only ship per-package Prettier configs.
                        if
                            prettier_config.has_project_config(vim.api.nvim_buf_get_name(bufnr))
                            and not project_has_own_eslint_config(root)
                        then
                            return
                        end
                        on_dir(root)
                    end,
                    before_init = function(_, config)
                        local root_dir = config.root_dir
                        if not root_dir then
                            return
                        end
                        config.settings = config.settings or {}
                        -- Bound the server's config search (VSCode "workspaceFolder").
                        config.settings.workspaceFolder = {
                            uri = root_dir,
                            name = vim.fn.fnamemodify(root_dir, ":t"),
                        }
                        if not project_has_own_eslint_config(root_dir) then
                            -- No project config → lint with my global flat config,
                            -- resolving the eslint engine + plugins from its deps.
                            config.settings.options = config.settings.options or {}
                            config.settings.options.overrideConfigFile = global_eslint_config
                            config.settings.nodePath = global_eslint_dir .. "/node_modules"
                            config.settings.experimental = config.settings.experimental or {}
                            config.settings.experimental.useFlatConfig = true
                        end
                    end,
                },
            },
        },
    },
}
