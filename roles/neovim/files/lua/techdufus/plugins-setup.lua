local fn = vim.fn

-- Automatically install packer
local install_path = fn.stdpath "data" .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
    PACKER_BOOTSTRAP = fn.system {
        "git",
        "clone",
        "--depth",
        "1",
        "https://github.com/wbthomason/packer.nvim",
        install_path,
    }
    print "Installing packer close and reopen Neovim..."
    vim.cmd [[packadd packer.nvim]]
end

-- Autocommand that reloads neovim whenever you save the plugins-setup.lua file
vim.cmd [[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins-setup.lua source <afile> | PackerSync
  augroup end
]]

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
    return
end

-- Have packer use a popup window
packer.init {
    display = {
        open_fn = function()
            return require("packer.util").float { border = "rounded" }
        end,
    },
}

-- Install your plugins here
return packer.startup(function(use)
    -- My plugins here
    use "wbthomason/packer.nvim" -- Have packer manage itself
    use "nvim-lua/popup.nvim" -- An implementation of the Popup API from vim in Neovim
    use "nvim-lua/plenary.nvim" -- Useful lua functions used ny lots of plugins
    use "nvim-telescope/telescope.nvim"
    use "nvim-telescope/telescope-media-files.nvim"
    use 'simrat39/symbols-outline.nvim'
    use "ThePrimeagen/harpoon"
    use "windwp/nvim-autopairs"
    use({ "windwp/nvim-ts-autotag", after = "nvim-treesitter" })
    -- use "gruvbox-community/gruvbox"
    -- use "github/copilot.vim"
    use { "nvim-treesitter/nvim-treesitter", run = ":TSUpdate" }
    use { 'nvim-treesitter/nvim-treesitter-context' }
    use { "catppuccin/nvim", as = "catppuccin" }
    use { "navarasu/onedark.nvim" }
    use "neovim/nvim-lspconfig"
    use({ "mfussenegger/nvim-dap", requires = { "rcarriga/nvim-dap-ui" } })
    use("andweeb/presence.nvim")
    use "leoluz/nvim-dap-go"
    use "sharkdp/fd"
    use "kyazdani42/nvim-web-devicons"
    use "ryanoasis/vim-devicons"
    use "numToStr/Comment.nvim"
    use {
        'lewis6991/gitsigns.nvim',
        config = function()
            require('gitsigns').setup()
        end
    }
    use 'mbbill/undotree'
    use {
        'feline-nvim/feline.nvim',
        config = function()
            require('feline').setup()
        end
    }
    use 's1n7ax/nvim-terminal'
    use {
        'noib3/nvim-cokeline',
        requires = 'kyazdani42/nvim-web-devicons', -- If you want devicons
        config = function()
            require('cokeline').setup()
        end
    }
    use { 'kyazdani42/nvim-tree.lua', requires = { 'kyazdani42/nvim-web-devicons' } }
    use 'akinsho/toggleterm.nvim'
    use 'crispgm/nvim-go'
    use 'nathom/filetype.nvim'
    use 'erikzaadi/vim-ansible-yaml'
    use {
        'VonHeikemen/lsp-zero.nvim',
        requires = {
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
    }
    use {
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
    }
    use {
        "danymat/neogen",
        config = function()
            require('neogen').setup {}
        end,
        requires = "nvim-treesitter/nvim-treesitter",
    }
    use({ "rcarriga/nvim-notify" }) -- pretty notifications
    use {
        'zbirenbaum/copilot-cmp',
        after = { 'copilot.lua' },
        config = function()
            require('copilot_cmp').setup()
        end
    }
    use 'ThePrimeagen/vim-be-good'
    use {
        'kosayoda/nvim-lightbulb',
        requires = 'antoinemadec/FixCursorHold.nvim',
    }
    -- Automatically set up your configuration after cloning packer.nvim
    -- Put this at the end after all plugins
    if PACKER_BOOTSTRAP then
        require("packer").sync()
    end
end)
