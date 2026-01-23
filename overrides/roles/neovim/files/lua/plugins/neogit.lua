return {
  "NeogitOrg/neogit",
  -- tag = "v0.0.1", -- needed for Neovim < 10.0.0
  dependencies = {
    "nvim-lua/plenary.nvim", -- required
    "sindrets/diffview.nvim", -- optional - Diff integration

    -- Only one of these is needed, not both.
    "nvim-telescope/telescope.nvim", -- optional
    "ibhagwan/fzf-lua", -- optional
  },
  config = true,
  keys = {
    { "<leader>gg", "<cmd>Neogit<CR>", desc = "[NEOGIT] View" },
    { "<leader>gd", "<cmd>DiffviewOpen<CR>", desc = "[DIFFVIEWOPEN] Open Diff" },
    { "<leader>gl", "<cmd>DiffviewToggle<CR>", desc = "[DIFFVIEWTOGGLE] Open Diff Log" },
    { "<leader>gp", "<cmd>Neogit pull<CR>", desc = "[NEOGIT] Pull" },
    { "<leader>gP", "<cmd>Neogit push<CR>", desc = "[NEOGIT] Push" },
    { "<leader>gb", "<cmd>Telescope git_branches<CR>", desc = "[TELESCOPE] Git Branches" },
    { "<leader>gB", "<cmd>G blame<CR>", desc = "[NEOGIT] Push" },
  },
}
