return {
    'kyazdani42/nvim-tree.lua',
    dependencies = {
        'kyazdani42/nvim-web-devicons',
    },
    config = function()
        -- empty setup using defaults
        require("nvim-tree").setup {
            view = {
                side = "left",
                width = 35,
            },
            renderer = {
                icons = {
                    glyphs = {
                        folder = {
                            arrow_open = "",
                            arrow_closed = "",
                        },
                    },
                },
            },
        }
        local function open_nvim_tree()
            require("nvim-tree.api").tree.open()
        end

        vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })
    end,
}
