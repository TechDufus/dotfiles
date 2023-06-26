-- TODO

-- references:
-- https://github.com/nvim-neo-tree/neo-tree.nvim
-- https://github.com/nvim-neo-tree/neo-tree.nvim/wiki/Recipes
return {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
    },
    event = "VeryLazy",
    keys = {
        { "<leader>w", ":Neotree focus<CR>", silent = true, desc = "File Explorer" },
    },
    config = function()
        local icons = require('techdufus.core.icons')
        require("neo-tree").setup({
            close_if_last_window = false,
            popup_border_style = "single",
            enable_git_status = true,
            enable_modified_markers = true,
            enable_diagnostics = false,
            sort_case_insensitive = true,
            default_component_configs = {
                indent = {
                    with_markers = true,
                    with_expanders = true,
                },
                -- modified = {
                --     symbol = "",
                --     highlight = "NeoTreeModified",
                -- },
                -- icon = {
                --     folder_closed = icons.documents.Folder,
                --     folder_open = icons.documents.FolderOpen,
                --     folder_empty = "",
                --     folder_empty_open = "",
                -- },
                git_status = {
                    symbols = {
                        -- Change type
                        added = icons.git.added,
                        deleted = icons.git.deleted,
                        modified = icons.git.modified,
                        renamed = icons.git.renamed,
                        -- Status type
                        untracked = icons.git.untracked,
                        ignored = icons.git.ignored,
                        unstaged = icons.git.Unstaged,
                        staged = icons.git.staged,
                        conflict = icons.git.conflict,
                    },
                },
            },
            window = {
                position = "left",
                width = 35,
                mappings = {
                    ["<Backspace>"] = {
                        "close_node",
                        nowait = true, -- disable `nowait` if you have existing combos starting with this char that you want to use
                    }
                }
            },
            filesystem = {
                use_libuv_file_watcher = true,
                filtered_items = {
                    visable = true,
                    hide_dotfiles = false,
                    hide_gitignored = false,
                    hide_by_name = {
                        "node_modules",
                    },
                    never_show = {
                        ".DS_Store",
                        "thumbs.db",
                    },
                },
            },
            buffers = {
                follow_current_file = true,
            },
            event_handlers = {
                {
                    event = "neo_tree_window_after_open",
                    handler = function(args)
                        if args.position == "left" or args.position == "right" then
                            vim.cmd("wincmd =")
                        end
                    end,
                },
                {
                    event = "neo_tree_window_after_close",
                    handler = function(args)
                        if args.position == "left" or args.position == "right" then
                            vim.cmd("wincmd =")
                        end
                    end,
                },
            },
        })
    end,
}
