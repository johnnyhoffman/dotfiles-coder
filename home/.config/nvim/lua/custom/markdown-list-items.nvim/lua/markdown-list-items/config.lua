---@class MarkdownListItemType
---@field id string Identifier used in mappings and transforms
---@field label string Display label (descriptions, health check)
---@field is_cycle_option boolean Include in cycle rotation

---@class MarkdownListItemsConfig
---@field filetypes string[] Filetypes to activate on
---@field items MarkdownListItemType[] Ordered list item types
---@field secondary_marks table<string, string[]> Secondary-mark char -> base marker chars it may attach to
---@field mappings table<string, string|false>|false Keymaps; false disables all, individual false disables one

local M = {}

---@type MarkdownListItemsConfig
M.defaults = {
  filetypes = { "markdown" },

  items = {
    { id = "plain", label = "Plain text", is_cycle_option = true },
    { id = "bullet", label = "Bullet (-)", is_cycle_option = true },
    { id = "unchecked", label = "Unchecked ([ ])", is_cycle_option = true },
    { id = "checked", label = "Checked ([x])", is_cycle_option = true },
    { id = "cancelled", label = "Cancelled ([-])", is_cycle_option = true },
    { id = "question", label = "Question ([?])", is_cycle_option = true },
    { id = "in_progress", label = "In progress ([/])", is_cycle_option = false },
    { id = "rescheduled", label = "Rescheduled ([>])", is_cycle_option = false },
    { id = "deferred", label = "Deferred ([<])", is_cycle_option = false },
    { id = "important", label = "Important ([!])", is_cycle_option = false },
    { id = "starred", label = "Starred ([*])", is_cycle_option = false },
    { id = "info", label = "Info ([i])", is_cycle_option = false },
    { id = "reference", label = 'Reference (["])', is_cycle_option = false },
    { id = "note", label = "Note ([:])", is_cycle_option = false },
    { id = "numbered", label = "Numbered (1.)", is_cycle_option = false },
  },

  -- A secondary mark is a second character appended inside an existing marker,
  -- e.g. `[?]` -> `[?x]` ("answered question"). Opt-in per base marker: a key here
  -- maps a secondary char to the base marker chars it may attach to. `<localleader>X`
  -- toggles the `x` secondary mark; only bases listed here are eligible (and only
  -- those with a matching markview render — currently `?x`).
  secondary_marks = {
    x = { "?", ">", "<", "!", "i", "*", ":" },
  },

  -- `<localleader>x` is a prefix for every checkbox/list type (e.g. `<localleader>x?`);
  -- `<localleader>xx` = checked and `<localleader>x<Space>` = unchecked live under it.
  -- `<localleader>L` cycles. `<localleader>X` toggles a marker's done-state: `[ ]`<->`[x]`
  -- for plain checkboxes, or appends/strips `x` on the typed markers in `secondary_marks`.
  mappings = {
    cycle = "<localleader>L",
    plain = "<localleader><BS>",
    bullet = "<localleader>-",
    unchecked = "<localleader>x<Space>",
    checked = "<localleader>xx",
    secondary_x = "<localleader>X",
    cancelled = "<localleader>x-",
    question = "<localleader>x?",
    in_progress = "<localleader>x/",
    rescheduled = "<localleader>x>",
    deferred = "<localleader>x<",
    important = "<localleader>x!",
    starred = "<localleader>x*",
    info = "<localleader>xi",
    reference = '<localleader>x"',
    note = "<localleader>x:",
    numbered = "<localleader>x1",
  },
}

---@type MarkdownListItemsConfig
M.options = {}

---@type boolean
M._did_setup = false

---@param opts? MarkdownListItemsConfig
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
  M._did_setup = true
end

---@return MarkdownListItemsConfig
function M.get()
  if not M._did_setup then
    M.setup()
  end
  return M.options
end

return M
