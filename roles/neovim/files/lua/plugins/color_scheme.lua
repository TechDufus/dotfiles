return {
  -- 'uloco/bluloco.nvim',
  -- dependencies = {
  --   'rktjmp/lush.nvim',
  -- },
  -- config = function()
  --   require("bluloco").setup({
  --     style = "auto",     -- "auto" | "dark" | "light"
  --     transparent = true,
  --     italics = false,
  --     terminal = vim.fn.has("gui_running") == 1,     -- bluoco colors are enabled in gui terminals per default.
  --   })
  --
  --   vim.cmd('colorscheme bluloco')
  -- end,
  -- "sainnhe/sonokai",
  -- priority = 1000,
  -- config = function()
  --   vim.g.sonokai_transparent_background = "1"
  --   vim.g.sonokai_enable_italic = "0"
  --   vim.g.sonokai_style = "andromeda"
  --   vim.cmd.colorscheme("sonokai")
  -- end,
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function()
    require("catppuccin").setup({
      flavor = "macchiato", -- latte, frappe, macchiato, mocha
      transparent_background = false,
      color_overrides = {
        mocha = {
          base = "#030304",
          mantle = "#030304",
          crust = "#030304",
        },
      },
      default_integrations = true,
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
