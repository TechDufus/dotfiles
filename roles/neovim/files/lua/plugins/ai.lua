local prefix = "<Leader>a"
return {
  {
    "zbirenbaum/copilot.lua",
    opts = function(_, opts)
      opts.suggestion = opts.suggestion or {}
      opts.suggestion.debounce = 200
      return opts
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
      provider = "copilot",
      providers = {
        copilot = {
          model = "claude-3.5-sonnet",
          extra_request_body = {
            temperature = 0,
            max_tokens = 8192,
          },
        },
      },
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    -- dynamically build it, taken from astronvim
    build = vim.fn.has("win32") == 1 and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
      or "make",
    dependencies = {
      -- "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
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
        dependencies = {
          -- make sure rendering happens even without opening a markdown file first
          "yetone/avante.nvim",
        },
        opts = function(_, opts)
          opts.file_types = opts.file_types or { "markdown", "norg", "rmd", "org" }
          vim.list_extend(opts.file_types, { "Avante" })
        end,
      },
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
