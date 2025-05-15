---@diagnostic disable: undefined-global, undefined-field
-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.swapfile = false
vim.g.snacks_animate = false

-- If SSHing, then enable OSC52 so you can copy out of a remote terminal
-- if vim.env.SSH_TTY then
--   vim.opt.clipboard:append("unnamedplus")
--   local function paste()
--     return vim.split(vim.fn.getreg(""), "\n")
--   end
--   vim.g.clipboard = {
--     name = "OSC 52",
--     copy = {
--       ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
--       ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
--     },
--     paste = {
--       ["+"] = paste,
--       ["*"] = paste,
--     },
--   }
-- end
