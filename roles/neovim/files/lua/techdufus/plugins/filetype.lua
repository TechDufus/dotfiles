require("filetype").setup({
  overrides = {
    extensions = {
      tfvars = "terraform",
      tfstate = "json",
      tfstate_backup = "json",
      tfplan = "json",
      sh = "bash",
    },
  },
})
