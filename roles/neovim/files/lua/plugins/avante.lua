return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  lazy = false,
  version = '*', -- set this if you want to always pull the latest change
  opts = {
    provider = "openai",
    auto_suggestions_provider = "openai",
    hints = { enabled = false },
    windows = {
      input = {
        prefix = "》"
      },
    },
  },
  build = "make", -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  dependencies = {
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    -- The below dependencies are optional
    "hrsh7th/nvim-cmp",
    "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
    "zbirenbaum/copilot.lua",      -- for providers='copilot'
    {
      "HakonHarnes/img-clip.nvim", -- support for image pasting
      event = "VeryLazy",
      opts = {
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          use_absolute_path = true, -- required for Windows users
        },
      },
    },
    {
      'MeanderingProgrammer/render-markdown.nvim', -- Make sure to set this up properly if you have lazy=true
      opts = {
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
  },
}
