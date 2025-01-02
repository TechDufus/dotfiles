return {
    'nathom/filetype.nvim',
    opts = {
        overrides = {
            extensions = {
                tfvars = "terraform",
                tf = "terraform",
                tfstate = "json",
                tfstate_backup = "json",
                tfplan = "json",
                sh = "sh",
                html = "html",
                bashrc = "sh",
                zsh = "sh",
                yml = "ansible",
                justfile = "just",
            },
        },
    },
}
