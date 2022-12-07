vim.cmd [[

  augroup _jenkins
    autocmd!
    autocmd BufRead,BufNewFile Jenkinsfile setf groovy
  augroup END

  ]]
vim.api.nvim_create_augroup('bufcheck', { clear = true })
vim.cmd 'autocmd BufRead,BufNewFile *.yml set filetype=yaml.ansible'
-- reload config file on change
vim.api.nvim_create_autocmd('BufWritePost', {
  group   = 'bufcheck',
  pattern = vim.env.MYVIMRC,
  command = 'silent source %'
})
