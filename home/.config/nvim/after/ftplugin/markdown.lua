-- Markdown-specific buffer options. Keeping this in `after/ftplugin` ensures it wins over built-in ftplugins.

-- my global options set `shiftwidth=4` and `tabstop=4`, but markdown can have filetype plugins / formatters that override indentation
vim.bo.expandtab = true
vim.bo.shiftwidth = 4
vim.bo.tabstop = 4
vim.bo.softtabstop = 4

-- Parse a markdown line into its components: indent, marker, checkbox, text
-- Returns nil if the line is not a bullet.
local function parse_bullet(line)
    -- Bullet with checkbox: "  - [x] text"
    local indent, marker, check_char, text = line:match("^(%s*)([-*+])%s+%[([xX ])%]%s(.*)")
    if indent then
        return { indent = indent, marker = marker, checkbox = check_char, text = text }
    end
    -- Bullet without checkbox: "  - text"
    indent, marker, text = line:match("^(%s*)([-*+])%s+(.*)")
    if indent then
        return { indent = indent, marker = marker, checkbox = nil, text = text }
    end
    return nil
end

-- Build a new bullet prefix from parsed components (always unchecked if checkbox present)
local function bullet_prefix(parsed)
    local prefix = parsed.indent .. parsed.marker .. " "
    if parsed.checkbox then
        prefix = prefix .. "[ ] "
    end
    return prefix
end

-- Bullet auto-continuation for <CR> in insert mode
vim.keymap.set("i", "<CR>", function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    local parsed = parse_bullet(line)

    if not parsed then
        -- Not a bullet line — default Enter
        return vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
    end

    local prefix = bullet_prefix(parsed)

    -- Check if the bullet has no text content (empty bullet) — remove the bullet instead
    if parsed.text == "" and col >= #line then
        vim.api.nvim_buf_set_lines(0, row - 1, row, false, { "" })
        vim.api.nvim_win_set_cursor(0, { row, 0 })
        return
    end

    if col >= #line then
        -- Cursor at end of line — new bullet below
        vim.api.nvim_buf_set_lines(0, row, row, false, { prefix })
        vim.api.nvim_win_set_cursor(0, { row + 1, #prefix })
    else
        -- Cursor mid-line — split: keep text before cursor, move rest to new bullet
        local before = line:sub(1, col)
        local after = line:sub(col + 1)
        -- Trim leading whitespace from the split-off text
        after = after:gsub("^%s+", "")
        vim.api.nvim_buf_set_lines(0, row - 1, row, false, { before, prefix .. after })
        vim.api.nvim_win_set_cursor(0, { row + 1, #prefix })
    end
end, { buffer = true, desc = "Markdown bullet-aware Enter" })

-- Bullet auto-continuation for o (new line below) in normal mode
vim.keymap.set("n", "o", function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    local parsed = parse_bullet(line)

    if not parsed then
        -- Not a bullet line — default o
        return vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("o", true, false, true), "n", false)
    end

    local prefix = bullet_prefix(parsed)
    vim.api.nvim_buf_set_lines(0, row, row, false, { prefix })
    vim.api.nvim_win_set_cursor(0, { row + 1, #prefix })
    vim.cmd("startinsert!")
end, { buffer = true, desc = "Markdown bullet-aware o" })

-- Bullet auto-continuation for O (new line above) in normal mode
vim.keymap.set("n", "O", function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    local parsed = parse_bullet(line)

    if not parsed then
        -- Not a bullet line — default O
        return vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("O", true, false, true), "n", false)
    end

    local prefix = bullet_prefix(parsed)
    vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, { prefix })
    vim.api.nvim_win_set_cursor(0, { row, #prefix })
    vim.cmd("startinsert!")
end, { buffer = true, desc = "Markdown bullet-aware O" })

-- <localleader>f formatting operators (bold/italic/strike/code/highlight/equation/code block)
require("config.markdown-format").attach()

-- toggle conceallevel based on mode
--     insert mode: show raw syntax (conceallevel=0)
--     normal mode: allow concealing (conceallevel=2)
-- Shared group across all markdown buffers, but the autocmds it holds are
-- buffer-local. Use clear = false and clear only THIS buffer's autocmds, so
-- opening a second markdown file doesn't wipe the first buffer's toggles.
local conceal_group = vim.api.nvim_create_augroup("MarkdownConceal", { clear = false })
vim.api.nvim_clear_autocmds({ group = conceal_group, buffer = 0 })

vim.api.nvim_create_autocmd("InsertEnter", {
    group = conceal_group,
    buffer = 0,
    callback = function()
        vim.wo.conceallevel = 0
    end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
    group = conceal_group,
    buffer = 0,
    callback = function()
        if not vim.b.markview_raw then
            vim.wo.conceallevel = 2
        end
    end,
})

-- When hybrid mode is off: visual mode shows raw, and a toggle switches normal mode raw/rendered
if not vim.g.markview_use_hybrid_mode then
    -- These ModeChanged autocmds are global (pattern-matched on the mode string,
    -- not buffer-local) and identical for every markdown buffer, so they live in
    -- their own group with clear = true: each markdown buffer load wipes and
    -- re-adds the single shared pair, keeping exactly one (no per-buffer leak).
    local modechanged_group = vim.api.nvim_create_augroup("MarkdownConcealModes", { clear = true })
    vim.api.nvim_create_autocmd("ModeChanged", {
        group = modechanged_group,
        pattern = "*:[vV\x16]*",
        callback = function()
            if vim.bo.filetype == "markdown" then
                vim.wo.conceallevel = 0
            end
        end,
    })

    vim.api.nvim_create_autocmd("ModeChanged", {
        group = modechanged_group,
        pattern = "[vV\x16]*:*",
        callback = function()
            if vim.bo.filetype == "markdown" and not vim.b.markview_raw then
                vim.wo.conceallevel = 2
            end
        end,
    })

    -- Toggle between fully-rendered and raw markdown display
    Snacks.toggle({
        id = "markview_raw",
        name = "",
        wk_desc = {
            enabled = "Markdown [r]endered -> [r]aw",
            disabled = "Markdown [r]aw -> [r]endered",
        },
        notify = function(state)
            Snacks.notify(
                state and "Markdown rendering **enabled**" or "Markdown rendering **disabled**",
                { title = "Markdown", level = state and vim.log.levels.INFO or vim.log.levels.WARN }
            )
        end,
        get = function()
            return not vim.b.markview_raw
        end,
        set = function(state)
            vim.b.markview_raw = not state
            vim.cmd("Markview toggle")
            vim.wo.conceallevel = state and 2 or 0
        end,
    }):map("<localleader>r", { buffer = 0 })
end
