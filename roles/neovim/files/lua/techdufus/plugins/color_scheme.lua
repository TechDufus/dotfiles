-- Theme Settings
-- vim.g.catppuccin_flavour = "mocha"
-- require('catppuccin').setup({
--   transparent_background = true,
--   term_colors = true,
-- })
-- require('onedark').setup {
--     style = 'darker',
--     transparent = true,
-- }
-- require('onedark').load()
require("bluloco").setup({
  style = "auto",               -- "auto" | "dark" | "light"
  transparent = true,
  italics = false,
  terminal = vim.fn.has("gui_running") == 1, -- bluoco colors are enabled in gui terminals per default.
})

vim.cmd('colorscheme bluloco')
-- vim.cmd [[colorscheme catppuccin]]
