return {
  {
    "zbirenbaum/copilot.lua",
    enabled = false, -- Disabled for power savings (uses ~2% CPU + 835MB RAM)
    cmd = "Copilot",
    lazy = false,
    config = function()
      require("copilot").setup({
        panel = {
          enabled = true,
          auto_refresh = true,
          keymap = {
            jump_next = "<c-j>",
            jump_prev = "<c-k>",
            accept = "<CR>",
            refresh = "r",
            open = "<M-CR>",
          },
          layout = {
            position = "bottom", -- | top | left | right
            ratio = 0.4,
          },
        },
        filetypes = {
          yaml = true,
        },
        suggestion = {
          enabled = true,
          auto_trigger = true,
          debounce = 75,
          keymap = {
            accept = "<c-a>",
            accept_word = false,
            accept_line = false,
            next = "<M-j>",
            prev = "<M-k>",
            dismiss = "<C-e>",
          },
        },
        copilot_model = "gpt-4o-copilot",
      })
    end
  },
  {
    "zbirenbaum/copilot-cmp",
    enabled = false, -- Disabled with copilot.lua
    after = { "copilot.lua" },
    event = { "InsertEnter", "LspAttach" },
    fix_pairs = true,
    config = function()
      require("copilot_cmp").setup()
    end,
  }
}
