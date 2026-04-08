local lsp_servers = {
  "gopls",
  "ansiblels",
  "bashls",
  "dockerls",
  "jsonls",
  "powershell_es",
  "solargraph",
  "terraformls",
  "lua_ls",
  "yamlls",
  "cssls",
  "pylsp",
}

return {
  {
    'mason-org/mason.nvim',
    lazy = false,
    opts = {},
  },

  -- Autocompletion
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    config = function()
      -- cmp icons
      local cmp = require('cmp')
      local icons = require('techdufus.core.icons')
      -- local lspkind = require('lspkind')
      local luasnip = require('luasnip')
      local cmp_mapping = require('cmp.config.mapping')
      local cmp_types = require('cmp.types.cmp')
      local utils = require('techdufus.core.utils')

      require('luasnip.loaders.from_vscode').lazy_load()

      cmp.setup {
        formatting = {
          fields = { "kind", "abbr", "menu" },
          format = function(entry, vim_item)
            local max_width = 0
            if max_width ~= 0 and #vim_item.abbr > max_width then
              vim_item.abbr = string.sub(vim_item.abbr, 1, max_width - 1) .. icons.ui.Ellipsis
            end
            vim_item.kind = icons.kind[vim_item.kind] .. " " .. vim_item.kind

            vim_item.menu = ({
              nvim_lsp = "[LSP]",
              emoji = "[Emoji]",
              path = "[Path]",
              calc = "[Calc]",
              vsnip = "[Snippet]",
              luasnip = "[LuaSnip]",
              buffer = "[Buffer]",
              tmux = "[Tmux]",
              nvim_lua = "[Lua]",
              -- copilot = "[Copilot]",
              treesitter = "[Treesitter]",
            })[entry.source.name]
            vim_item.dup = ({
              buffer = 1,
              path = 1,
              nvim_lsp = 0,
              luasnip = 1,
            })[entry.source.name] or 0
            return vim_item
          end,
        },
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        window = {
          completion = require('cmp.config.window').bordered(),
          documentation = require('cmp.config.window').bordered(),
        },
        sources = cmp.config.sources({
          -- { name = "copilot" },
          {
            name = "nvim_lsp",
            entry_filter = function(entry, ctx)
              local kind = require("cmp.types.lsp").CompletionItemKind[entry:get_kind()]
              return true
            end,
          },
          { name = "path" },
          { name = "luasnip" },
          { name = "saadparwaiz1/cmp_luasnip" },
          { name = "nvim_lua" },
          { name = "buffer" },
          { name = "calc" },
          { name = "emoji" },
          { name = "treesitter" },
          { name = "crates" },
          { name = "tmux" },
        }),
        mapping = cmp_mapping.preset.insert {
          ["<C-k>"] = cmp_mapping(cmp_mapping.select_prev_item(), { "i", "c" }),
          ["<C-j>"] = cmp_mapping(cmp_mapping.select_next_item(), { "i", "c" }),
          ["<Down>"] = cmp_mapping(cmp_mapping.select_next_item { behavior = cmp_types.SelectBehavior.Select }, {
            "i" }),
          ["<Up>"] = cmp_mapping(cmp_mapping.select_prev_item { behavior = cmp_types.SelectBehavior.Select }, {
            "i" }),
          ["<C-d>"] = cmp_mapping.scroll_docs(-4),
          ["<C-f>"] = cmp_mapping.scroll_docs(4),
          ["<C-y>"] = cmp_mapping {
            i = cmp_mapping.confirm { behavior = cmp_types.ConfirmBehavior.Replace, select = false },
            c = function(fallback)
              if cmp.visible() then
                cmp.confirm { behavior = cmp_types.ConfirmBehavior.Replace, select = false }
              else
                fallback()
              end
            end,
          },
          ["<Tab>"] = cmp_mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            elseif utils.jumpable(1) then
              luasnip.jump(1)
            elseif utils.has_words_before() then
              -- cmp.complete()
              fallback()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp_mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<C-Space>"] = cmp_mapping.complete(),
          ["<C-e>"] = cmp_mapping.abort(),
          ['<CR>'] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
            select = false,
          })
        },
      }
    end
  },

  -- LSP
  {
    'neovim/nvim-lspconfig',
    cmd = { 'LspInfo', 'LspInstall', 'LspStart', 'LspStop', 'LspRestart' },
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      { 'hrsh7th/cmp-nvim-lsp' },
      { 'mason-org/mason.nvim' },
      { 'mason-org/mason-lspconfig.nvim' },
    },
    config = function()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      local lsp_group = vim.api.nvim_create_augroup('techdufus_lsp', { clear = true })

      local function telescope_lsp(method)
        return function()
          require("telescope.builtin")[method]()
        end
      end

      local function jump_diagnostic(count)
        vim.diagnostic.jump({
          count = count,
          on_jump = function()
            vim.diagnostic.open_float(nil, {
              focus = false,
              scope = "cursor",
            })
          end,
        })
      end

      vim.lsp.config('*', {
        capabilities = capabilities,
      })

      vim.lsp.config('lua_ls', {
        settings = {
          Lua = {
            diagnostics = {
              globals = { 'vim', 'hs', 'spoon' },
              disable = { 'lowercase-global' },
            },
          },
        },
      })

      vim.lsp.config('ansiblels', {
        settings = {
          ansible = {
            diagnostics = {
              disable = { 'name[template]' }
            },
          },
        },
      })

      vim.api.nvim_create_autocmd('LspAttach', {
        group = lsp_group,
        desc = 'LSP actions',
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          local noremap = { buffer = event.buf, remap = false }
          local bind = vim.keymap.set

          bind('n', 'gD', vim.lsp.buf.declaration, noremap)
          bind('n', 'gd', vim.lsp.buf.definition, noremap)
          bind('n', 'K', vim.lsp.buf.hover, noremap)
          bind('n', 'gi', telescope_lsp("lsp_implementations"), noremap)
          bind('n', 'gt', telescope_lsp("lsp_type_definitions"), noremap)
          bind('n', '<Leader>rn', vim.lsp.buf.rename, noremap)
          bind('n', '<Leader>ca', vim.lsp.buf.code_action, noremap)
          bind('n', 'gr', telescope_lsp("lsp_references"), noremap)
          bind('n', '<Leader>dl', telescope_lsp("diagnostics"), noremap)
          bind('n', '<Leader>ld', vim.diagnostic.open_float, noremap)
          bind('n', '[d', function() jump_diagnostic(-1) end, noremap)
          bind('n', ']d', function() jump_diagnostic(1) end, noremap)
          bind('n', '<Leader>q', vim.diagnostic.setloclist, noremap)
          bind("n", "<Leader>f", function() vim.lsp.buf.format({ async = true }) end, noremap)
          if client and vim.lsp.inlay_hint and client:supports_method('textDocument/inlayHint') then
            vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
          end
          -- if client is gopls then define bindings
          if client and client.name == 'gopls' then
            bind("n", "<Leader>gtf", "<cmd>GoTestFile<CR>", noremap)
            bind("n", "<Leader>gtff", "<cmd>GoTestFunc<CR>", noremap)
            bind("n", "<Leader>gtt", "<cmd>GoTest<CR>", noremap)
            bind("n", "<Leader>gta", "<cmd>GoTestAll<CR>", noremap)
          end
        end,
      })

      require('mason-lspconfig').setup({
        ensure_installed = lsp_servers,
        automatic_enable = false,
      })
      vim.lsp.enable(lsp_servers)
    end
  },
  {
    "crispgm/nvim-go",
    dependencies = {
      "nvim-lua/plenary.nvim",
      -- "rcarriga/nvim-notify",
    },
    config = function()
      require('go').setup({
        -- notify: use nvim-notify
        notify = true,
        -- auto commands
        auto_format = true,
        auto_lint = true,
        -- linters: revive, errcheck, staticcheck, golangci-lint
        linter = 'revive',
        -- linter_flags: e.g., {revive = {'-config', '/path/to/config.yml'}}
        linter_flags = {},
        -- lint_prompt_style: qf (quickfix), vt (virtual text)
        lint_prompt_style = 'vt',
        -- formatter: goimports, gofmt, gofumpt
        formatter = 'goimports',
        -- maintain cursor position after formatting loaded buffer
        maintain_cursor_pos = true,
        -- test flags: -count=1 will disable cache
        test_flags = { '-v' },
        test_timeout = '30s',
        test_env = {},
        -- show test result with popup window
        test_popup = true,
        test_popup_auto_leave = true,
        test_popup_width = 80,
        test_popup_height = 10,
        -- test open
        test_open_cmd = 'edit',
        -- struct tags
        tags_name = 'json',
        tags_options = { 'json=omitempty' },
        tags_transform = 'snakecase',
        tags_flags = { '-skip-unexported' },
        -- quick type
        quick_type_flags = { '--just-types' },
      })
    end,
    event = { "CmdlineEnter" },
    ft = { "go", 'gomod' },
    build = ':lua require("go.install").update_all_sync()' -- if you need to install/update all binaries
  },
}
