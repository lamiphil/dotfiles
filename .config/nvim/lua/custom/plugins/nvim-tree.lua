-- File tree sidebar
---@type LazySpec
return {
  'nvim-tree/nvim-tree.lua',
  cmd = { 'NvimTreeToggle', 'NvimTreeFocus' },
  keys = {
    {
      '<leader>tt',
      '<cmd>NvimTreeToggle<CR>',
      desc = 'Toggle file tree',
    },
  },
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },
  init = function()
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
  end,
  opts = {
    update_focused_file = {
      enable = true,
      update_root = false,
    },
    view = {
      width = 35,
    },
    renderer = {
      group_empty = true,
    },
    filters = {
      dotfiles = false,
    },
  },
}
