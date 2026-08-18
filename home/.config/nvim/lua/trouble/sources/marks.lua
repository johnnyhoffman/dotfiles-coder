-- Custom Trouble source: "open" planning-doc checkbox marks. Auto-discovered by
-- Trouble via the runtimepath scan in `trouble.sources.load()` (same mechanism
-- todo-comments uses to ship its `todo` source). Pattern + glyph set live in
-- `scripts.planning-marks` so navigation and this list stay in sync.
--
-- One mode, `marks`:
--   <cmd>Trouble marks<cr>                  workspace scan (ripgrep over *.md under cwd)
--   <cmd>Trouble marks filter.buf=0<cr>     current buffer only (in-memory scan — works
--                                           even for docs opened outside cwd)

---@diagnostic disable: inject-field
local Item = require("trouble.item")
local PM = require("scripts.planning-marks")

---@type trouble.Source
local M = {}

---@diagnostic disable-next-line: missing-fields
M.config = {
    modes = {
        marks = {
            desc = "Open planning-doc marks",
            events = { "BufEnter", "BufWritePost" },
            source = "marks",
            groups = {
                { "filename", format = "{file_icon} {filename} {count}" },
            },
            sort = { { buf = 0 }, "filename", "pos" },
            format = "{text} {pos}",
        },
    },
}

-- Scan a single buffer in memory. Robust regardless of cwd, so the `filter.buf=0`
-- view works for planning docs opened from anywhere.
local function scan_buffer(buf)
    local items = {}
    if not vim.api.nvim_buf_is_valid(buf) then
        return items
    end
    local re = vim.regex(PM.vim_pattern())
    local name = vim.api.nvim_buf_get_name(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for i, line in ipairs(lines) do
        local s = re:match_str(line)
        if s then
            items[#items + 1] = Item.new({
                buf = buf,
                pos = { i, s },
                end_pos = { i, s },
                text = line,
                filename = name,
                source = "marks",
            })
        end
    end
    return items
end

-- Scan the workspace with ripgrep, restricted to markdown.
local function scan_workspace(cb)
    if vim.fn.executable("rg") == 0 then
        vim.notify("planning-marks: ripgrep (rg) not found", vim.log.levels.WARN)
        return cb({})
    end
    local cmd = { "rg", "--vimgrep", "--no-heading", "--color=never" }
    if PM.include_hidden then
        table.insert(cmd, "--hidden") -- descend into `.planning/` and other dot-dirs
    end
    vim.list_extend(cmd, { "-g", "*.md", "-g", "*.markdown", PM.rg_pattern() })
    vim.system(cmd, { text = true }, function(res)
        local stdout, code = res.stdout or "", res.code
        vim.schedule(function()
            local items = {}
            -- rg exits 1 on "no matches" — not an error for us.
            if code == 0 or code == 1 then
                for line in vim.gsplit(stdout, "\n", { plain = true }) do
                    local file, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
                    if file then
                        local row = tonumber(lnum)
                        local c = tonumber(col) - 1
                        items[#items + 1] = Item.new({
                            buf = vim.fn.bufadd(vim.fn.fnamemodify(file, ":p")),
                            pos = { row, c },
                            end_pos = { row, c },
                            text = text,
                            filename = vim.fn.fnamemodify(file, ":p"),
                            source = "marks",
                        })
                    end
                end
            end
            cb(items)
        end)
    end)
end

---@param cb trouble.Source.Callback
---@param ctx trouble.Source.ctx
function M.get(cb, ctx)
    local buf = type(ctx.opts.filter) == "table" and ctx.opts.filter.buf or nil
    if buf == 0 then
        buf = ctx.main.buf
    end
    if buf then
        cb(scan_buffer(buf))
    else
        scan_workspace(cb)
    end
end

return M
