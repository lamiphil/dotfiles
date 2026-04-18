-- Statusline configuration using lualine.nvim
-- Layout matches NvChad's "default" statusline theme:
--   mode | file + git branch + diff | (center) | lsp server | cwd | cursor position
return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    -- Custom component: LSP server name (e.g. " LSP ~ tailwindcss")
    local function lsp_server()
      local clients = vim.lsp.get_clients { bufnr = 0 }
      if #clients == 0 then return '' end

      local names = {}
      for _, client in ipairs(clients) do
        table.insert(names, client.name)
      end
      return ' LSP ~ ' .. table.concat(names, ', ')
    end

    -- Custom component: Current working directory basename (e.g. "󰉋 dotfiles")
    local function cwd()
      local dir = vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
      return '󰉋 ' .. dir
    end

    -- Custom component: Cursor position as line/col (e.g. "15/1")
    local function cursor_pos()
      local line = vim.fn.line '.'
      local col = vim.fn.virtcol '.'
      return ' ' .. line .. '/' .. col
    end

    require('lualine').setup {
      options = {
        theme = 'onedark',
        icons_enabled = true,
        -- No separators between components within the same section
        component_separators = '',
        -- Rounded separators on the outer edges of section groups
        section_separators = { left = '', right = '' },
        globalstatus = true,
      },
      sections = {
        -- Left side: mode indicator with colored background
        lualine_a = { 'mode' },

        -- Left-center: file info + git branch + diff stats on grey background
        lualine_b = {
          { 'filename', path = 0, symbols = { modified = '●', readonly = '', unnamed = '[No Name]' } },
          'branch',
          { 'diff', symbols = { added = ' ', modified = ' ', removed = ' ' } },
        },

        -- Center: empty spacer
        lualine_c = {},

        -- Right-center: diagnostics + LSP server name on base statusline background
        lualine_x = {
          {
            'diagnostics',
            sources = { 'nvim_diagnostic' },
            symbols = { error = ' ', warn = ' ', hint = '󰛩 ', info = '󰋼 ' },
          },
          { lsp_server, cond = function() return #vim.lsp.get_clients { bufnr = 0 } > 0 end },
        },

        -- Right: CWD on red background (matches NvChad's St_cwd_icon style)
        lualine_y = {
          { cwd, color = { bg = '#e06c75', fg = '#1e222a', gui = 'bold' } },
        },

        -- Far right: cursor position on green background (matches NvChad's St_pos_icon style)
        lualine_z = {
          { cursor_pos, color = { bg = '#98c379', fg = '#1e222a', gui = 'bold' } },
        },
      },

      -- Inactive windows: just show filename and location
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { 'filename' },
        lualine_x = { 'location' },
        lualine_y = {},
        lualine_z = {},
      },
    }
  end,
}
