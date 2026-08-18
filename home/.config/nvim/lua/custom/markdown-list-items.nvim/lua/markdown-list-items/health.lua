--- Health check for markdown-list-items.nvim
--- Run with :checkhealth markdown-list-items

local M = {}

function M.check()
  vim.health.start("markdown-list-items.nvim")

  -- Setup state
  local config = require("markdown-list-items.config")
  if config._did_setup then
    vim.health.ok("setup() has been called")
  else
    vim.health.info("setup() has not been called (using defaults)")
  end

  -- Filetypes
  local cfg = config.get()
  if cfg.filetypes and #cfg.filetypes > 0 then
    vim.health.ok("Active filetypes: " .. table.concat(cfg.filetypes, ", "))
  else
    vim.health.warn("No filetypes configured")
  end

  -- Items
  local cycle_count = 0
  for _, item in ipairs(cfg.items) do
    if item.is_cycle_option then
      cycle_count = cycle_count + 1
    end
  end
  vim.health.ok(string.format("%d item types (%d in cycle)", #cfg.items, cycle_count))

  -- Mappings
  if cfg.mappings == false then
    vim.health.info("Default keymaps disabled (mappings = false)")
  else
    local disabled = {}
    for action, key in pairs(cfg.mappings) do
      if key == false then
        disabled[#disabled + 1] = action
      end
    end
    if #disabled > 0 then
      vim.health.info("Disabled keymaps: " .. table.concat(disabled, ", "))
    else
      vim.health.ok("All default keymaps enabled")
    end
  end
end

return M
