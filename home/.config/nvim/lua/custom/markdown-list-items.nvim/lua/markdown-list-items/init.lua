--- markdown-list-items.nvim
--- Neovim plugin for cycling and picking markdown list item types.
---
--- Setup is optional — the plugin works with defaults out of the box.
--- Call setup() only to customize behavior:
---
---   require("markdown-list-items").setup({
---     mappings = {
---       cycle = "<localleader>l",
---       bullet = false,  -- disable one mapping
---     },
---   })
---
---   -- Or disable all default keymaps and use <Plug> mappings:
---   require("markdown-list-items").setup({ mappings = false })

local config = require("markdown-list-items.config")

local M = {}

--- Map of keymap action names to their <Plug> mapping names.
---@type table<string, string>
local PLUG_MAPPINGS = {
  cycle = "<Plug>(markdown-list-cycle)",
  plain = "<Plug>(markdown-list-plain)",
  bullet = "<Plug>(markdown-list-bullet)",
  unchecked = "<Plug>(markdown-list-unchecked)",
  checked = "<Plug>(markdown-list-checked)",
  cancelled = "<Plug>(markdown-list-cancelled)",
  question = "<Plug>(markdown-list-question)",
  in_progress = "<Plug>(markdown-list-in_progress)",
  rescheduled = "<Plug>(markdown-list-rescheduled)",
  deferred = "<Plug>(markdown-list-deferred)",
  important = "<Plug>(markdown-list-important)",
  starred = "<Plug>(markdown-list-starred)",
  info = "<Plug>(markdown-list-info)",
  reference = "<Plug>(markdown-list-reference)",
  note = "<Plug>(markdown-list-note)",
  numbered = "<Plug>(markdown-list-numbered)",
  secondary_x = "<Plug>(markdown-list-secondary-x)",
}

--- Map of keymap action names to their descriptions.
---@type table<string, string>
local DESCRIPTIONS = {
  cycle = "List: cycle item type",
  plain = "List: make plain text",
  bullet = "List: make bullet",
  unchecked = "unchecked | planning docs: undecided option / open to-do",
  checked = "checked | planning docs: accept / agree to choice",
  cancelled = "cancelled | planning docs: ruled out / dropped",
  question = "question | planning docs: agent's question for the user",
  in_progress = "in-progress | planning docs: partial (partially resolved/accepted)",
  rescheduled = "rescheduled | planning docs: user's reply/concern/comment",
  deferred = "deferred | planning docs: agent's answer/response",
  important = "important",
  starred = "starred",
  info = "info | planning docs: context note, no response needed",
  reference = "reference",
  note = "note | planning docs: cross-reference pointer (discussed elsewhere)",
  numbered = "numbered item",
  secondary_x = "List: toggle done ([ ]↔[x], or append x to typed markers)",
}

--- Keys currently applied per buffer, for cleanup on re-application.
---@type table<integer, string[]>
local applied_buf_keys = {}

--- Apply keymaps for a single buffer, removing any previously applied keymaps first.
---@param buf integer
---@param cfg MarkdownListItemsConfig
local function apply_buf_keymaps(buf, cfg)
  -- Remove previously applied keymaps (handles re-setup with different mappings)
  for _, key in ipairs(applied_buf_keys[buf] or {}) do
    pcall(vim.keymap.del, "n", key, { buffer = buf })
  end

  local keys = {}
  for action, default_key in pairs(config.defaults.mappings) do
    local key = cfg.mappings[action]
    -- nil means "use default", false means "disabled"
    if key == nil then
      key = default_key
    end
    if key and key ~= false then
      vim.keymap.set("n", key, PLUG_MAPPINGS[action], {
        buffer = buf,
        desc = DESCRIPTIONS[action],
      })
      keys[#keys + 1] = key
    end
  end
  applied_buf_keys[buf] = keys
end

--- Create (or recreate) the FileType autocmd that sets buffer-local keymaps.
--- Also retroactively applies keymaps to already-loaded matching buffers.
function M._setup_keymaps()
  local cfg = config.get()

  if cfg.mappings == false then
    -- Clear any previously created autocmd and remove buffer-local keymaps
    vim.api.nvim_create_augroup("MarkdownListItems", { clear = true })
    for buf, keys in pairs(applied_buf_keys) do
      for _, key in ipairs(keys) do
        pcall(vim.keymap.del, "n", key, { buffer = buf })
      end
    end
    applied_buf_keys = {}
    return
  end

  local ft_set = {}
  for _, ft in ipairs(cfg.filetypes) do
    ft_set[ft] = true
  end

  local group = vim.api.nvim_create_augroup("MarkdownListItems", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = cfg.filetypes,
    callback = function(ev)
      apply_buf_keymaps(ev.buf, cfg)
    end,
  })

  -- Retroactively apply to already-open matching buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local ft = vim.bo[buf].filetype
      if ft_set[ft] then
        apply_buf_keymaps(buf, cfg)
      end
    end
  end
end

--- Configure the plugin. Call this in your config to customize behavior.
---@param opts? MarkdownListItemsConfig
function M.setup(opts)
  config.setup(opts)
  M._setup_keymaps()
end

-- Public API

function M.cycle()
  require("markdown-list-items.transforms").cycle()
end

---@param target_type string
function M.set_type(target_type)
  require("markdown-list-items.transforms").set_line_type(target_type)
end

---@param mark? string
function M.toggle_secondary_mark(mark)
  require("markdown-list-items.transforms").toggle_secondary_mark(mark)
end

return M
