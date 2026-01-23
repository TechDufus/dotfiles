-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Stop comment continuation
-- https://github.com/LazyVim/LazyVim/issues/80#issuecomment-1478662212
vim.api.nvim_create_autocmd("FileType", {
  command = "set formatoptions-=cro",
})

-- Adds highlighting to Jenkinsfile
vim.api.nvim_create_autocmd("BufReadPre", {
  pattern = "Jenkinsfile",
  command = "setfiletype groovy",
})

vim.api.nvim_create_user_command("W", function()
  -- Temporarily disable autoformat
  vim.b.autoformat = false
  vim.cmd("w")
  -- Re-enable after save
  vim.defer_fn(function()
    vim.b.autoformat = true
  end, 100)
end, {})

-- Open dashboard when no buffers remain
vim.api.nvim_create_autocmd("BufDelete", {
  group = vim.api.nvim_create_augroup("DashboardOnEmpty", { clear = true }),
  callback = function()
    vim.schedule(function()
      -- Filter for valid and listed buffers with names
      local bufs = vim.tbl_filter(function(buf)
        return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and vim.api.nvim_buf_get_name(buf) ~= ""
      end, vim.api.nvim_list_bufs())

      -- Open the snacks.dashboard if no buffers remain
      if #bufs == 0 then
        ---@diagnostic disable-next-line: missing-fields
        require("snacks.dashboard").open({
          win = vim.api.nvim_get_current_win(),
        })
      end
    end)
  end,
})

-- local Format = vim.api.nvim_create_augroup("Format", { clear = true })
-- vim.api.nvim_create_autocmd("BufWritePre", {
-- group = Format,
-- pattern = "*.tsx,*.ts,*.jsx,*.js",
-- callback = function()
-- if vim.fn.exists(":TypescriptFixAll") then
-- vim.cmd("TypescriptFixAll!")
-- vim.cmd("TypescriptRemoveUnused!")
-- vim.cmd("TypescriptOrganizeImports!")
-- end
-- end,
-- })

-- Auto organize import on save
-- vim.api.nvim_create_autocmd("BufWritePre", {
--   pattern = "*.ts",
--   callback = function()
--     vim.lsp.buf.code_action({
--       apply = true,
--       context = {
--         only = { "source.organizeImports.ts" },
--         diagnostics = {},
--       },
--     })
--     vim.lsp.buf.code_action({
--       apply = true,
--       context = {
--         only = { "source.removeUnused.ts" },
--         diagnostics = {},
--       },
--     })
--   end,
-- })

-- Neogit
vim.api.nvim_create_user_command("DiffviewToggle", function()
  local view = require("diffview.lib").get_current_view()
  if view then
    vim.cmd("DiffviewClose")
  else
    require("telescope.builtin").git_commits({
      previewer = require("telescope.previewers").new_termopen_previewer({
        get_command = function(entry)
          local hash = entry.value
          return { "git", "log", "--name-status", "-n1", hash }
        end,
      }),
      attach_mappings = function(_, map)
        map({ "n", "i" }, "<cr>", function(prompt_bufnr)
          local entry = require("telescope.actions.state").get_selected_entry()
          require("telescope.actions").close(prompt_bufnr)
          vim.cmd("DiffviewOpen " .. entry.value)
        end)
        return true
      end,
    })
  end
end, { desc = "", nargs = "*" })
