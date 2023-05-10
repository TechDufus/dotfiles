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
    "nvim-lua/popup.nvim",   -- An implementation of the Popup API from vim in Neovim
    "nvim-lua/plenary.nvim", -- Useful lua functions used ny lots of plugins
    'simrat39/symbols-outline.nvim',
    "ThePrimeagen/harpoon",
    { "windwp/nvim-ts-autotag",  dependencies = "nvim-treesitter" },
    "neovim/nvim-lspconfig",
    ({ "mfussenegger/nvim-dap", dependencies = { "rcarriga/nvim-dap-ui" } }),
    "leoluz/nvim-dap-go",
    "sharkdp/fd",
    {
        'lewis6991/gitsigns.nvim',
        config = function()
            require('gitsigns').setup()
        end
    },
    {
        'noib3/nvim-cokeline',
        dependencies = 'nvim-tree/nvim-web-devicons', -- If you want devicons
        config = function()
            require('cokeline').setup()
        end
    },
    'crispgm/nvim-go',
    'erikzaadi/vim-ansible-yaml',
    {
        "jackMort/ChatGPT.nvim",
        event = "VeryLazy",
        config = function()
            require("chatgpt").setup()
        end,
        dependencies = {
            "MunifTanjim/nui.nvim",
            "nvim-lua/plenary.nvim",
            "nvim-telescope/telescope.nvim"
        }
    },
}
