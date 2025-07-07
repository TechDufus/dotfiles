return {
  'kevinhwang91/nvim-ufo',
  dependencies = {
    'kevinhwang91/promise-async',
    {
      "luukvbaal/statuscol.nvim",
      config = function()
        local builtin = require("statuscol.builtin")
        require("statuscol").setup({
          relculright = true,
          segments = {
            { text = { builtin.foldfunc }, click = "v:lua.ScFa" },
            { text = { "%s" }, click = "v:lua.ScSa" },
            { text = { builtin.lnumfunc, " " }, click = "v:lua.ScLa" },
          },
        })
      end,
    },
  },
  event = {'BufReadPost', 'BufNewFile'},
  opts = {
    open_fold_hl_timeout = 150,
    close_fold_kinds_for_ft = {
      default = {'imports', 'comment'},
      json = {'array'},
      c = {'comment', 'region'}
    },
    provider_selector = function(bufnr, filetype, buftype)
      return { 'treesitter', 'indent' }
    end,
    -- Custom fold virtual text handler
    fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
      local newVirtText = {}
      local suffix = (' 󰁂 %d '):format(endLnum - lnum)
      local sufWidth = vim.fn.strdisplaywidth(suffix)
      local targetWidth = width - sufWidth
      local curWidth = 0
      for _, chunk in ipairs(virtText) do
        local chunkText = chunk[1]
        local chunkWidth = vim.fn.strdisplaywidth(chunkText)
        if targetWidth > curWidth + chunkWidth then
          table.insert(newVirtText, chunk)
        else
          chunkText = truncate(chunkText, targetWidth - curWidth)
          local hlGroup = chunk[2]
          table.insert(newVirtText, { chunkText, hlGroup })
          chunkWidth = vim.fn.strdisplaywidth(chunkText)
          -- str width returned from truncate() may less than 2nd argument, need padding
          if curWidth + chunkWidth < targetWidth then
            suffix = suffix .. (' '):rep(targetWidth - curWidth - chunkWidth)
          end
          break
        end
        curWidth = curWidth + chunkWidth
      end
      table.insert(newVirtText, { suffix, 'MoreMsg' })
      return newVirtText
    end,
  },
  config = function(_, opts)
    -- Fold column symbols
    -- UFO respects Neovim's default fillchars, which are:
    -- foldclose: '+' (closed fold)
    -- foldopen: '-' (open fold)  
    -- foldsep: '|' (fold separator)
    -- Let's just improve the basics:
    vim.opt.fillchars:append({
      eob = ' ',
      fold = ' ',
      foldsep = '│',  -- Use a nicer vertical line
    })
    -- Keep the default + and - for foldclose/foldopen as they're reliable
    vim.o.foldcolumn = '1' -- '0' is not bad
    vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
    vim.o.foldlevelstart = 99
    vim.o.foldenable = true

    require('ufo').setup(opts)
    
    -- Using ufo provider need remap `zR` and `zM`
    vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
    vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)
    vim.keymap.set('n', 'zr', require('ufo').openFoldsExceptKinds)
    vim.keymap.set('n', 'zm', require('ufo').closeFoldsWith)
    
    -- Preview fold
    vim.keymap.set('n', 'K', function()
      local winid = require('ufo').peekFoldedLinesUnderCursor()
      if not winid then
        vim.lsp.buf.hover()
      end
    end)
    
    -- Additional fold commands
    vim.keymap.set('n', '<leader>zf', function()
      -- Close all folds then open just enough to see cursor
      require('ufo').closeAllFolds()
      require('ufo').openFoldsExceptKinds()
    end, { desc = "Focus on current fold" })
    
    -- Show fold count
    vim.keymap.set('n', '<leader>zc', function()
      local fold_count = require('ufo').getFolds(0)
      if fold_count and #fold_count > 0 then
        vim.notify("Found " .. #fold_count .. " folds in this buffer", vim.log.levels.INFO)
      else
        vim.notify("No folds found. Check if Treesitter parser is installed for this filetype.", vim.log.levels.WARN)
      end
    end, { desc = "Show fold count" })
  end
}