return {
  "rcarriga/nvim-dap-ui",
  opts = {
    layouts = {
      {
        elements = {
          {
            id = "scopes",
            size = 0.45,
          },
          {
            id = "breakpoints",
            size = 0.25,
          },
          {
            id = "stacks",
            size = 0.25,
          },
          {
            id = "watches",
            size = 0.05,
          },
        },
        position = "right",
        size = 80,
      },
      {
        elements = {
          {
            id = "repl",
            size = 0.05,
          },
          {
            id = "console",
            size = 0.95,
          },
        },
        position = "bottom",
        size = 20,
      },
    },
  },
}
