return {
  "epwalsh/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  lazy = true,
  ft = "markdown",
  -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  -- event = {
  --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
  --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/**.md"
  --   "BufReadPre path/to/my-vault/**.md",
  --   "BufNewFile path/to/my-vault/**.md",
  -- },
  dependencies = {
    -- Required.
    "nvim-lua/plenary.nvim",

    -- see below for full list of optional dependencies 👇
  },
  opts = {
    workspaces = {
      {
        name = "personal",
        path = "~/SecondBrain",
      },
      {
        name = "no-vault",
        path = function()
          -- alternatively use the CWD:
          -- return assert(vim.fn.getcwd())
          return assert(vim.fs.dirname(vim.api.nvim_buf_get_name(0)))
        end,
        overrides = {
          templates = {
            subdir = vim.NIL,
          },
          notes_subdir = "SecondBrain/UnsortedNotes",
          disable_frontmatter = true,
        },
      },
    },
    completion = {
      nvim_cmp = true,
      min_chars = 2,
    },
    disable_frontmatter = true,
    notes_subdir = "UnsortedNotes",
    new_notes_location = "notes_subdir",
    -- Either 'wiki' or 'markdown'.
    preferred_link_style = "markdown",
    wiki_link_func = function(opts)
      if opts.id == nil then
        return string.format("[[%s]]", opts.label)
      elseif opts.label ~= opts.id then
        return string.format("[[%s|%s]]", opts.id, opts.label)
      else
        return string.format("[[%s]]", opts.id)
      end
    end,

    note_frontmatter_func = function(note)
      -- This is equivalent to the default frontmatter function.
      local out = { id = note.id, aliases = note.aliases, tags = note.tags, area = "", project = "" }

      -- `note.metadata` contains any manually added fields in the frontmatter.
      -- So here we just make sure those fields are kept in the frontmatter.
      if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
        for k, v in pairs(note.metadata) do
          out[k] = v
        end
      end
      return out
    end,
    note_id_func = function(title)
      local suffix = ""
      if title ~= nil then
        -- If title is given, transform it into valid file name.
        -- suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
        suffix = title
      else
        -- If title is nil, just add 4 random uppercase letters to the suffix.
        for _ = 1, 4 do
          suffix = suffix .. string.char(math.random(65, 90))
        end
      end
      return suffix .. "-" .. tostring(os.time())
    end,
    templates = {
      subdir = "Templates",
      date_format = "%Y-%m-%d-%a",
      time_format = "%H:%M",
      tags = "",
    },
    mappings = {
      -- "Obsidian follow"
      ["<leader>of"] = {
        action = function()
          return require("obsidian").util.gf_passthrough()
        end,
        opts = { noremap = false, expr = true, buffer = true },
      },

      -- Toggle check-boxes "obsidian done"
      ["<leader>och"] = {
        action = function()
          return require("obsidian").util.toggle_checkbox()
        end,
        opts = { buffer = true },
      },
    },
  },
  keys = {
    { "<leader>onn", "<cmd>ObsidianNew<cr>",                                                                                                                                                    silent = true, desc = "Obsidian New Note" },
    { "<leader>ogs", "<cmd>lua require('telescope.builtin').live_grep({ cwd = '~/SecondBrain', hidden = true , search_dirs = {'Archive','Areas','Projects','Resources','UnsortedNotes'}})<cr>", silent = true, desc = "File Explorer" },
    { "<leader>ofs", "<cmd>lua require'telescope.builtin'.find_files({cwd = '~/SecondBrain', find_command = {'rg', '--files', '--hidden', '-g', '!.git' }})<cr>",                               silent = true, desc = "File Explorer" },
  },
}
