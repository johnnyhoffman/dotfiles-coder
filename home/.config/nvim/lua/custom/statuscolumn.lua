local M = {}

local git_patterns = { "GitSign", "MiniDiffSign" }

local function is_git_sign(name)
    for _, pattern in ipairs(git_patterns) do
        if name:find(pattern) then
            return true
        end
    end
    return false
end

local sign_cache = {}
local cache = {}

local function get_signs(buf, lnum)
    if not sign_cache[buf] then
        sign_cache[buf] = {}
        local extmarks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true, type = "sign" })
        for _, extmark in pairs(extmarks) do
            local l = extmark[2] + 1
            sign_cache[buf][l] = sign_cache[buf][l] or {}
            local name = extmark[4].sign_hl_group or extmark[4].sign_name or ""
            table.insert(sign_cache[buf][l], {
                name = name,
                text = extmark[4].sign_text,
                texthl = extmark[4].sign_hl_group,
                priority = extmark[4].priority or 0,
                is_git = is_git_sign(name),
            })
        end
    end
    return sign_cache[buf][lnum] or {}
end

local function sign_char(sign)
    local text = vim.fn.strcharpart(sign.text or "", 0, 1)
    if sign.texthl then
        return "%#" .. sign.texthl .. "#" .. text .. "%*"
    end
    return text
end

function M.get()
    local win = vim.g.statusline_winid
    local buf = vim.api.nvim_win_get_buf(win)
    local lnum = vim.v.lnum
    local virtnum = vim.v.virtnum

    local key = ("%d:%d:%d:%d:%d"):format(win, buf, lnum, virtnum ~= 0 and 1 or 0, vim.v.relnum)
    if cache[key] then
        return cache[key]
    end

    local parts = {}

    -- Signs (only on real lines, not wrapped)
    if virtnum == 0 and vim.wo[win].signcolumn ~= "no" then
        local signs = get_signs(buf, lnum)
        local git_sign, other_sign

        -- Pick highest-priority git sign and highest-priority other sign
        for _, s in ipairs(signs) do
            if s.is_git then
                if not git_sign or s.priority > git_sign.priority then
                    git_sign = s
                end
            else
                if not other_sign or s.priority > other_sign.priority then
                    other_sign = s
                end
            end
        end

        if git_sign and other_sign then
            table.insert(parts, sign_char(git_sign) .. sign_char(other_sign))
        elseif git_sign then
            table.insert(parts, sign_char(git_sign))
        elseif other_sign then
            table.insert(parts, sign_char(other_sign))
        else
            table.insert(parts, " ")
        end
    end

    -- Line number
    local nu = vim.wo[win].number
    local rnu = vim.wo[win].relativenumber
    if (nu or rnu) and virtnum == 0 then
        local num
        if rnu and nu and vim.v.relnum == 0 then
            num = lnum
        elseif rnu then
            num = vim.v.relnum
        else
            num = lnum
        end
        table.insert(parts, "%=" .. num .. " ")
    end

    local ret = table.concat(parts, "")
    cache[key] = ret
    return ret
end

-- Cache invalidation, event-driven (replaces a 20 Hz uv timer that busy-looped
-- forever and leaked a live timer across `:source`/reloads). The augroup's
-- clear = true is the reload guard: re-sourcing wipes the prior autocmds so they
-- never duplicate. Rendered output is unchanged — clearing a cache only forces a
-- recompute.
local group = vim.api.nvim_create_augroup("StatusColumnCache", { clear = true })

-- Sign sources changed → drop both caches (the rendered cache embeds sign text).
vim.api.nvim_create_autocmd({ "DiagnosticChanged", "BufWritePost" }, {
    group = group,
    callback = function()
        sign_cache = {}
        cache = {}
    end,
})
vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "GitSignsUpdate",
    callback = function()
        sign_cache = {}
        cache = {}
    end,
})

-- The rendered cache key includes the relative line number, so it goes stale on
-- cursor movement / scrolling (sign data does not — leave sign_cache warm). This
-- also bounds the rendered cache that the old timer used to flush periodically.
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled" }, {
    group = group,
    callback = function()
        cache = {}
    end,
})

return M
