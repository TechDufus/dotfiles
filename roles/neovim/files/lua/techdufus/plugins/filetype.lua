require("filetype").setup({
  overrides = {
    extensions = {
      tfvars = "tf",
      tfstate = "json",
      tfstate_backup = "json",
      tfplan = "json",
      sh = "bash",
    },
  },
})
