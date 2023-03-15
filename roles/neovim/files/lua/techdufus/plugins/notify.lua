return {
    "rcarriga/nvim-notify", -- pretty notifications
    config = function()
        require("notify").setup {
            stages = 'fade_in_slide_out',
            background_colour = 'FloatShadow',
            timeout = 3000,
        }
        vim.notify = require("notify")
    end
}
