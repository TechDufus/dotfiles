return {
    "nvim-lua/popup.nvim",   -- An implementation of the Popup API from vim in Neovim
    "nvim-lua/plenary.nvim", -- Useful lua functions used ny lots of plugins
    'simrat39/symbols-outline.nvim',
    "ThePrimeagen/harpoon",
    { "windwp/nvim-ts-autotag", dependencies = "nvim-treesitter" },
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
        "christoomey/vim-tmux-navigator",
        lazy = false,
    },
    {
        "sbdchd/neoformat",
    },
    {
        'noib3/nvim-cokeline',
        dependencies = 'nvim-tree/nvim-web-devicons', -- If you want devicons
        config = function()
            require('cokeline').setup({
                components = {
                    {
                        text = function(buffer) return ' ' .. buffer.devicon.icon end,
                    },
                    {
                        text = function(buffer) return ' ' .. buffer.filename .. ' ' end,
                    },
                    {
                        text = '',
                        delete_buffer_on_left_click = true,
                    },
                    {
                        text = ' ',
                    }
                },
            })
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
