return {
  -- Quickly switch between angular files faster
  enabled = false,
  "softoika/ngswitcher.vim",
  keys = {
    { "<leader>at", "<cmd>NgSwitchTS<CR>", desc = "[ANGULAR] Go to TypeScript file" },
    { "<leader>ah", "<cmd>NgSwitchHTML<CR>", desc = "[ANGULAR] Go to HTML file" },
    { "<leader>ac", "<cmd>NgSwitchCSS<CR>", desc = "[ANGULAR] Go to CSS file" },
    { "<leader>as", "<cmd>NgSwitchSpec<CR>", desc = "[ANGULAR] Go to .spec.ts file" },
  },
}
