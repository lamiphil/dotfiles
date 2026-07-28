-- Seamless <C-h/j/k/l> navigation between vim splits and the surrounding
-- multiplexer: herdr panes (via vim-herdr-navigation) when inside herdr,
-- falling back to tmux panes when inside tmux instead.
-- Replaces the default <C-h/j/k/l> split navigation keymaps in kickstart.
--
-- vim-tmux-navigator is kept (mappings disabled) purely to supply the
-- TmuxNavigate* commands used as the tmux fallback below.
-- https://github.com/paulbkim-dev/vim-herdr-navigation

local function nav(wincmd, dir)
  local prev = vim.api.nvim_get_current_win()
  vim.cmd('wincmd ' .. wincmd)
  if vim.api.nvim_get_current_win() ~= prev then
    return -- moved within Neovim
  end
  -- At a split edge: cross into the surrounding multiplexer.
  if vim.env.HERDR_PANE_ID and vim.env.HERDR_PANE_ID ~= '' then
    local herdr = vim.env.HERDR_BIN_PATH
    if herdr == nil or herdr == '' then
      herdr = 'herdr'
    end
    vim.fn.system { herdr, 'pane', 'focus', '--direction', dir, '--current' }
  elseif vim.env.TMUX and vim.env.TMUX ~= '' then
    local tmux = { left = 'Left', down = 'Down', up = 'Up', right = 'Right' }
    pcall(vim.cmd, 'TmuxNavigate' .. tmux[dir])
  end
end

local function map(lhs, wincmd, dir, desc)
  vim.keymap.set('n', lhs, function()
    nav(wincmd, dir)
  end, { silent = true, noremap = true, desc = desc })
end

return {
  'christoomey/vim-tmux-navigator',
  lazy = false,
  init = function()
    vim.g.tmux_navigator_no_mappings = 1
  end,
  cmd = {
    'TmuxNavigateLeft',
    'TmuxNavigateDown',
    'TmuxNavigateUp',
    'TmuxNavigateRight',
    'TmuxNavigatePrevious',
  },
  config = function()
    map('<C-h>', 'h', 'left', 'Navigate left (vim/herdr/tmux)')
    map('<C-j>', 'j', 'down', 'Navigate down (vim/herdr/tmux)')
    map('<C-k>', 'k', 'up', 'Navigate up (vim/herdr/tmux)')
    map('<C-l>', 'l', 'right', 'Navigate right (vim/herdr/tmux)')
  end,
}
