require('feline').setup({
  provider = {
    name = 'file_info',
    opts = {
      type = 'relative'
    }
  }
})
require('feline').winbar.setup()
