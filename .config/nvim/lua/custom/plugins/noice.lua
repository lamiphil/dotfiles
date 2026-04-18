-- Replaces the UI for messages, cmdline and the popupmenu
-- NOTE: This may overlap with kickstart's fidget.nvim for LSP progress.
--       They can coexist, or you can disable fidget if noice covers your needs.
return {
  'folke/noice.nvim',
  event = 'VeryLazy',
  opts = {
    -- Show notification when recording macro
    routes = {
      {
        view = 'notify',
        filter = { event = 'msg_showmode' },
      },
    },
  },
  dependencies = {
    'MunifTanjim/nui.nvim',
    'rcarriga/nvim-notify',
  },
  keys = {
    { '<leader>nd', '<cmd>NoiceDismiss<CR>', desc = 'Dismiss Noice Message' },
  },
}
