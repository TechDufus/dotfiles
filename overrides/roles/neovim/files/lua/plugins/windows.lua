return {
  -- Learned that <space>w<space>+ does the same thing in LazyVim
  enabled = false,

  -- Allows the same command to be run over and over, <C-w>hhhhhhhhhhhh
  "nvimtools/hydra.nvim",
  config = function()
    local Hydra = require("hydra")
    Hydra({
      name = "Change / Resize Window Vertical",
      mode = "n",
      body = "<C-w>",
      heads = {
        -- move between windows
        { "k", "<C-w>2+" },
        { "j", "<C-w>2-" },

        -- exit this Hydra
        { "h", nil, { exit = true, nowait = true } },
        { "l", nil, { exit = true, nowait = true } },
        { "q", nil, { exit = true, nowait = true } },
        { ";", nil, { exit = true, nowait = true } },
        { "<Esc>", nil, { exit = true, nowait = true } },
      },
    })
    Hydra({
      name = "Change / Resize Window Horizontal",
      mode = "n",
      body = "<C-w>",
      heads = {
        -- move between windows
        { "h", "<C-w>3>" },
        { "l", "<C-w>3<" },

        -- exit this Hydra
        { "k", nil, { exit = true, nowait = true } },
        { "j", nil, { exit = true, nowait = true } },
        { "q", nil, { exit = true, nowait = true } },
        { ";", nil, { exit = true, nowait = true } },
        { "<Esc>", nil, { exit = true, nowait = true } },
      },
    })
  end,
}
