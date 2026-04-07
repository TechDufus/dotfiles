return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  lazy = false,
  keys = {
    { "n", "<leader>it", ":InspectTree<CR>" },
  },
  dependencies = {
    "nvim-treesitter/nvim-treesitter-textobjects",
  },
  config = function()
    local ts = require("nvim-treesitter")
    ts.setup()

    local group = vim.api.nvim_create_augroup("techdufus_treesitter", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "*",
      callback = function(args)
        if vim.bo[args.buf].buftype ~= "" then
          return
        end

        local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
        if not lang then
          return
        end

        if not pcall(vim.treesitter.start, args.buf) then
          return
        end

        if #vim.api.nvim_get_runtime_file(("queries/%s/indents.scm"):format(lang), true) > 0 then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end
}
