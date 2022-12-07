if ConfigMode == "rich" then
  require("notify").setup {
    stages = 'fade_in_slide_out',
    background_colour = 'FloatShadow',
    timeout = 3000,
  }
  vim.notify = require("notify")
end
