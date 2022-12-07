-- Theme Settings
vim.g.catppuccin_flavour = "mocha"
require('catppuccin').setup({
  transparent_background = true,
  term_colors = true,
})
-- require('onedark').setup {
--     style = 'darker',
--     transparent = true,
-- }
-- require('onedark').load()
vim.cmd [[colorscheme catppuccin]]
