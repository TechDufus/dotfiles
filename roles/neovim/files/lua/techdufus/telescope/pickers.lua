
local M = {}
local builtin = require('telescope.builtin')

M.project_files = function()
  builtin.find_files({
    prompt_title = 'Project Files',
    find_command = {
      'rg',
      '--files',
      '--hidden',
      '-g',
      '!.git'
    }
  })
end


M.dotfiles = function()
  builtin.find_files({
    prompt_title = 'Dotfiles',
    find_command = {
      'rg',
      '--files',
      '--hidden',
      '-g',
      '!.git'
    },
    cwd = '~/.dotfiles'
  })
end

M.project_history = function()
  builtin.oldfiles({
    prompt_title = 'Project History',
    cwd_only = true,
  })
end



return M
