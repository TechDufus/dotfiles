return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
        require 'nvim-treesitter.configs'.setup {
            -- A list of parser names, or "all"
            ensure_installed = "all",
            -- Install parsers synchronously (only applied to `ensure_installed`)
            sync_install = true,
            -- Automatically install missing parsers when entering buffer
            -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
            auto_install = true,
            highlight = {
                -- `false` will disable the whole extension
                enable = true,
                additional_vim_regex_highlighting = false,
            },
        }
    end
}
