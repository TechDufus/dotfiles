return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      eslint = {
        flags = {
          -- Speed up eslint
          allow_incremental_sync = false,
          debounce_text_changes = 1000,
        },
      },
    },
  },
}
