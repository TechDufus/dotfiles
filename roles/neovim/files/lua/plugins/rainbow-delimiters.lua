return {
  "HiPhish/rainbow-delimiters.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("rainbow-delimiters.setup").setup({
      condition = function(bufnr)
        -- Skip synthetic buffers that advertise a filetype but have no parser,
        -- such as mini.files' `minifiles` buffers.
        local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
        return ok and parser ~= nil
      end,
    })
  end,
}
