-- Theme Settings
require("bluloco").setup({
  style = "auto",               -- "auto" | "dark" | "light"
  transparent = true,
  italics = false,
  terminal = vim.fn.has("gui_running") == 1, -- bluoco colors are enabled in gui terminals per default.
  guicursor = true
})

vim.cmd('colorscheme bluloco')
