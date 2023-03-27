return {
    "ThePrimeagen/harpoon",
    config = function()
        require("harpoon").setup {
            menu = {
                width = vim.api.nvim_win_get_width(0) - 20,
            }
        }
    end
}
