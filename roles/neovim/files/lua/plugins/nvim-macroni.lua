return {
  'jesseleite/nvim-macroni',
  lazy = false,
  opts = {
    -- All of your `setup(opts)` and saved macros will go here
    macros = {
      make_todo_list_item = {
        macro = '^i-<Space>[<Space>]<Space>',
        keymap = '<Leader>mt',
        mode = { 'n', 'v' },                 -- By default, macros will be mapped to both normal & visual modes
        desc = 'Make a markdown list item!', -- Description for whichkey or similar
      },
      make_simple_function_into_alias = {
        macro = 'vim<Esc>[mdwf(dwdwJA<BS><BS><BS><Esc><Home>ialias<Space><Esc>ea=<Del>\'<End>\'<Esc>Ja<Del><Del><Esc>',
        desc = 'Turn a single-line bash|zsh function into an alias.',
      },
    }
  },
}
