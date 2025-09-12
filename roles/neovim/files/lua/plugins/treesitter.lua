return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = {"BufReadPre", "BufNewFile"},
  keymaps = {
    { "n", "<leader>it", ":InspectTree<CR>" },
  },
  dependencies = {
    "nvim-treesitter/nvim-treesitter-textobjects",
  },
  config = function()
    require 'nvim-treesitter.configs'.setup {
      -- A list of parser names, or "all"
      ensure_installed = "all",
      -- Install parsers synchronously (only applied to `ensure_installed`)
      sync_install = true,
      -- Automatically install missing parsers when entering buffer
      -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
      auto_install = true,
      highlight = {
        -- `false` will disable the whole extension
        enable = true,
        additional_vim_regex_highlighting = true,
      },
      autotag = { enable = true },
      indent = { enable = true },
      rainbow = {
        enable = true,
        -- Which query to use for finding delimiters
        query = 'rainbow-parens',
        -- Highlight the entire buffer all at once
        strategy = require('rainbow-delimiters').strategy.global,
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-n>",
          node_incremental = "<C-n>",
          scope_incremental = false,
          node_decremental = "<bs>",
        },
      }
    }
  end
}
