return {
  'MeanderingProgrammer/render-markdown.nvim',
  lazy = false,
  dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    ft = {
      'markdown'
    },
    render_modes = true,
  },
}
