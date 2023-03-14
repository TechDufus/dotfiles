return {
    'feline-nvim/feline.nvim',
    config = function()
        require('feline').setup({
            provider = {
                name = 'file_info',
                opts = {
                    type = 'relative'
                }
            }
        })
        require('feline').winbar.setup()
    end
}
