local prefix = "<Leader>a"
return {
  -- {
  --   "zbirenbaum/copilot.lua",
  --   opts = function(_, opts)
  --     opts.suggestion = opts.suggestion or {}
  --     opts.suggestion.debounce = 200
  --     return opts
  --   end,
  -- },
  {
    "greggh/claude-code.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim", -- Required for git operations
    },
    config = function()
      require("claude-code").setup()
    end,
  },
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = true,
    version = false, -- set this if you want to always pull the latest change
    opts = {
      -- add any opts here
      -- mappings = {
      --   ask = prefix .. "<CR>",
      --   edit = prefix .. "e",
      --   refresh = prefix .. "r",
      --   focus = prefix .. "f",
      --   toggle = {
      --     default = prefix .. "t",
      --     debug = prefix .. "d",
      --     hint = prefix .. "h",
      --     suggestion = prefix .. "s",
      --     repomap = prefix .. "R",
      --   },
      --   diff = {
      --     next = "]c",
      --     prev = "[c",
      --   },
      --   files = {
      --     add_current = prefix .. ".",
      --   },
      -- },
      behaviour = {
        auto_suggestions = false,
        auto_insert = true, -- Automatically enter insert mode when focusing the chat window
      },
      provider = "claude",
      providers = {
        copilot = {
          model = "claude-3.5-sonnet",
          extra_request_body = {
            temperature = 0,
            max_tokens = 8192,
          },
        },
        claude = {
          -- endpoint = "https://api.anthropic.com",
          -- model = "claude-3-5-sonnet-20241022",
          extra_request_body = {
            temperature = 0.75,
            max_tokens = 4096,
          },
        },
      },
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    -- dynamically build it, taken from astronvim
    build = vim.fn.has("win32") == 1 and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
      or "make",
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    --- The below dependencies are optional,
    "echasnovski/mini.pick", -- for file_selector provider mini.pick
    "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
    "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
    "ibhagwan/fzf-lua", -- for file_selector provider fzf
    "stevearc/dressing.nvim", -- for input provider dressing
    "folke/snacks.nvim", -- for input provider snacks
    "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
    "zbirenbaum/copilot.lua", -- for providers='copilot'
    {
      -- support for image pasting
      "HakonHarnes/img-clip.nvim",
      event = "VeryLazy",
      opts = {
        -- recommended settings
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          -- required for Windows users
          use_absolute_path = true,
        },
      },
    },
    {
      -- Make sure to set this up properly if you have lazy=true
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
  },
}

-- Api Key pulled from https://codeium.com/install/vscode
-- search for user_token and pull it out of that request the format is a JWT token. DUMB!!!
-- Also ~/.curlrc needed to have a proxy statement as defined by the FTC confluence page
-- return {
--   "Exafunction/codeium.nvim",
--   dependencies = {
--     "nvim-lua/plenary.nvim",
--     "hrsh7th/nvim-cmp",
--   },
--   opts = {
--     api = {
--       host = "",
--       port = "443",
--     },
--     enterprise_mode = true,
--     enable_chat = true,
--     detect_proxy = true,
--   },
-- }
