return {
  {
    "rafamadriz/friendly-snippets",
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load({ paths = { "./snippets" } })
    end,
  },
  {
    "L3MON4D3/LuaSnip",
    -- keys = {
    --   {
    --     "<Tab>",
    --     function()
    --       -- Override lazyvim config to use locally_jumpable instead of jumpable,
    --       if vim.snippet.locally_jumpable(1) then
    --         -- vim.schedule(function()
    --         vim.snippet.jump(1)
    --         -- end)
    --         return
    --       end
    --       return "<Tab>"
    --     end,
    --     expr = true,
    --     silent = true,
    --     mode = "i",
    --   },
    -- },
  },
}
