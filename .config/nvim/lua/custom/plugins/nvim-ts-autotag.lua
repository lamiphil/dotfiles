-- Automatically close and rename HTML/JSX tags using treesitter
return {
  'windwp/nvim-ts-autotag',
  ft = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
  config = function() require('nvim-ts-autotag').setup() end,
}
