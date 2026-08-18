-- Shared "does this file's project provide its own Prettier config?" check.
--
-- Both conform.lua (should Prettier format TS/JS?) and eslint.lua (should the
-- ESLint LSP stay out so Prettier owns formatting?) need the SAME answer, or a
-- monorepo with a per-package .prettierrc and no root config makes them disagree
-- (Prettier formats while ESLint Stylistic also attaches → two formatters fight).
--
-- `prettier --find-config-path <file>` resolves the config the way Prettier
-- itself does: it walks UP from the file (Prettier has no global/XDG config) and
-- also recognises a `prettier` key in package.json, exiting non-zero when nothing
-- is found. Using it per-file — rather than probing a hardcoded filename list at
-- the project root — is what keeps the two callers consistent.
--
-- Memoized per filename so the two callers share one lookup and never re-spawn
-- Prettier for the same file.

local M = {}

local cache = {}

---@param filename string Absolute path of the file being formatted/linted.
---@return boolean # true if a project Prettier config resolves for this file.
function M.has_project_config(filename)
    if cache[filename] == nil then
        vim.fn.system({ "prettier", "--find-config-path", filename })
        cache[filename] = vim.v.shell_error == 0
    end
    return cache[filename]
end

return M
