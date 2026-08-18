-- Side-by-side diff view for git commit ranges.
-- Navigate files: ]] / [[. Pick file: <CR>. Close: q.

local M = {}

---@type { commit_old: string, commit_new: string, files: string[], current: number, tab: number, win_left: number, win_right: number, buf_left: number?, buf_right: number? }?
local state = nil

local function create_buf(content, filepath, name)
    local buf = vim.api.nvim_create_buf(false, true)
    local lines = vim.split(content, "\n", { trimempty = false })
    if #lines > 0 and lines[#lines] == "" then
        table.remove(lines)
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].buflisted = false
    vim.bo[buf].modifiable = false
    local ft = vim.filetype.match({ filename = filepath })
    if ft then
        vim.bo[buf].filetype = ft
    end
    pcall(vim.api.nvim_buf_set_name, buf, name)
    return buf
end

local function wipe_bufs()
    if not state then
        return
    end
    for _, key in ipairs({ "buf_left", "buf_right" }) do
        local buf = state[key]
        if buf and vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
        state[key] = nil
    end
end

function M.close()
    if not state then
        return
    end
    wipe_bufs()
    if state.tab and vim.api.nvim_tabpage_is_valid(state.tab) and #vim.api.nvim_list_tabpages() > 1 then
        -- Close the tracked diff tab explicitly (by its number) rather than a
        -- bare `tabclose`, which would close whatever tab is currently focused.
        vim.cmd(vim.api.nvim_tabpage_get_number(state.tab) .. "tabclose")
    end
    state = nil
end

local function set_keymaps(buf)
    local o = { buffer = buf, nowait = true, silent = true }
    vim.keymap.set("n", "]]", M.next_file, vim.tbl_extend("force", o, { desc = "Next diff file" }))
    vim.keymap.set("n", "[[", M.prev_file, vim.tbl_extend("force", o, { desc = "Prev diff file" }))
    vim.keymap.set("n", "<leader>gd", M.pick_file, vim.tbl_extend("force", o, { desc = "Pick diff file" }))
    vim.keymap.set("n", "q", M.close, vim.tbl_extend("force", o, { desc = "Close diff view" }))
end

local function show_file(index)
    if not state or index < 1 or index > #state.files then
        return
    end
    if not vim.api.nvim_win_is_valid(state.win_left) or not vim.api.nvim_win_is_valid(state.win_right) then
        M.close()
        return
    end

    state.current = index
    local file = state.files[index]
    local short_old = state.commit_old:sub(1, 7)
    local short_new = state.commit_new:sub(1, 7)

    vim.api.nvim_win_call(state.win_left, function()
        vim.cmd("diffoff")
    end)
    vim.api.nvim_win_call(state.win_right, function()
        vim.cmd("diffoff")
    end)

    local content_old = vim.fn.system({ "git", "show", state.commit_old .. ":" .. file })
    if vim.v.shell_error ~= 0 then
        content_old = ""
    end
    local content_new = vim.fn.system({ "git", "show", state.commit_new .. ":" .. file })
    if vim.v.shell_error ~= 0 then
        content_new = ""
    end

    -- Create new buffers before replacing — old ones auto-wipe via bufhidden=wipe
    -- when they're removed from the windows, avoiding an intermediate state where
    -- windows have no buffer and might get closed.
    local new_left = create_buf(content_old, file, ("diff://%s/%s"):format(short_old, file))
    local new_right = create_buf(content_new, file, ("diff://%s/%s"):format(short_new, file))

    vim.api.nvim_win_set_buf(state.win_left, new_left)
    vim.api.nvim_win_set_buf(state.win_right, new_right)
    state.buf_left = new_left
    state.buf_right = new_right
    vim.api.nvim_win_call(state.win_left, function()
        vim.cmd("diffthis")
    end)
    vim.api.nvim_win_call(state.win_right, function()
        vim.cmd("diffthis")
    end)

    set_keymaps(state.buf_left)
    set_keymaps(state.buf_right)
    vim.notify(("[%d/%d] %s  (%s → %s)"):format(index, #state.files, file, short_old, short_new))
end

function M.next_file()
    if state and state.current < #state.files then
        show_file(state.current + 1)
    end
end

function M.prev_file()
    if state and state.current > 1 then
        show_file(state.current - 1)
    end
end

---Open a Snacks picker to browse and jump to a specific file in the diff.
function M.pick_file()
    if not state then
        return
    end
    local short_old = state.commit_old:sub(1, 7)
    local short_new = state.commit_new:sub(1, 7)
    local items = {}
    for i, file in ipairs(state.files) do
        local diff = vim.fn.system({ "git", "diff", state.commit_old, state.commit_new, "--", file })
        items[#items + 1] = {
            text = file,
            file = file,
            diff = vim.v.shell_error == 0 and diff or "",
            idx = i,
        }
    end
    Snacks.picker({
        title = ("Changed files (%s → %s)"):format(short_old, short_new),
        items = items,
        preview = "diff",
        confirm = function(picker, item)
            picker:close()
            if item and item.idx then
                show_file(item.idx)
            end
        end,
    })
end

---Open a side-by-side diff view for all files changed between two commits.
---@param commit_old string Older commit hash (left side)
---@param commit_new string Newer commit hash (right side)
function M.open(commit_old, commit_new)
    M.close()
    local files = vim.fn.systemlist({ "git", "diff", "--name-only", commit_old, commit_new })
    if vim.v.shell_error ~= 0 or #files == 0 then
        vim.notify("No files changed in " .. commit_old:sub(1, 7) .. ".." .. commit_new:sub(1, 7), vim.log.levels.WARN)
        return
    end

    vim.cmd("tabnew")
    vim.cmd("vsplit")
    local win_right = vim.api.nvim_get_current_win()
    vim.cmd("wincmd h")

    state = {
        commit_old = commit_old,
        commit_new = commit_new,
        files = files,
        current = 0,
        tab = vim.api.nvim_get_current_tabpage(),
        win_left = vim.api.nvim_get_current_win(),
        win_right = win_right,
    }
    show_file(1)
end

return M
