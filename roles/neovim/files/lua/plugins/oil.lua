return {
  "stevearc/oil.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("oil").setup({
      keymaps = {
        ["<Esc>"] = "actions.close",
      },
      view_options = {
        show_hidden = true,
      },
    })
  end,
  keys = {
    -- { "<leader>-", "<cmd>Oil<cr>", mode = "n", desc = "Open Filesystem" },
    -- { "-", "<cmd>Oil<cr>", mode = "n", desc = "Open Filesystem" },
    { "<leader>-", "<cmd>Oil --float<cr>", mode = "n", desc = "Open Floating Filesystem" },
  },
}
