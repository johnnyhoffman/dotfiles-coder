-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua (../LazyVim-clone/lua/lazyvim/config/keymaps.lua)
-- Add any additional keymaps here

-- Disable arrow keys in normal mode
vim.keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')
vim.keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')

vim.keymap.set("n", "<c-w><c-w>", "<cmd>WhichKey<cr>", { desc = "WhichKey" })

vim.keymap.set("n", "<leader><Space>", function()
    require("which-key").show({ keys = "<leader>" })
end, { desc = "which_key_ignore" })

-- H and L did this but I disabled them in favor of this
vim.keymap.set({ "n", "v", "i" }, "<C-Tab>", "<Cmd>BufferLineCycleNext<CR>", { desc = "Next Buffer" })
vim.keymap.set({ "n", "v", "i" }, "<C-S-Tab>", "<Cmd>BufferLineCyclePrev<CR>", { desc = "Previous Buffer" })

vim.keymap.set("i", "<C-h>", "<C-o><C-w>h", { desc = "Go to Left Window (Insert Mode)" })
vim.keymap.set("i", "<C-j>", "<C-o><C-w>j", { desc = "Go to Lower Window (Insert Mode)" })
vim.keymap.set("i", "<C-k>", "<C-o><C-w>k", { desc = "Go to Upper Window (Insert Mode)" })
vim.keymap.set("i", "<C-l>", "<C-o><C-w>l", { desc = "Go to Right Window (Insert Mode)" })
vim.keymap.set("v", "<C-h>", "<C-w>h", { desc = "Go to Left Window (Visual Mode)" })
vim.keymap.set("v", "<C-j>", "<C-w>j", { desc = "Go to Lower Window (Visual Mode)" })
vim.keymap.set("v", "<C-k>", "<C-w>k", { desc = "Go to Upper Window (Visual Mode)" })
vim.keymap.set("v", "<C-l>", "<C-w>l", { desc = "Go to Right Window (Visual Mode)" })

vim.keymap.set("n", "<leader>.l", "<cmd>Lazy<cr>", { desc = "[l]azy.nvim" })
vim.keymap.set("n", "<leader>.x", "<cmd>LazyExtras<cr>", { desc = "lazy E[x]tras" })
vim.keymap.set("n", "<leader>.hl", "<cmd>LazyHealth<cr>", { desc = "[l]azy" })
vim.keymap.set("n", "<leader>.hL", "<cmd>checkhealth vim.lsp<cr>", { desc = "vim.[L]sp" })
vim.keymap.set("n", "<leader>.ht", "<cmd>checkhealth nvim-treesitter<cr>", { desc = "nvim-[t]reesitter" })

vim.keymap.set("v", "<leader>P", '"_dP', { desc = "[p]ut without overwriting register" })

vim.keymap.set("n", "gV", "`[v`]", { remap = true, desc = "[v]isually select last put operation" })

-- Normal-mode `P` override lives in ../plugins/added/yanky.lua (registered via
-- yanky's own `keys` spec so it survives the plugin's lazy load).

vim.keymap.set("n", "<leader>fy", function()
    local relative_path = vim.fn.expand("%")
    vim.fn.setreg("+", relative_path)
    vim.notify("Yanked relative path: " .. relative_path)
end, { desc = "[y]ank relative path" })
vim.keymap.set("n", "<leader>fY", function()
    local absolute_path = vim.fn.expand("%:p")
    vim.fn.setreg("+", absolute_path)
    vim.notify("Yanked absolute path: " .. absolute_path)
end, { desc = "[Y]ank absolute path" })

vim.keymap.set("n", "<leader>fp", function()
    local path = vim.fn.getreg("+")
    if path and path ~= "" then
        vim.cmd("edit " .. vim.fn.fnameescape(path))
    else
        vim.notify("Yank register is empty", vim.log.levels.WARN)
    end
end, { desc = "[p]ut (open from yank register)" })

-- Minuet (../plugins/added/minuet-ai.lua). Spec-file check because the
-- generated work dotfiles (coder/) exclude minuet entirely.
if vim.uv.fs_stat(vim.fn.stdpath("config") .. "/lua/plugins/added/minuet-ai.lua") then
    vim.keymap.set({ "n", "v" }, "<leader>amo", function()
        require("minuet").change_preset("gpt_5_2")
    end, { desc = "use [o]penai gpt-5.2", noremap = true, silent = true })
    vim.keymap.set({ "n", "v" }, "<leader>amk", function()
        require("minuet").change_preset("kimi_k2")
    end, { desc = "use groq [k]imi k2", noremap = true, silent = true })
    vim.keymap.set({ "n", "v" }, "<leader>amc", function()
        require("minuet").change_preset("codestral")
    end, { desc = "use mistral [c]odestral", noremap = true, silent = true })
    vim.keymap.set({ "n", "v" }, "<leader>amz", function()
        require("minuet").change_preset("glm_5")
    end, { desc = "use [z]ai glm-5", noremap = true, silent = true })
end


-- record with Q instead of q, because I keep hitting Q when I'm trying to quit certain plugins
vim.keymap.set("n", "Q", "q", { desc = "Record macro (Q)" })
vim.keymap.set("n", "q", "<nop>", { desc = "Disable macro record on q" })
