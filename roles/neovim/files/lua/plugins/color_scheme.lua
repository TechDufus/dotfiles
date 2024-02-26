return {
  -- 'uloco/bluloco.nvim',
  -- dependencies = {
  --     'rktjmp/lush.nvim',
  -- },
  -- config = function()
  --     require("bluloco").setup({
  --         style = "auto", -- "auto" | "dark" | "light"
  --         transparent = true,
  --         italics = false,
  --         terminal = vim.fn.has("gui_running") == 1, -- bluoco colors are enabled in gui terminals per default.
  --     })
  --
  --     vim.cmd('colorscheme bluloco')
  -- end,
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function()
    require("catppuccin").setup({
      flavor = "macchiato", -- latte, frappe, macchiato, mocha
      transparent_background = true,
      color_overrides = {
        mocha = {
          base = "#000000",
          mantle = "#000000",
          crust = "#000000",
        },
      },
      integrations = {
        cmp = true,
        gitsigns = true,
        mason = true,
        markdown = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
        neotest = true,
        neotree = true,
        noice = true,
        notify = true,
        telescope = true,
        treesitter = true,
        treesitter_context = true,
      },
    })
    vim.cmd('colorscheme catppuccin')
  end,
}
