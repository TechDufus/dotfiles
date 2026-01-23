ConfigMode = "rich" -- changes the config to suit either a full nerdfont/truecolor setup, or a simple 8 color tty ('rich' or 'simple')
-- disable netrw at the very start of your init.lua (strongly advised)
vim.g.loaded = 1
vim.g.loaded_netrwPlugin = 1

require('techdufus.core')
