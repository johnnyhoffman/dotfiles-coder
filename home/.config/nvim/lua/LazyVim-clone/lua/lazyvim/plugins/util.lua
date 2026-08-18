-- Terminal Mappings
local function term_nav(dir)
  ---@param self snacks.terminal
  return function(self)
    return self:is_floating() and "<c-" .. dir .. ">" or vim.schedule(function()
      vim.cmd.wincmd(dir)
    end)
  end
end

-- JH MODIFICATION START
-- Prompt for a name and open (or create) that named scratch buffer. Named
-- scratches are distinct files per name and show their name in the picker.
local function scratch_new_named()
  vim.ui.input({ prompt = "Scratch name: " }, function(name)
    if name and name ~= "" then
      Snacks.scratch({ name = name })
    end
  end)
end

-- Scratch picker limited to scratches created in the current project (cwd).
-- Same comparison scratch uses for its filekey, so it matches exactly the
-- buffers `Snacks.scratch()` would open from this directory.
local function scratch_select_cwd()
  local cwd = svim.fs.normalize(assert(vim.uv.cwd()))
  Snacks.picker.scratch({
    finder = function(opts, ctx)
      local items = require("snacks.picker.source.scratch").scratch(opts, ctx)
      return vim.tbl_filter(function(item)
        return item.item.cwd == cwd
      end, items)
    end,
  })
end

-- Rename a scratch buffer: the one in the current buffer if we're in a
-- scratch, otherwise the project's default "Scratch". Snacks has no rename
-- API; scratches are looked up by a hash of name+cwd(+branch+count), so a
-- rename means rewriting the .meta and moving the file to the new hash path
-- (the same dance scratch's own migrate() does). Renaming the default frees
-- its key, so the next `Snacks.scratch()` toggle creates a fresh default.
local function scratch_rename()
  local buf_file = svim.fs.normalize(vim.api.nvim_buf_get_name(0))
  local cwd = svim.fs.normalize(assert(vim.uv.cwd()))
  local target, default
  for _, item in ipairs(Snacks.scratch.list()) do
    if item.file == buf_file then
      target = item
      break
    elseif item.name == "Scratch" and item.cwd == cwd and not default then
      default = item
    end
  end
  target = target or default
  if not target then
    return Snacks.notify.warn("No scratch buffer to rename")
  end
  -- Write + drop any buffer holding `file`, so autowrite-on-hide can't
  -- resurrect the old path after the move. Returns whether it was visible.
  local function drop_buf(file)
    local buf = vim.fn.bufnr(file)
    if buf == -1 then
      return false
    end
    local was_open = vim.fn.bufwinid(buf) ~= -1
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("silent! write")
    end)
    vim.api.nvim_buf_delete(buf, { force = true })
    return was_open
  end
  vim.ui.input({ prompt = ("Rename scratch '%s' to: "):format(target.name) }, function(name)
    if not name or name == "" or name == target.name then
      return
    end
    -- A scratch whose filekey fields all match would hash to the same file
    -- and be silently clobbered by the rename — confirm first.
    for _, item in ipairs(Snacks.scratch.list()) do
      if
        item.file ~= target.file
        and item.name == name
        and item.cwd == target.cwd
        and item.branch == target.branch
        and item.count == target.count
        and item.ft == target.ft
      then
        local choice =
          vim.fn.confirm(("Scratch '%s' already exists here and will be overwritten."):format(name), "&Overwrite\n&Cancel", 2)
        if choice ~= 1 then
          return
        end
        drop_buf(item.file)
        break
      end
    end
    local was_open = drop_buf(target.file)
    local root = Snacks.config.get("scratch", { root = vim.fn.stdpath("data") .. "/scratch" }).root
    local old = target.file
    target.name = name
    target.stat = nil -- added by list(); not part of the meta format
    local new_file = Snacks.scratch._write_meta(root, target)
    vim.fn.rename(old, new_file)
    os.remove(old .. ".meta")
    if was_open then
      Snacks.scratch.open({ file = new_file, name = name, ft = target.ft, icon = target.icon })
    end
  end)
end

-- Normalized root dir holding scratch files.
local function scratch_root()
  return svim.fs.normalize(Snacks.config.get("scratch", { root = vim.fn.stdpath("data") .. "/scratch" }).root)
end

-- True when the current buffer is a scratch file.
local function in_scratch()
  return vim.startswith(svim.fs.normalize(vim.api.nvim_buf_get_name(0)), scratch_root() .. "/")
end

-- Leave the current scratch by switching to another buffer. Hiding it fires
-- snacks' autowrite, which saves the file and unlists the buffer (dropping the
-- chip) — the same "save and close" you get from a tab-switch. We do it by
-- switching buffers rather than letting snacks' toggle run `:close`, which
-- errors when the scratch is the only window.
local function leave_scratch()
  local cur = vim.api.nvim_get_current_buf()
  local alt = vim.fn.bufnr("#")
  if alt > 0 and alt ~= cur and vim.api.nvim_buf_is_valid(alt) and vim.bo[alt].buflisted then
    vim.cmd("buffer #")
    return
  end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if b ~= cur and vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted then
      vim.api.nvim_set_current_buf(b)
      return
    end
  end
  vim.cmd("enew")
end

-- Toggle: leave the scratch if we're in one, otherwise open the project scratch.
local function scratch_toggle()
  if in_scratch() then
    leave_scratch()
  else
    Snacks.scratch()
  end
end

-- Session-restored scratch buffers never went through `Snacks.scratch.open`,
-- so they lack snacks' per-buffer autowrite-on-hide autocmd: leaving them
-- wouldn't save or unlist them, so the first <leader>SS appears to do nothing
-- (you'd have to re-open through snacks first to "adopt" the buffer). Mirror
-- snacks' behavior for any scratch-root buffer so they all save + drop their
-- chip on hide regardless of how they were opened. Harmlessly idempotent with
-- snacks' own autowrite for snacks-opened scratches.
vim.api.nvim_create_autocmd("BufHidden", {
  callback = function(ev)
    if not Snacks then
      return
    end
    if vim.startswith(svim.fs.normalize(vim.api.nvim_buf_get_name(ev.buf)), scratch_root() .. "/") then
      vim.api.nvim_buf_call(ev.buf, function()
        vim.cmd("silent! write")
      end)
      vim.bo[ev.buf].buflisted = false
    end
  end,
})

-- With `position = "current"` the scratch shares your only window, so the old
-- "close other scratch windows" logic is obsolete (a current-window scratch
-- can't stack) and harmful (it would close your current window). Opening a
-- scratch now just swaps it into the current window; autowrite saves + unlists
-- whatever scratch was there. The one rough edge: snacks' built-in toggle runs
-- `:close` when you re-open the scratch you're already viewing, erroring on the
-- last window. Short-circuit that so every entry point (picker confirm, etc.)
-- is safe; `scratch_toggle` handles the deliberate "leave" instead.
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    local orig_open = Snacks.scratch.open
    Snacks.scratch.open = function(opts)
      local target = Snacks.scratch.get(opts)
      if svim.fs.normalize(vim.api.nvim_buf_get_name(0)) == target.file then
        return
      end
      return orig_open(opts)
    end
  end,
})
-- JH MODIFICATION END

return {

  -- Snacks utils
  {
    "snacks.nvim",
    opts = {
      bigfile = { enabled = true },
      quickfile = { enabled = true },
      terminal = {
        win = {
          keys = {
            nav_h = { "<C-h>", term_nav("h"), desc = "Go to Left Window", expr = true, mode = "t" },
            nav_j = { "<C-j>", term_nav("j"), desc = "Go to Lower Window", expr = true, mode = "t" },
            nav_k = { "<C-k>", term_nav("k"), desc = "Go to Upper Window", expr = true, mode = "t" },
            nav_l = { "<C-l>", term_nav("l"), desc = "Go to Right Window", expr = true, mode = "t" },
            hide_slash = { "<C-/>", "hide", desc = "Hide Terminal", mode = "t" },
            hide_underscore = { "<c-_>", "hide", desc = "which_key_ignore", mode = "t" },
          },
        },
      },
    },
    -- stylua: ignore
    keys = {
      -- JH MODIFICATION START
      -- TODO this isn't what I want, but not sure what I'd prefer for now
      -- { "<leader>.",  function() Snacks.scratch() end, desc = "Toggle Scratch Buffer" },
      -- { "<leader>S",  function() Snacks.scratch.select() end, desc = "Select Scratch Buffer" },
      { "<leader>SS",  scratch_toggle, desc = "Toggle [S]cratch Buffer" },
      { "<leader>Sn",  scratch_new_named, desc = "[n]ew Named Scratch Buffer" },
      { "<leader>Sr",  scratch_rename, desc = "[r]ename Scratch Buffer" },
      { "<leader>Ss",  scratch_select_cwd, desc = "Select [S]cratch Buffer (project)" },
      { "<leader>ss",  scratch_select_cwd, desc = "Select [s]cratch Buffer (project)" },
      { "<leader>sS",  function() Snacks.scratch.select() end, desc = "Select [S]cratch Buffer (all)" },
      -- JH MODIFICATION START
      { "<leader>dps", function() Snacks.profiler.scratch() end, desc = "Profiler Scratch Buffer" },
    },
  },

  -- Session management. This saves your session in the background,
  -- keeping track of open buffers, window arrangement, and more.
  -- You can restore sessions when returning through the dashboard.
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    -- stylua: ignore
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
      { "<leader>qS", function() require("persistence").select() end,desc = "Select Session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't Save Current Session" },
    },
  },

  -- library used by other plugins
  { "nvim-lua/plenary.nvim", lazy = true },
}
