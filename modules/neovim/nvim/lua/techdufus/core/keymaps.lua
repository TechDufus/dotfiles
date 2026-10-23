local insert_mode = "i"
local normal_mode = "n"
local term_mode = "t"
local visual_mode = "v"
local visual_block_mode = "x"
local command_mode = "c"

local opts = { noremap = true, silent = true }
local term_opts = { silent = true }

local keymap = vim.api.nvim_set_keymap

keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Normal --
-- Better window navigation
keymap(normal_mode, "<C-h>", "<C-w>h", opts)
keymap(normal_mode, "<C-j>", "<C-w>j", opts)
keymap(normal_mode, "<C-k>", "<C-w>k", opts)
keymap(normal_mode, "<C-l>", "<C-w>l", opts)

-- Better window navigation (using alt with zellij)
-- keymap(normal_mode, "<A-h>", "<C-w>h", opts)
-- keymap(normal_mode, "<A-j>", "<C-w>j", opts)
-- keymap(normal_mode, "<A-k>", "<C-w>k", opts)
-- keymap(normal_mode, "<A-l>", "<C-w>l", opts)

-- keymap(normal_mode, ";", ":", opts)

keymap(normal_mode, "<left>",  ":echohl WarningMsg<Bar>echo 'USE h you SWINE!'<Bar>echohl None<CR>", opts)
keymap(normal_mode, "<right>", ":echohl WarningMsg<Bar>echo 'USE l you SWINE!'<Bar>echohl None<CR>", opts)
keymap(normal_mode, "<up>",    ":echohl WarningMsg<Bar>echo 'USE k you SWINE!'<Bar>echohl None<CR>", opts)
keymap(normal_mode, "<down>",  ":echohl WarningMsg<Bar>echo 'USE j you SWINE!'<Bar>echohl None<CR>", opts)
keymap(insert_mode, "<left>",  "<C-o>:echohl WarningMsg<Bar>echo 'USE h you SWINE!'<Bar>echohl None<CR>", opts)
keymap(insert_mode, "<right>", "<C-o>:echohl WarningMsg<Bar>echo 'USE l you SWINE!'<Bar>echohl None<CR>", opts)
keymap(insert_mode, "<up>", "<C-o>:echohl WarningMsg<Bar>echo 'USE k you SWINE!'<Bar>echohl None<CR>", opts)
keymap(insert_mode, "<down>", "<C-o>:echohl WarningMsg<Bar>echo 'USE j you SWINE!'<Bar>echohl None<CR>", opts)

-- Better indenting
keymap(normal_mode, "<leader>ft", "gg=G<C-o>", opts)

-- JSON File Formatting --
keymap(normal_mode, "<leader>fj", ":%!jq .<CR>", opts)


-- keymap(normal_mode, "<leader>b", ":Telescope buffers<cr>", opts)
-- Unhilight search --
keymap(normal_mode, "<leader>chl", ":nohl<cr>", opts)

-- Insert blank line above and below current line
keymap(normal_mode, "<leader>o", "m`o<Esc>``", opts)
keymap(normal_mode, "<leader>O", "m`O<Esc>``", opts)

-- Resize with arrows
keymap(normal_mode, "<C-Up>", ":resize -2<CR>", opts)
keymap(normal_mode, "<C-Down>", ":resize +2<CR>", opts)
keymap(normal_mode, "<C-Left>", ":vertical resize -2<CR>", opts)
keymap(normal_mode, "<C-Right>", ":vertical resize +2<CR>", opts)

-- Navigate buffers
keymap(normal_mode, "<S-l>", ":bnext<CR>", opts)
keymap(normal_mode, "<S-h>", ":bprevious<CR>", opts)

-- Toggle Word Wrap --
keymap(normal_mode, "<leader>tw", ":set wrap!<CR>", opts)

-- Visual --
-- Stay in indent mode
keymap(visual_mode, "<", "<gv", opts)
keymap(visual_mode, ">", ">gv", opts)

-- Visual search --
keymap(visual_mode, "//", 'y/<C-R>"<CR>', opts)

-- Move text up and down
keymap(visual_mode, "J", ":m '>+1<CR>gv=gv", opts)
keymap(visual_mode, "V", ":m '>-2<CR>gv=gv", opts)
-- keymap(visual_mode, "<A-j>", ":m .+1<CR>==", opts)
-- keymap(visual_mode, "<A-k>", ":m .-2<CR>==", opts)
keymap(visual_mode, "p", '"_dP', opts)

-- keep cursor in place when appending below line to current line
keymap(normal_mode, "J", "mzJ`z", opts)

-- Keep search term in the middle
keymap(normal_mode, "n", "nzzzv", opts)
keymap(normal_mode, "N", "Nzzzv", opts)

-- Keep current buffer when pasting over text
keymap(normal_mode, "<leader>p", '"_dP', opts)

-- Worst place in the universe
keymap(normal_mode, "Q", "<nop>", opts)

-- Make current file executable
keymap(normal_mode, "<leader>x", ":w !chmod +x %<CR>", opts)

-- Find / Replace Current Word
keymap(normal_mode, "<leader>R", ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gI<left><left><left>", opts)

-- Remap for dealing with word wrap
keymap(normal_mode, "j", "v:count == 0 ? 'gj' : 'j'", { silent = true, expr = true })
keymap(normal_mode, "k", "v:count == 0 ? 'gk' : 'k'", { silent = true, expr = true })

-- Move line up/down
keymap(normal_mode, "<leader>j", "ddp", opts)
keymap(normal_mode, "<leader>k", "ddkP", opts)

-- Better Ctrl u | d
keymap(normal_mode, "<C-u>", "<C-u>zz", opts)
keymap(normal_mode, "<C-d>", "<C-d>zz", opts)

-- MACROS
keymap(normal_mode, "Q", "@qj", opts)
keymap(visual_block_mode, "Q", ":norm @q<CR>gv", opts)


-- Visual Block --
-- Move text up and down
keymap(visual_block_mode, "J", ":move '>+1<CR>gv-gv", opts)
keymap(visual_block_mode, "K", ":move '<-2<CR>gv-gv", opts)
keymap(visual_block_mode, "<A-j>", ":move '>+1<CR>gv-gv", opts)
keymap(visual_block_mode, "<A-k>", ":move '<-2<CR>gv-gv", opts)

-- Terminal --
-- Better terminal navigation
keymap(term_mode, "<C-h>", "<C-\\><C-N><C-w>h", term_opts)
keymap(term_mode, "<C-j>", "<C-\\><C-N><C-w>j", term_opts)
keymap(term_mode, "<C-k>", "<C-\\><C-N><C-w>k", term_opts)
keymap(term_mode, "<C-l>", "<C-\\><C-N><C-w>l", term_opts)

-- Telescope find files in nvim config directory
keymap(normal_mode, "<leader>rc",
    "<cmd>lua require'telescope.builtin'.find_files({cwd = '~/.dotfiles', find_command = {'rg', '--files', '--hidden', '-g', '!.git' }})<cr>"
    , opts)

-- Harpoon --
keymap(normal_mode, "<leader>a", "<cmd>lua require'harpoon.mark'.add_file()<cr>", opts)
keymap(normal_mode, "<leader>e", "<cmd>lua require'harpoon.ui'.toggle_quick_menu()<cr>", opts)
keymap(normal_mode, "<leader>h", "<cmd>lua require'harpoon.ui'.nav_file(1)<cr>", opts)
keymap(normal_mode, "<leader>t", "<cmd>lua require'harpoon.ui'.nav_file(2)<cr>", opts)
keymap(normal_mode, "<leader>n", "<cmd>lua require'harpoon.ui'.nav_file(3)<cr>", opts)
keymap(normal_mode, "<leader>s", "<cmd>lua require'harpoon.ui'.nav_file(4)<cr>", opts)

keymap(normal_mode, "<Leader>gb", ":Gitsigns toggle_current_line_blame<CR>", opts)

-- tmux-navigator --
keymap(normal_mode, "<C-h>", "<cmd>TmuxNavigateLeft<cr>", opts)
keymap(normal_mode, "<C-j>", "<cmd>TmuxNavigateDown<cr>", opts)
keymap(normal_mode, "<C-k>", "<cmd>TmuxNavigateUp<cr>", opts)
keymap(normal_mode, "<C-l>", "<cmd>TmuxNavigateRight<cr>", opts)

-- Copilot --
keymap(normal_mode, "<leader>cpa", "<cmd>Copilot! attach<cr>", opts)

-- reload current file --
keymap(normal_mode, "<leader>r", "<cmd>e!", opts)

--LazyGit--
keymap(normal_mode, "<leader>gg", "<cmd>LazyGit<cr>", opts)
