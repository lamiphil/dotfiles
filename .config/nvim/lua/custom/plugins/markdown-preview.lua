-- Browser markdown preview (live reload, Mermaid, KaTeX).
-- On macOS it opens a chromeless Vivaldi app window (no tabs, panel,
-- bookmarks or address bar) so AeroSpace keeps it in the current workspace
-- instead of jumping to the browser's workspace.
local vivaldi = '/Applications/Vivaldi.app/Contents/MacOS/Vivaldi'

-- The viewer runs as its own Vivaldi instance with a throwaway profile, so
-- closing/quitting it never touches the main browser or its saved tabs.
-- A second preview while it is open is forwarded to that same instance.
function _G.mkdp_open_vivaldi(url)
  vim.system {
    'open', '-na', 'Vivaldi', '--args',
    '--user-data-dir=' .. vim.fn.stdpath 'cache' .. '/mkdp-vivaldi',
    '--no-first-run', '--no-default-browser-check',
    '--app=' .. url,
  }
end

return {
  'iamcco/markdown-preview.nvim',
  cmd = { 'MarkdownPreview', 'MarkdownPreviewStop', 'MarkdownPreviewToggle' },
  ft = { 'markdown' },
  build = 'cd app && yarn install',
  init = function()
    vim.g.mkdp_filetypes = { 'markdown' }
    if vim.fn.has 'mac' == 1 and vim.fn.executable(vivaldi) == 1 then
      vim.cmd [[
        function! MkdpOpenNewWindow(url) abort
          call v:lua.mkdp_open_vivaldi(a:url)
        endfunction
      ]]
      vim.g.mkdp_browserfunc = 'MkdpOpenNewWindow'
    end
  end,
  keys = {
    { '<leader>mp', '<cmd>MarkdownPreviewToggle<CR>', ft = 'markdown', desc = '[M]arkdown [P]review toggle' },
  },
}
