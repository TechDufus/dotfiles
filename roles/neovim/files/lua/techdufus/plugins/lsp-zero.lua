return {
    {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v2.x',
        lazy = false,
        dependencies = {
            -- LSP Support
            { 'neovim/nvim-lspconfig' }, -- Required
            {
                -- Optional
                'williamboman/mason.nvim',
                build = function()
                    pcall(vim.cmd, 'MasonUpdate')
                end,
            },
            { 'williamboman/mason-lspconfig.nvim' }, -- Optional

            -- Autocompletion
            { 'hrsh7th/nvim-cmp' },     -- Required
            { 'hrsh7th/cmp-nvim-lsp' }, -- Required
            { 'L3MON4D3/LuaSnip' },     -- Required

            { 'onsails/lspkind.nvim' },
        },
        config = function()
            require('mason.settings').set({
                ui = {
                    border = 'rounded'
                }
            })
            local lsp = require('lsp-zero').preset("recommended")

            lsp.ensure_installed({
                'gopls',
                'ansiblels',
                'bashls',
                'dockerls',
                'jsonls',
                'powershell_es',
                'solargraph',
                'terraformls',
                'lua_ls',
                -- 'sumneko_lua',
                'yamlls'
            })

            lsp.on_attach(function(client, bufnr)
                lsp.default_keymaps({ buffer = bufnr })
            end)

            require('lspconfig').lua_ls.setup(lsp.nvim_lua_ls())

            -- lsp.skip_server_setup({ 'gopls' })
            -- the function below will be executed whenever
            -- a language server is attached to a buffer
            lsp.on_attach(function(client, bufnr)
                local noremap = { buffer = bufnr, remap = false }
                local bind = vim.keymap.set

                bind('n', '<leader>r', '<cmd>lua vim.lsp.buf.rename()<cr>', noremap)
                -- Mappings.
                bind('n', 'gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>', noremap)
                bind('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', noremap)
                bind('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', noremap)
                bind('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', noremap)
                bind('n', 'gt', '<cmd>lua vim.lsp.buf.type_definition()<CR>', noremap)
                bind('n', '<Leader>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', noremap)
                bind('n', '<Leader>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', noremap)
                bind('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', noremap)
                bind('n', '<Leader>dl', '<cmd>Telescope diagnostics<CR>', noremap)
                bind('n', '<Leader>ld', '<cmd>lua vim.diagnostic.open_float()<CR>', noremap)
                bind('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', noremap)
                bind('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', noremap)
                bind('n', '<Leader>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', noremap)
                bind("n", "<Leader>f", "<cmd>lua vim.lsp.buf.format({ async = true })<CR>", noremap)
                -- if client is gopls then define bindings
                if client.name == 'gopls' then
                    bind("n", "<Leader>gtf", "<cmd>GoTestFile<CR>", noremap)
                    bind("n", "<Leader>gtff", "<cmd>GoTestFunc<CR>", noremap)
                    bind("n", "<Leader>gtt", "<cmd>GoTest<CR>", noremap)
                    bind("n", "<Leader>gta", "<cmd>GoTestAll<CR>", noremap)
                end
            end)
            lsp.setup()

            -- cmp icons
            local cmp = require('cmp')
            local lspkind = require('lspkind')
            local icons = require('techdufus.core.icons')
            local luasnip = require('luasnip')
            local cmp_mapping = require('cmp.config.mapping')
            local cmp_types = require('cmp.types.cmp')
            local utils = require('techdufus.core.utils')
            cmp.setup {
                formatting = {
                    fields = { "kind", "abbr", "menu" },
                    format = function(entry, vim_item)
                        local max_width = 0
                        if max_width ~= 0 and #vim_item.abbr > max_width then
                            vim_item.abbr = string.sub(vim_item.abbr, 1, max_width - 1) .. icons.ui.Ellipsis
                        end
                        vim_item.kind = lspkind.presets.default[vim_item.kind] .. " " .. vim_item.kind

                        if entry.source.name == "copilot" then
                            vim_item.kind = icons.git.Octoface
                            vim_item.kind_hl_group = "CmpItemKindCopilot"
                        end

                        if entry.source.name == "crates" then
                            vim_item.kind = icons.misc.Package
                            vim_item.kind_hl_group = "CmpItemKindCrate"
                        end

                        if entry.source.name == "emoji" then
                            vim_item.kind = icons.misc.Smiley
                            vim_item.kind_hl_group = "CmpItemKindEmoji"
                        end
                        vim_item.menu = ({
                            vsnip = "(Snippet)",
                            copilot = "(Copilot)",
                            nvim_lsp = "[LSP]",
                            luasnip = "[LuaSnip]",
                            buffer = "[Buffer]",
                            nvim_lua = "[Lua]",
                            path = "[Path]",
                            calc = "[Calc]",
                            emoji = "[Emoji]",
                            treesitter = "[Treesitter]",
                            tmux = "[Tmux]",
                            crates = "[Crates]",
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
                sources = {
                    {
                        name = "copilot",
                        -- keyword_length = 0,
                        max_item_count = 3,
                        trigger_characters = {
                            {
                                ".",
                                ":",
                                "(",
                                "'",
                                '"',
                                "[",
                                ",",
                                "#",
                                "*",
                                "@",
                                "|",
                                "=",
                                "-",
                                "{",
                                "/",
                                "\\",
                                "+",
                                "?",
                                " ",
                                "*",
                                "!",
                                "<",
                                ">",
                                -- "\t",
                                -- "\n",
                            },
                        },
                    },
                    {
                        name = "nvim_lsp",
                        entry_filter = function(entry, ctx)
                            local kind = require("cmp.types.lsp").CompletionItemKind[entry:get_kind()]
                            if kind == "Snippet" and ctx.prev_context.filetype == "java" then
                                return false
                            end
                            if kind == "Text" then
                                return false
                            end
                            return true
                        end,
                    },

                    { name = "path" },
                    { name = "luasnip" },
                    { name = "nvim_lua" },
                    { name = "buffer" },
                    { name = "calc" },
                    { name = "emoji" },
                    { name = "treesitter" },
                    { name = "crates" },
                    { name = "tmux" },
                },
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
                    ["<CR>"] = cmp_mapping(function(fallback)
                        if cmp.visible() then
                            local confirm_opts = vim.deepcopy({
                                behavior = cmp_types.ConfirmBehavior.Replace,
                                select = false,
                            }) -- avoid mutating the original opts below
                            local is_insert_mode = function()
                                return vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
                            end
                            if is_insert_mode() then -- prevent overwriting brackets
                                confirm_opts.behavior = cmp_types.ConfirmBehavior.Insert
                            end
                            local entry = cmp.get_selected_entry()
                            local is_copilot = entry and entry.source.name == "copilot"
                            if is_copilot then
                                confirm_opts.behavior = cmp_types.ConfirmBehavior.Replace
                                confirm_opts.select = true
                            end
                            if cmp.confirm(confirm_opts) then
                                return -- success, exit early
                            end
                        end
                        fallback() -- if not exited early, always fallback
                    end),
                },
            }
        end
    },

    -- inlay hints
    {
        'simrat39/inlay-hints.nvim',
        config = function()
            require("inlay-hints").setup({
                only_current_line = false,
                eol = {
                    right_align = false,
                }
            })
        end
    },
    {
        "crispgm/nvim-go",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "rcarriga/nvim-notify",
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
