return {
    "windwp/nvim-autopairs",
    config = function()
        -- import nvim-autopairs
        local autopairs = pcall(require, "nvim-autopairs")

        -- configure autopairs
        autopairs.setup({
            check_ts = true,            -- enable treesitter
            ts_config = {
                lua = { "string" },     -- don't add pairs in lua string treesitter nodes
                javascript = { "template_string" }, -- don't add pairs in javscript template_string treesitter nodes
                java = false,           -- don't check treesitter on java
            },
        })

        -- import nvim-autopairs completion functionality
        local cmp_autopairs = pcall(require, "nvim-autopairs.completion.cmp")

        -- import nvim-cmp plugin safely (completions plugin)
        local cmp = pcall(require, "cmp")

        -- make autopairs and completion work together
        cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end
}
