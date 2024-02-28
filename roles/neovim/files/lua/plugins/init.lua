return {
  "nvim-lua/popup.nvim",   -- An implementation of the Popup API from vim in Neovim
  "nvim-lua/plenary.nvim", -- Useful lua functions used ny lots of plugins
  'simrat39/symbols-outline.nvim',
  "ThePrimeagen/harpoon",
  { "windwp/nvim-ts-autotag", dependencies = "nvim-treesitter" },
  "neovim/nvim-lspconfig",
  ({ "mfussenegger/nvim-dap", dependencies = { "rcarriga/nvim-dap-ui" } }),
  "leoluz/nvim-dap-go",
  "sharkdp/fd",
  {
    'lewis6991/gitsigns.nvim',
    config = function()
      require('gitsigns').setup()
    end
  },
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
  },
  {
    "sbdchd/neoformat",
  },
  -- {
  --     'akinsho/bufferline.nvim',
  --     version = "*",
  --     dependencies = 'nvim-tree/nvim-web-devicons',
  --     config = true,
  -- },
  'crispgm/nvim-go',
  'erikzaadi/vim-ansible-yaml',
}
