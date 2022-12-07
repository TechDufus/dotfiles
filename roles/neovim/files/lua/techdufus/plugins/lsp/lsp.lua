require('mason.settings').set({
  ui = {
    border = 'rounded'
  }
})
local cmp = require('cmp')
local lsp = require('lsp-zero')
lsp.preset('recommended')

lsp.setup_nvim_cmp({
  sources = {
    -- This one provides the data from copilot.
    { name = 'copilot' },

    --- These are the default sources for lsp-zero
    { name = 'path' },
    { name = 'nvim_lsp', keyword_length = 3 },
    { name = 'buffer', keyword_length = 3 },
    { name = 'luasnip', keyword_length = 2 },
  },
  window = {
    completion = cmp.config.window.bordered(),
    documentation = cmp.config.window.bordered(),
  },
  mapping = lsp.defaults.cmp_mappings({
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    ['<CR>'] = cmp.mapping.confirm({
      -- documentation says this is important.
      -- I don't know why.
      behavior = cmp.ConfirmBehavior.Replace,
      select = false,
    })
  })
})

-- make sure these servers are installed
lsp.ensure_installed({
  'ansiblels',
  'bashls',
  'yamlls',
  'gopls',
  'dockerls',
  'sumneko_lua',
  'powershell_es'
})

-- share options between serveral servers
local lsp_opts = {
  flags = {
    debounce_text_changes = 150,
  }
}

-- the function below will be executed whenever
-- a language server is attached to a buffer
lsp.on_attach(function(client, bufnr)
  local noremap = { buffer = bufnr, remap = false }
  local bind = vim.keymap.set

  bind('n', '<leader>r', '<cmd>lua vim.lsp.buf.rename()<cr>', noremap)
  -- Mappings.
  bind('n', 'gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>', noremap)
  bind('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', noremap)
  bind('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', noremap)
  bind('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', noremap)
  bind('n', 'gt', '<cmd>lua vim.lsp.buf.type_definition()<CR>', noremap)
  bind('n', '<Leader>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', noremap)
  bind('n', '<Leader>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', noremap)
  bind('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', noremap)
  bind('n', '<Leader>dl', '<cmd>Telescope diagnostics<CR>', noremap)
  bind('n', '<Leader>ld', '<cmd>lua vim.diagnostic.open_float()<CR>', noremap)
  bind('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', noremap)
  bind('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', noremap)
  bind('n', '<Leader>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', noremap)
  bind("n", "<Leader>f", "<cmd>lua vim.lsp.buf.format({ async = true })<CR>", noremap)
  -- if client is gopls then define bindings
  if client.name == 'gopls' then
    bind("n", "<Leader>gtf", "<cmd>GoTestFile<CR>", noremap)
    bind("n", "<Leader>gtff", "<cmd>GoTestFunc<CR>", noremap)
    bind("n", "<Leader>gtt", "<cmd>GoTest<CR>", noremap)
    bind("n", "<Leader>gta", "<cmd>GoTestAll<CR>", noremap)
  end
end)

-- big boi
lsp.setup()
