-- Browser markdown preview (live reload, Mermaid, KaTeX).
-- Inside Rex it opens in a terminal-browser pane split to the right of Neovim.
-- Elsewhere on macOS it opens a chromeless Vivaldi app window (own instance and
-- throwaway profile, so closing it never touches the main browser or its tabs).
local vivaldi = '/Applications/Vivaldi.app/Contents/MacOS/Vivaldi'
local rex = vim.env.REX_BIN_DIR and (vim.env.REX_BIN_DIR .. '/rex') or 'rex'
local rex_session, rex_block = vim.env.REX_SESSION, vim.env.REX_BLOCK
local in_rex = rex_session and rex_session ~= '' and vim.fn.executable 'terminal-browser' == 1

local preview_block -- Rex block holding the terminal-browser pane

local function close_rex_pane()
  if preview_block then
    vim.system { rex, 'block', 'close', preview_block }
    preview_block = nil
  end
end

local function rex_api(method, args, on_done)
  local cmd = { rex, 'api', 'call', method, vim.json.encode(args) }
  local function decode(res)
    local ok, out = pcall(vim.json.decode, res.stdout or '')
    return ok and out or nil
  end
  if on_done then
    return vim.system(cmd, { text = true }, function(res) on_done(decode(res)) end)
  end
  return decode(vim.system(cmd, { text = true }):wait())
end

-- Top of the tiled layout in Neovim's window: anchoring there makes the new
-- pane a full-height column on the far right of the whole window.
local function window_root()
  local view = rex_api('session.view', { session_id = rex_session })
  local function has_block(node)
    if not node then return false end
    if node.block_id then return node.block_id == rex_block end
    return node.split and (has_block(node.split.before) or has_block(node.split.after))
  end
  for _, win in ipairs(view and view.windows or {}) do
    for _, layer in ipairs(win.layers or {}) do
      if layer.kind == 'tiled' and has_block(layer.layout) then
        local root = layer.layout
        return root.split and root.split.split_id or root.block_id
      end
    end
  end
end

local function open_rex_pane(url)
  close_rex_pane()
  -- terminal-browser needs a real TTY to detect graphics support, so Rex
  -- creates the pane and runs it there.
  rex_api('session.new_split', {
    session_id = rex_session,
    anchor_id = window_root() or rex_block,
    direction = 'horizontal',
    side = 'after',
    layout = {
      block = {
        flavor = 'com.superlogical.terminal.shell',
        label = 'md-preview',
        options = { shell = 'none', command = { vim.fn.exepath 'terminal-browser', 'open', url } },
      },
    },
  }, vim.schedule_wrap(function(out)
    preview_block = out and out.block_ids and out.block_ids[1] or nil
    if preview_block then
      -- Rex evens out columns shortly after a split (an immediate resize is
      -- overwritten), so set the width a moment later: existing panes keep
      -- 60%, preview gets 40% of the window.
      local block = preview_block
      vim.defer_fn(function()
        rex_api('session.resize_pane', {
          session_id = rex_session,
          before_block_id = rex_block,
          after_block_id = block,
          direction = 'horizontal',
          ratio = 0.6,
        }, function() end)
      end, 400)
    end
  end))
end

local function open_vivaldi(url)
  vim.system {
    'open', '-na', 'Vivaldi', '--args',
    '--user-data-dir=' .. vim.fn.stdpath 'cache' .. '/mkdp-vivaldi',
    '--no-first-run', '--no-default-browser-check',
    '--app=' .. url,
  }
end

function _G.mkdp_open(url)
  if in_rex then
    open_rex_pane(url)
  else
    open_vivaldi(url)
  end
end

return {
  'iamcco/markdown-preview.nvim',
  cmd = { 'MarkdownPreview', 'MarkdownPreviewStop', 'MarkdownPreviewToggle' },
  ft = { 'markdown' },
  build = 'cd app && yarn install',
  init = function()
    vim.g.mkdp_filetypes = { 'markdown' }
    if in_rex or (vim.fn.has 'mac' == 1 and vim.fn.executable(vivaldi) == 1) then
      vim.cmd [[
        function! MkdpOpen(url) abort
          call v:lua.mkdp_open(a:url)
        endfunction
      ]]
      vim.g.mkdp_browserfunc = 'MkdpOpen'
    end
    vim.api.nvim_create_autocmd('VimLeavePre', { callback = close_rex_pane })
  end,
  keys = {
    {
      '<leader>mp',
      function()
        if not in_rex then
          vim.cmd 'MarkdownPreviewToggle'
        elseif preview_block then
          close_rex_pane()
          vim.cmd 'MarkdownPreviewStop'
        else
          vim.cmd 'MarkdownPreview'
        end
      end,
      ft = 'markdown',
      desc = '[M]arkdown [P]review toggle',
    },
  },
}
