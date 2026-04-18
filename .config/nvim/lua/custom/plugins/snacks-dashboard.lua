-- Startup dashboard using snacks.nvim
-- snacks.nvim is already installed as a dependency of opencode.nvim.
-- This spec merges with the existing one to enable the dashboard module.
return {
  'folke/snacks.nvim',
  lazy = false,
  priority = 1000,
  opts = {
    dashboard = {
      enabled = true,
      width = 60,
      -- Sections displayed top to bottom on the start screen
      sections = {
        -- ASCII art header
        {
          align = 'center',
          text = {
            { [[   __    ___   __  _______  ]], hl = 'SnacksDashboardHeader' },
            { '\n' },
            { [[  / /   /   | /  |/  /  _/  ]], hl = 'SnacksDashboardHeader' },
            { '\n' },
            { [[ / /   / /| |/ /|_/ // /    ]], hl = 'SnacksDashboardHeader' },
            { '\n' },
            { [[/ /___/ ___ / /  / _/ /     ]], hl = 'SnacksDashboardHeader' },
            { '\n' },
            { [[\____/_/  |_/_/  /_/___/    ]], hl = 'SnacksDashboardHeader' },
            { '\n' },
          },
          padding = 2,
        },

        -- Quick action buttons
        { title = 'Actions', padding = 1 },
        { section = 'keys', gap = 1, padding = 1 },

        -- Recent projects (detected via .git directories)
        { title = 'Projects', padding = 1 },
        { section = 'projects', padding = 1 },

        -- Recent files
        { title = 'Recent Files', padding = 1 },
        { section = 'recent_files', padding = 1 },

        -- Startup time
        { section = 'startup' },
      },
      -- Keyboard shortcuts shown as action buttons
      preset = {
        keys = {
          { icon = ' ', key = 'f', desc = 'Find File', action = ':Telescope find_files hidden=true' },
          { icon = ' ', key = 'n', desc = 'New File', action = ':ene | startinsert' },
          { icon = ' ', key = 'g', desc = 'Find Text', action = ':lua Snacks.dashboard.pick("live_grep")' },
          { icon = ' ', key = 'r', desc = 'Recent Files', action = ':lua Snacks.dashboard.pick("oldfiles")' },
          { icon = ' ', key = 'c', desc = 'Config', action = ':lua require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config"), hidden = true })' },
          { icon = ' ', key = 'G', desc = 'LazyGit', action = ':LazyGit' },
          { icon = '󰒲 ', key = 'l', desc = 'Lazy', action = ':Lazy' },
          { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
        },
      },
    },
  },
}
