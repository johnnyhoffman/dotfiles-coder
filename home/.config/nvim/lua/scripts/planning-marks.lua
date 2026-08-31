-- "Open" planning-doc checkbox marks — the custom glyphs used in planning status
-- docs (`~/.claude/j-threads/**/*.md`, formerly repo-local `.planning/`; see the
-- j-thread skill) — treated as pseudo-TODOs and folded
-- into the existing todo workflow: `]t`/`[t` navigation and the `<leader>xt`/`xT`
-- Trouble list (mode `todo_marks`) surface both these marks and real TODO/FIX/FIXME
-- comments. Marks aren't todo-comments keywords (they're bracket glyphs, not words),
-- so this module supplies the pattern (shared with `lua/trouble/sources/marks.lua`)
-- and a combined jump that todo-comments' word-based engine can't express alone.
--
-- "Needs my attention" = an open mark whose ball is in the reviewer's court and that
-- hasn't been acknowledged yet. Acknowledged variants carry a trailing `x` (`[?x]`,
-- `[ix]`, …) and are excluded for free: the pattern only matches a *single* glyph
-- char between the brackets, so `[x]` (done), `[-]` (dropped) and every `[Gx]` are
-- skipped automatically.

local M = {}

-- Base glyph chars that count as "needs my attention". Edit to taste:
--   (space) unchecked / undecided option    [ ]
--   ?       agent's question to me           [?]
--   <       agent's answer awaiting my ack   [<]
--   i       info note I haven't read yet     [i]
--   !       important note, unread           [!]
--   *       starred / flagged, unread        [*]
-- Left out by default — add the char to the string to include:
--   >  user voice (ball's in the agent's court)   /  partial / in-progress   :  cross-ref pointer
M.glyphs = " ?<i!*"

-- Whether workspace scans descend into hidden dot-dirs like `.planning/` (which
-- ripgrep skips by default, since the dir name starts with a `.`). Defaults on so
-- planning docs show without ceremony; toggle at runtime with `<M-h>` in any
-- Trouble window (see lua/plugins/lazyvim-adjustments/trouble.lua). The marks scan
-- reads this flag directly; the todo half is kept in sync via `sync_todo_comments`.
M.include_hidden = true

-- One list-item checkbox with exactly one glyph char inside the brackets. All of
-- ` ?<i!*` are literal inside a `[…]` class in both Vim regex and ripgrep's Rust
-- regex, so the same char class works for both patterns.
local function char_class()
    return "[" .. M.glyphs .. "]"
end

-- Vim regex (for `:h search()` / `vim.regex`). `-` leads the bullet class so it's
-- read as a literal rather than a range.
function M.vim_pattern()
    return "^\\s*[-*+]\\s\\+\\[" .. char_class() .. "\\]"
end

-- Ripgrep / Rust regex (for the workspace scan in the Trouble source).
function M.rg_pattern()
    return "^\\s*[-*+]\\s+\\[" .. char_class() .. "\\]"
end

-- Combined jump: open planning marks are treated as pseudo-TODOs, so `]t`/`[t`
-- surface both a line's todo-comment keyword *and* our mark glyphs. Mirrors
-- todo-comments' own jump.lua (a buffer line scan) and adds the mark check, so the
-- two feel like one list — marks live in markdown docs, todo comments in code, and
-- they rarely share a buffer anyway.
---@param up boolean
local function combined_jump(up)
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()
    local cur = vim.api.nvim_win_get_cursor(win)[1]
    local last = vim.api.nvim_buf_line_count(buf)
    local from = up and cur - 1 or cur + 1
    local to = up and 1 or last
    local step = up and -1 or 1

    local re = vim.regex(M.vim_pattern())
    local ok_hl, hl = pcall(require, "todo-comments.highlight")
    local tc_cfg = package.loaded["todo-comments.config"]

    for l = from, to, step do
        if l >= 1 and l <= last then
            local line = vim.api.nvim_buf_get_lines(buf, l - 1, l, false)[1] or ""
            local col ---@type integer?
            local s = re:match_str(line)
            if s then
                col = s -- open planning mark
            elseif ok_hl then
                local ok, start, _, kw = pcall(hl.match, line)
                if ok and start and kw then
                    -- respect todo-comments' comments_only setting for real todos
                    if tc_cfg and tc_cfg.options.highlight.comments_only and hl.is_comment(buf, l - 1, start) == false then
                        kw = nil
                    end
                    if kw then
                        col = start - 1
                    end
                end
            end
            if col then
                vim.api.nvim_win_set_cursor(win, { l, col })
                return
            end
        end
    end
    vim.notify("No more todos / open marks to jump to", vim.log.levels.INFO)
end

function M.jump_next()
    combined_jump(false)
end

function M.jump_prev()
    combined_jump(true)
end

-- Point todo-comments' ripgrep args at the current `include_hidden` flag, so the
-- `todo` half of Trouble views (and TodoTelescope) reveal/hide dot-dirs in lockstep
-- with the marks half. Idempotent: strips any existing `--hidden` before re-adding.
function M.sync_todo_comments()
    local ok, cfg = pcall(require, "todo-comments.config")
    if not ok or not cfg.options or not cfg.options.search then
        return
    end
    local args = vim.tbl_filter(function(a)
        return a ~= "--hidden"
    end, cfg.options.search.args or {})
    if M.include_hidden then
        table.insert(args, "--hidden")
    end
    cfg.options.search.args = args
end

-- Flip whether hidden dot-dirs are scanned, and re-sync the todo half. The caller
-- (the <M-h> Trouble action) refreshes the view afterwards.
function M.toggle_hidden()
    M.include_hidden = not M.include_hidden
    M.sync_todo_comments()
    vim.notify("Trouble: hidden files " .. (M.include_hidden and "**shown**" or "**hidden**"), vim.log.levels.INFO)
end

return M
