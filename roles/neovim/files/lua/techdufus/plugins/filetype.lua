return {
    'nathom/filetype.nvim',
    config = {
        overrides = {
            extensions = {
                tfvars = "terraform",
                tfstate = "json",
                tfstate_backup = "json",
                tfplan = "json",
                sh = "bash",
            },
        },
    },
}
