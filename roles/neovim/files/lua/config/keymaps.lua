-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("i", "kj", "<ESC>")
-- vim.keymap.del("n", "sh")
-- vim.keymap.del("v", "<A-j>")
-- vim.keymap.del("v", "<A-k>")

-- vim.keymap.del("n", "<C-Up>")
-- vim.keymap.del("n", "<C-Down>")
-- vim.keymap.del("n", "<C-Right>")
-- vim.keymap.del("n", "<C-Left>")

-- Source files and selected lines so they will work right away with neovim from Teej_dv
vim.keymap.set("n", "<space><space>x", "<cmd>source %<CR>", { desc = "Source File" })
vim.keymap.set("n", "<space>x", ":.lua<CR>", { desc = "Source Line" })
vim.keymap.set("v", "<space>x", ":lua<CR>", { desc = "Source Selected Lines" })

-- Quickfix using Alt
vim.keymap.set("n", "<A-j>", ":copen<CR>")
vim.keymap.set("n", "<A-k>", ":cclose<CR>")
vim.keymap.set("n", "<A-h>", ":cprev<CR>")
vim.keymap.set("n", "<A-l>", ":cnext<CR>")

-- test
--vim.keymap.set("n", "<leader>af", require("telescope.builtin").find_files)
