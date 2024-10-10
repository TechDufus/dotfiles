return  {
  -- Highlight todo, notes, etc in comments
  'folke/todo-comments.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  -- RESEARCH: It appears this plugin does not export functions.
  -- Might have to map directly to :TodoTelescope
  keys = {
    { "<leader>td", "<cmd>TodoTelescope<cr>", { desc = 'Show all [T]o[D]o Comments' } },
  },
  lazy = false,
  opts = {
    signs = true,           -- show icons in the signs column
    merge_keywords = true, -- use only these
    keywords = {
      BECAUSE = { icon = "∵", color = "argumentation" },
      BUG = { icon = "", color = "error" },
      BAD = { icon = "󰇸", color = "default" },
      BROKEN = { icon = "󰋮", color = "error" },
      CHALLENGE = { icon = "", color = "actionItem" },
      CLAIM = { icon = "➰", color = "argumentation" },
      CONCLUSION = { icon = "∴", color = "default" },
      CONTEXT = { icon = "❄", color = "info" },
      DECIDE = { icon = "", color = "actionItem" },
      DEF = { icon = "∆", color = "info" },
      DEFINITION = { icon = "∆", color = "info" },
      DISABLED = { icon = "", color = "default" },
      DOC = { icon = "", color = "info" },
      DOCUMENTATION = { icon = "", color = "info" },
      EXPLANATION = { icon = "∵", color = "argumentation" },
      FIXME = { icon = "", color = "error" },
      HACK = { icon = "", color = "info" },
      IDEA = { icon = "☀", color = "idea" },
      JUSTIFICATION = { icon = "∵", color = "argumentation" },
      LOOKUP = { icon = "󰊪", color = "actionItem" },
      MAYBE = { icon = "󱍊", color = "idea" },
      NOMENCLATURE = { icon = "∆", color = "info" },
      NOTE = { icon = "❦", color = "info" },
      NICE = { icon = "", color = "idea" },
      PITCH = { icon = "♮", color = "argumentation" },
      PROMISE = { icon = "✪", color = "actionItem" },
      QED = { icon = "∴", color = "argumentation" },
      REASON = { icon = "∵", color = "argumentation" },
      REF = { icon = "", color = "info" },
      REFERENCE = { icon = "", color = "info" },
      RESEARCH = { icon = "⚗", color = "actionItem" },
      SAD = { icon = "󰋔", color = "default" },
      SECTION = { icon = "§", color = "info" },
      SRC = { icon = "", color = "info" },
      THEREFORE = { icon = "∴", color = "argumentation" },
      TIP = { icon = "󰓠", color = "argumentation" },
      TODO = { icon = "★", color = "actionItem" },
      URL = { icon = "", color = "info" },
      WARN = { icon = "󰀦", color = "warning" },
      WARNING = { icon = "󰀦", color = "warning" },
      WORRY = { icon = "⌇", color = "warning" },
      YIKES = { icon = "⁉", color = "error" },
      WHAA = { icon = "⁇", color = "default" },
    },
    colors = {
      actionItem = { "ActionItem", "#A0CC00" },
      argumentation = { "Argument", "#8C268C" },
      idea = { "IdeaMsg", "#FDFF74" },
    }
  }
}

