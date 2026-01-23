-- Custom filetype detection using native vim.filetype.add()
-- Replaces deprecated nathom/filetype.nvim with Neovim's native Lua filetype detection

vim.filetype.add({
  extension = {
    tfvars = "terraform",
    tf = "terraform",
    tfstate = "json",
    tfstate_backup = "json",
    tfplan = "json",
  },
  filename = {
    [".bashrc"] = "sh",
    [".justfile"] = "just",
    ["justfile"] = "just",
    ["Justfile"] = "just",
  },
})

-- Return empty table since this is now just a config file, not a plugin
return {}
