--- Line parsing and transformation for markdown list item types.

local config = require("markdown-list-items.config")

local M = {}

--- Checkbox character for each checkbox-style type. The order here is also the
--- single source of truth for which `[x]` characters parse_line recognizes.
---@type table<string, string>
local CHECKBOX_CHAR = {
  unchecked = " ",
  checked = "x",
  cancelled = "-",
  question = "?",
  in_progress = "/",
  rescheduled = ">",
  deferred = "<",
  important = "!",
  starred = "*",
  info = "i",
  reference = '"',
  note = ":",
}

--- Reverse map: checkbox character -> type. `X` is folded onto `x` (checked).
---@type table<string, string>
local CHAR_TO_TYPE = { X = "checked" }
for type, char in pairs(CHECKBOX_CHAR) do
  CHAR_TO_TYPE[char] = type
end

-- Lua pattern character class matching any recognized checkbox character, built
-- programmatically from CHECKBOX_CHAR (plus `X`, folded onto `x`) so there is a
-- single source of truth. Every non-alphanumeric char is `%`-escaped so magic
-- ones (`-`, `?`, `*`, …) stay literal inside the enclosing `[...]` set; order
-- within the class is irrelevant once escaped.
local CHECKBOX_CLASS = (function()
  local function escape(c)
    return c:match("%w") and c or ("%" .. c)
  end
  local seen, parts = {}, {}
  local function add(c)
    if not seen[c] then
      seen[c] = true
      parts[#parts + 1] = escape(c)
    end
  end
  add("X") -- uppercase checked, folded onto `x` by CHAR_TO_TYPE
  for _, char in pairs(CHECKBOX_CHAR) do
    add(char)
  end
  return table.concat(parts)
end)()

---@class ParsedLine
---@field indent string Leading whitespace
---@field text string Content without list marker
---@field type string Type id (see config items), e.g. "checked", "in_progress", "numbered"
---@field checkbox_prefix? string For numbered checkboxes, the ordinal marker (e.g. "1. ") so build_line can preserve it

--- Parse a markdown line into its components.
---@param line string
---@return ParsedLine
function M.parse_line(line)
  local indent, check, rest

  -- Checkbox: "  - [x] text", "  - [ ]", "  - [/] text", etc.
  indent, check, rest = line:match("^(%s*)[-*+]%s+%[([" .. CHECKBOX_CLASS .. "])%](.*)")
  if indent then
    -- Fall back to `rest` (not "") so "- [x]text" — no space after `]` — keeps its text.
    local text = rest:match("^%s(.*)") or rest
    return {
      indent = indent,
      text = text,
      type = CHAR_TO_TYPE[check] or "unchecked",
    }
  end

  -- Numbered checkbox: "  1. [x] text", "  2) [ ] item". Detected before plain
  -- numbered so it parses as a checkbox type (agreeing with toggle_secondary_mark)
  -- instead of leaving the "[ ]" embedded in the text.
  local ordinal
  indent, ordinal, check, rest = line:match("^(%s*)(%d+[.)]%s+)%[([" .. CHECKBOX_CLASS .. "])%](.*)")
  if indent then
    local text = rest:match("^%s(.*)") or rest
    return {
      indent = indent,
      text = text,
      type = CHAR_TO_TYPE[check] or "unchecked",
      checkbox_prefix = ordinal,
    }
  end

  -- Numbered: "  1. text" or "  1."
  indent, rest = line:match("^(%s*)%d+%.(.*)")
  if indent then
    -- Fall back to `rest` (not "") so "1.text" — no space after `.` — keeps its
    -- text, matching the checkbox branches above.
    local text = rest:match("^%s(.*)") or rest
    return { indent = indent, text = text, type = "numbered" }
  end

  -- Bullet: "  - text" or "  -"
  indent, rest = line:match("^(%s*)[-*+]%s(.*)")
  if indent then
    return { indent = indent, text = rest, type = "bullet" }
  end
  indent = line:match("^(%s*)[-*+]$")
  if indent then
    return { indent = indent, text = "", type = "bullet" }
  end

  -- Plain text
  indent = line:match("^(%s*)") or ""
  return { indent = indent, text = line:sub(#indent + 1), type = "plain" }
end

--- Determine the number to use for a numbered list item at the given row.
---@param row integer 1-based line number
---@return integer
local function get_number_for_row(row)
  if row <= 1 then
    return 1
  end
  local prev = vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
  if prev then
    local num = prev:match("^%s*(%d+)%.")
    if num then
      return tonumber(num) + 1
    end
  end
  return 1
end

--- Build a new line with the target type applied.
---@param parsed ParsedLine
---@param target_type string
---@param row integer 1-based line number (used for numbered list context)
---@return string
function M.build_line(parsed, target_type, row)
  local indent = parsed.indent
  local text = parsed.text

  if target_type == "plain" then
    return indent .. text
  elseif target_type == "bullet" then
    return indent .. "- " .. text
  elseif target_type == "numbered" then
    local num = get_number_for_row(row)
    return indent .. num .. ". " .. text
  elseif CHECKBOX_CHAR[target_type] then
    -- Preserve a numbered checkbox's ordinal marker ("1. ") when present, else bullet.
    local marker = parsed.checkbox_prefix or "- "
    return indent .. marker .. "[" .. CHECKBOX_CHAR[target_type] .. "] " .. text
  end
  return indent .. text
end

--- Transform the line at the given row to the target type.
---@param target_type string
---@param row? integer 1-based line number (defaults to cursor row)
function M.set_line_type(target_type, row)
  row = row or vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  if not line then
    return
  end

  local parsed = M.parse_line(line)
  if parsed.type == target_type then
    return
  end

  local new_line = M.build_line(parsed, target_type, row)
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
end

--- Toggle a trailing secondary mark on an existing checkbox, e.g. `- [?]` <-> `- [?x]`.
--- For the `x` mark this also toggles the plain checkbox itself: `- [ ]` <-> `- [x]`
--- (the `x` doubles as the checked glyph, so it replaces the box rather than appending).
--- Opt-in for typed markers: only bases configured under `secondary_marks[mark]` are
--- eligible, so the mark is only ever appended to types you've decided make sense (and
--- styled). It is a no-op on non-eligible markers, plain bullets, and non-list lines.
--- Toggling is reversible: adding the mark when absent, stripping it when already present.
---@param mark? string Secondary character to toggle (default "x")
---@param row? integer 1-based line number (defaults to cursor row)
function M.toggle_secondary_mark(mark, row)
  mark = mark or "x"
  row = row or vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  if not line then
    return
  end

  -- Base marker chars this secondary mark may attach to (opt-in via config).
  local allowed = {}
  for _, base in ipairs((config.get().secondary_marks or {})[mark] or {}) do
    allowed[base] = true
  end

  -- Capture the checkbox marker content: `<pre>[<content>]<post>`
  local pre, content, post = line:match("^(%s*[-*+]%s+%[)([^%]]*)(%].*)$")
  if not pre then
    pre, content, post = line:match("^(%s*%d+[.)]%s+%[)([^%]]*)(%].*)$")
  end
  if not pre then
    return
  end

  local new_content
  if mark == "x" and content == " " then
    -- Unchecked -> checked
    new_content = "x"
  elseif mark == "x" and (content == "x" or content == "X") then
    -- Checked -> unchecked
    new_content = " "
  elseif #content >= 2 and content:sub(-#mark) == mark and allowed[content:sub(1, #content - #mark)] then
    -- Already marked on an eligible base: strip the secondary mark
    new_content = content:sub(1, #content - #mark)
  elseif #content == 1 and allowed[content] then
    -- Eligible base marker: append the secondary mark
    new_content = content .. mark
  else
    return
  end

  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { pre .. new_content .. post })
end

--- Cycle to the next list item type based on configured cycle options.
function M.cycle()
  local cfg = config.get()
  local cycle_ids = {}
  for _, item in ipairs(cfg.items) do
    if item.is_cycle_option then
      cycle_ids[#cycle_ids + 1] = item.id
    end
  end
  if #cycle_ids == 0 then
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  if not line then
    return
  end

  local parsed = M.parse_line(line)

  -- Find current type in cycle list
  local current_idx = nil
  for i, id in ipairs(cycle_ids) do
    if id == parsed.type then
      current_idx = i
      break
    end
  end

  -- Next in cycle (or first if current type isn't in cycle)
  local next_idx
  if current_idx then
    next_idx = (current_idx % #cycle_ids) + 1
  else
    next_idx = 1
  end

  local new_line = M.build_line(parsed, cycle_ids[next_idx], row)
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
end

return M
