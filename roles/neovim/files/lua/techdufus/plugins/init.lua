-- require('techdufus.plugins.terminal')
-- require("techdufus.plugins.web-devicons")
-- require('techdufus.plugins.comment')
-- require('techdufus.plugins.telescope')
-- require('techdufus.plugins.harpoon')
-- require('techdufus.plugins.autopairs')
-- require('techdufus.plugins.statusline')
-- require('techdufus.plugins.nvim-tree')
-- require('techdufus.plugins.nvim-lightbulb')
-- require('techdufus.plugins.toggleterm')
-- require('techdufus.plugins.filetype')
-- require("techdufus.plugins.color_scheme")
-- require("techdufus.plugins.notify")
-- require("techdufus.plugins.symbols-outline")
-- require("techdufus.plugins.treesitter")
-- require("techdufus.plugins.treesitter-context")
-- require("techdufus.plugins.undotree")
return {
    "nvim-lua/popup.nvim", -- An implementation of the Popup API from vim in Neovim
    "nvim-lua/plenary.nvim", -- Useful lua functions used ny lots of plugins
    "nvim-telescope/telescope-media-files.nvim",
    'simrat39/symbols-outline.nvim',
    "ThePrimeagen/harpoon",
    { "windwp/nvim-ts-autotag", dependencies = "nvim-treesitter" },
    { "catppuccin/nvim", name = "catppuccin" },
    -- { "navarasu/onedark.nvim" },
    "neovim/nvim-lspconfig",
    ({ "mfussenegger/nvim-dap", dependencies = { "rcarriga/nvim-dap-ui" } }),
    "andweeb/presence.nvim",
    "leoluz/nvim-dap-go",
    "sharkdp/fd",
    "numToStr/Comment.nvim",
    {
        'lewis6991/gitsigns.nvim',
        config = function()
            require('gitsigns').setup()
        end
    },
    -- {
    --     'feline-nvim/feline.nvim',
    --     config = function()
    --         require('feline').setup()
    --     end
    -- },
    {
        'noib3/nvim-cokeline',
        dependencies = 'kyazdani42/nvim-web-devicons', -- If you want devicons
        config = function()
            require('cokeline').setup()
        end
    },
    { 'kyazdani42/nvim-tree.lua', dependencies = { 'kyazdani42/nvim-web-devicons' } },
    'crispgm/nvim-go',
    'nathom/filetype.nvim',
    'erikzaadi/vim-ansible-yaml',
    {
        'VonHeikemen/lsp-zero.nvim',
        dependencies = {
            -- LSP Support
            'neovim/nvim-lspconfig',
            'williamboman/mason.nvim',
            'williamboman/mason-lspconfig.nvim',

            -- Autocompletion
            'hrsh7th/nvim-cmp',
            'hrsh7th/cmp-buffer',
            'hrsh7th/cmp-path',
            'saadparwaiz1/cmp_luasnip',
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-nvim-lua',

            -- Snippets
            'L3MON4D3/LuaSnip',
            'rafamadriz/friendly-snippets',
        }
    },
    {
        'zbirenbaum/copilot.lua',
        event = 'VimEnter',
        config = function()
            vim.defer_fn(function()
                require('copilot').setup({
                    filetypes = {
                        ['*'] = true,
                    }
                })
            end, 100)
        end,
    },
    {
        "danymat/neogen",
        config = function()
            require('neogen').setup {}
        end,
        dependencies = "nvim-treesitter/nvim-treesitter",
    },
    -- "rcarriga/nvim-notify", -- pretty notifications
    {
        'zbirenbaum/copilot-cmp',
        dependencies = { 'copilot.lua' },
        config = function()
            require('copilot_cmp').setup()
        end
    },
    'ThePrimeagen/vim-be-good',
    {
        'kosayoda/nvim-lightbulb',
        dependencies = 'antoinemadec/FixCursorHold.nvim',
    },
    {
        'uloco/bluloco.nvim',
        dependencies = 'rktjmp/lush.nvim'
    },
}
