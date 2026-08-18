-- LSP progress tracker — fidget replacement built on the LspProgress autocmd.
--
-- Why this exists: vim.lsp.status() drains a ringbuf per call, so between
-- "report" events the statusline goes blank. We maintain our own table so the
-- display stays steady until a task actually ends.
--
-- Also bridges LSP $/progress → nvim_echo({kind='progress'}) so:
--   • vim.ui.progress_status() reflects LSP work
--   • OSC 9;4 terminal-tab progress bars activate
--   • 'messagesopt+=progress:c' surfaces LSP progress in the cmdline area

local M = {}

local LINGER_MS = 750
local SPINNER_FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local SPINNER_PERIOD_MS = 80

---@class LspProgressTask
---@field client_id integer
---@field client_name string
---@field token string|integer
---@field title? string
---@field message? string
---@field percent? integer
---@field kind "begin" | "report" | "end"
---@field finished_at? integer  -- vim.uv.now() when kind=="end"
---@field echo_id? integer      -- id returned by nvim_echo for updates

---@type table<string, LspProgressTask>
M.tasks = {}

local function key(client_id, token)
    return tostring(client_id) .. ":" .. tostring(token)
end

local function refresh_statusline()
    local ok, lualine = pcall(require, "lualine")
    if ok then
        lualine.refresh({ scope = "window", place = { "statusline" } })
    else
        pcall(vim.cmd.redrawstatus)
    end
end

local function emit_native_progress(task)
    local title = task.title or task.client_name or "LSP"
    local text = task.message and (title .. ": " .. task.message) or title
    local opts = {
        kind = "progress",
        source = "lsp:" .. (task.client_name or "unknown"),
        title = title,
        percent = task.percent or 0,
        status = task.kind == "end" and "success" or "running",
    }
    if task.kind == "end" then
        opts.percent = 100
    end
    if task.echo_id then
        opts.id = task.echo_id
    end
    local ok, id = pcall(vim.api.nvim_echo, { { text } }, false, opts)
    if ok and id then
        task.echo_id = id
    end
end

local spinner_timer
local function ensure_spinner_running()
    if spinner_timer then
        return
    end
    spinner_timer = (vim.uv or vim.loop).new_timer()
    spinner_timer:start(
        SPINNER_PERIOD_MS,
        SPINNER_PERIOD_MS,
        vim.schedule_wrap(function()
            local has_active = false
            for _, t in pairs(M.tasks) do
                if t.kind ~= "end" then
                    has_active = true
                    break
                end
            end
            if has_active then
                refresh_statusline()
            else
                if spinner_timer then
                    spinner_timer:stop()
                    if not spinner_timer:is_closing() then
                        spinner_timer:close()
                    end
                    spinner_timer = nil
                end
            end
        end)
    )
end

local function schedule_clear(k)
    vim.defer_fn(function()
        local t = M.tasks[k]
        if t and t.finished_at and (vim.uv.now() - t.finished_at) >= LINGER_MS then
            M.tasks[k] = nil
            refresh_statusline()
        end
    end, LINGER_MS + 50)
end

local group = vim.api.nvim_create_augroup("johnny.lsp_progress", { clear = true })

vim.api.nvim_create_autocmd("LspProgress", {
    group = group,
    callback = function(ev)
        local data = ev.data or {}
        local params = data.params
        local client_id = data.client_id
        if not params or not params.value or not client_id then
            return
        end
        local v = params.value
        if type(v) ~= "table" or not v.kind then
            return
        end
        local client = vim.lsp.get_client_by_id(client_id)
        if not client then
            return
        end

        local k = key(client_id, params.token)
        local task = M.tasks[k]
            or {
                client_id = client_id,
                client_name = client.name,
                token = params.token,
            }
        task.title = v.title or task.title
        task.message = v.message
        task.percent = v.percentage or task.percent
        task.kind = v.kind
        if v.kind == "end" then
            task.finished_at = vim.uv.now()
            schedule_clear(k)
        end
        M.tasks[k] = task

        emit_native_progress(task)
        ensure_spinner_running()
        refresh_statusline()
    end,
})

-- Clear tasks belonging to a client that has detached, so a stuck "begin"
-- without an "end" doesn't linger forever.
vim.api.nvim_create_autocmd("LspDetach", {
    group = group,
    callback = function(ev)
        local cid = ev.data and ev.data.client_id
        if not cid then
            return
        end
        local prefix = tostring(cid) .. ":"
        local changed = false
        for k, _ in pairs(M.tasks) do
            if k:sub(1, #prefix) == prefix then
                M.tasks[k] = nil
                changed = true
            end
        end
        if changed then
            refresh_statusline()
        end
    end,
})

local function spinner_frame()
    local idx = (math.floor((vim.uv or vim.loop).now() / SPINNER_PERIOD_MS) % #SPINNER_FRAMES) + 1
    return SPINNER_FRAMES[idx]
end

---@param opts? { exclude?: string[], exclude_in_insert?: string[], max_width?: integer }
---@return string
function M.status(opts)
    opts = opts or {}
    local excl = {}
    for _, name in ipairs(opts.exclude_in_insert or {}) do
        excl[name] = true
    end
    local excl_always = {}
    for _, name in ipairs(opts.exclude or {}) do
        excl_always[name] = true
    end
    local in_insert = vim.api.nvim_get_mode().mode:sub(1, 1) == "i"

    local active_labels, completed_labels = {}, {}
    local percent_sum, percent_count = 0, 0
    for _, t in pairs(M.tasks) do
        if not excl_always[t.client_name] and not (in_insert and excl[t.client_name]) then
            local label = t.title or t.client_name or "LSP"
            if t.message then
                label = label .. ": " .. t.message
            end
            if t.kind == "end" then
                table.insert(completed_labels, "✓ " .. (t.title or t.client_name or "LSP"))
            else
                table.insert(active_labels, label)
                if t.percent then
                    percent_sum = percent_sum + t.percent
                    percent_count = percent_count + 1
                end
            end
        end
    end

    local parts = {}
    if #active_labels > 0 then
        local prefix = spinner_frame()
        if percent_count > 0 then
            local avg = math.floor(percent_sum / percent_count)
            prefix = string.format("%s %d%%%%", prefix, avg)
        end
        table.insert(parts, prefix .. " " .. table.concat(active_labels, ", "))
    end
    for _, c in ipairs(completed_labels) do
        table.insert(parts, c)
    end

    local s = table.concat(parts, " · ")
    local max = opts.max_width or 60
    if vim.fn.strdisplaywidth(s) > max then
        s = vim.fn.strcharpart(s, 0, max - 1) .. "…"
    end
    return s
end

return M
