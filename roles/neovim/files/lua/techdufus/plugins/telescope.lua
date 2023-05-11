return {
    {
        "nvim-telescope/telescope.nvim",
        cmd = 'Telescope',
        version = false,
        lazy = true,
        dependencies = {
            "nvim-lua/plenary.nvim",
            "jvgrootveld/telescope-zoxide",
            "nvim-tree/nvim-web-devicons",
            { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make' },
            'nvim-telescope/telescope-ui-select.nvim',
        },
        config = function()
            local telescope = require("telescope")
            local actions = require("telescope.actions")

            telescope.setup {
                defaults = {
                    theme = 'dropdown',
                    previewer = true,
                    path_display = { "smart" },
                    entry_prefix = "  ",
                    initial_mode = "insert",
                    selection_strategy = "reset",
                    sorting_strategy = "ascending",
                    layout_strategy = "horizontal",
                    border = {},
                    borderchars = nil,
                    layout_config = {
                        width = 0.95,
                        preview_cutoff = 120,
                        prompt_position = "top",
                        horizontal = { mirror = false },
                        vertical = { mirror = false },
                    },
                    vimgrep_arguments = {
                        "rg",
                        "--color=never",
                        "--no-heading",
                        "--with-filename",
                        "--line-number",
                        "--column",
                        "--smart-case",
                        "--hidden",
                        "--glob=!.git/",
                    },
                    mappings = {
                        i = {
                            ["<C-n>"] = actions.cycle_history_next,
                            ["<C-p>"] = actions.cycle_history_prev,
                            ["<C-j>"] = actions.move_selection_next,
                            ["<C-k>"] = actions.move_selection_previous,
                            ["<C-c>"] = actions.close,
                            ["<Down>"] = actions.move_selection_next,
                            ["<Up>"] = actions.move_selection_previous,
                            ["<CR>"] = actions.select_default,
                            ["<C-x>"] = actions.select_horizontal,
                            ["<C-v>"] = actions.select_vertical,
                            ["<C-t>"] = actions.select_tab,
                            ["<C-u>"] = actions.preview_scrolling_up,
                            ["<C-d>"] = actions.preview_scrolling_down,
                            ["<PageUp>"] = actions.results_scrolling_up,
                            ["<PageDown>"] = actions.results_scrolling_down,
                            ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
                            ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
                            ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
                            ["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
                            ["<C-l>"] = actions.complete_tag,
                            ["<C-_>"] = actions.which_key, -- keys from pressing <C-/>
                        },
                        n = {
                            ["<esc>"] = actions.close,
                            ["<CR>"] = actions.select_default,
                            ["<C-x>"] = actions.select_horizontal,
                            ["<C-v>"] = actions.select_vertical,
                            ["<C-t>"] = actions.select_tab,
                            ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
                            ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
                            ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
                            ["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
                            ["j"] = actions.move_selection_next,
                            ["k"] = actions.move_selection_previous,
                            ["H"] = actions.move_to_top,
                            ["M"] = actions.move_to_middle,
                            ["L"] = actions.move_to_bottom,
                            ["<Down>"] = actions.move_selection_next,
                            ["<Up>"] = actions.move_selection_previous,
                            ["gg"] = actions.move_to_top,
                            ["G"] = actions.move_to_bottom,
                            ["<C-u>"] = actions.preview_scrolling_up,
                            ["<C-d>"] = actions.preview_scrolling_down,
                            ["<PageUp>"] = actions.results_scrolling_up,
                            ["<PageDown>"] = actions.results_scrolling_down,
                            ["?"] = actions.which_key,
                        },
                    },
                },
                file_ignore_patterns = {},
                path_display = { shorten = 5 },
                winblend = 0,
                set_env = { ["COLORTERM"] = "truecolor" }, -- default = nil,
                pickers = {
                    find_files = {
                        hidden = true,
                        previewer = false,
                        layout_config = {
                            horizontal = {
                                width = 0.5,
                                height = 0.4,
                                preview_width = 0.6,
                            },
                        },
                    },
                    git_files = {
                        hidden = true,
                        previewer = false,
                        layout_config = {
                            horizontal = {
                                width = 0.5,
                                height = 0.4,
                                preview_width = 0.6,
                            },
                        },
                    },
                    live_grep = {
                        --@usage don't include the filename in the search results
                        only_sort_text = true,
                        previewer = true,
                        layout_config = {
                            horizontal = {
                                width = 0.9,
                                height = 0.75,
                                preview_width = 0.6,
                            },
                        },
                    },
                    grep_string = {
                        --@usage don't include the filename in the search results
                        only_sort_text = true,
                        previewer = true,
                        layout_config = {
                            horizontal = {
                                width = 0.9,
                                height = 0.75,
                                preview_width = 0.6,
                            },
                        },
                    },
                    buffers = {
                        -- initial_mode = "normal",
                        previewer = false,
                        layout_config = {
                            horizontal = {
                                width = 0.5,
                                height = 0.4,
                                preview_width = 0.6,
                            },
                        },
                    },
                    lsp_reference = {
                        show_line = false,
                        layout_config = {
                            horizontal = {
                                width = 0.9,
                                height = 0.75,
                                preview_width = 0.6,
                            },
                        },
                    },
                    treesitter = {
                        show_line = false,
                        sorting_strategy = nil,
                        layout_config = {
                            horizontal = {
                                width = 0.9,
                                height = 0.75,
                                preview_width = 0.6,
                            },
                        },
                        symbols = {
                            "class", "function", "method", "type", "conts",
                            "property", "struct", "field", "constructor",
                            "variable", "interface", "module"
                        }
                    },
                },
                extensions = {
                    fzf = {
                        fuzzy = true,               -- false will only do exact matching
                        override_generic_sorter = true, -- override the generic sorter
                        override_file_sorter = true, -- override the file sorter
                        case_mode = "smart_case",   -- or "ignore_case" or "respect_case"
                    },
                    ["ui-select"] = {
                        require("telescope.themes").get_dropdown({
                            previewer = false,
                            initial_mode = "normal",
                            sorting_strategy = "ascending",
                            layout_strategy = "horizontal",
                            layout_config = {
                                horizontal = {
                                    width = 0.5,
                                    height = 0.4,
                                    preview_width = 0.6,
                                },
                            },
                        })
                    },
                },
            }
            local M = {}

            M.project_files = function()
                local opts = {}
                local ok = pcall(require "telescope.builtin".git_files, opts)
                if not ok then require "telescope.builtin".find_files(opts) end
            end

            return M
        end
    }
}
