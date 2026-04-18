-- Statusline configuration using lualine.nvim
-- Layout matches NvChad's "default" statusline theme:
--   mode | file | git branch + diff | (center) lsp progress | diagnostics | lsp server | cwd | cursor position
return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    -- Custom component: LSP server name (e.g. "  LSP ~ lua_ls")
    local function lsp_server()
      local clients = vim.lsp.get_clients { bufnr = 0 }
      if #clients == 0 then return '' end

      local names = {}
      for _, client in ipairs(clients) do
        table.insert(names, client.name)
      end
      return '  LSP ~ ' .. table.concat(names, ', ')
    end

    -- Custom component: Current working directory basename (e.g. "󰉋 nvim")
    local function cwd()
      local dir = vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
      return '󰉋 ' .. dir
    end

    require('lualine').setup {
      options = {
        theme = 'onedark',
        icons_enabled = true,
        -- Use no separators between sections (matches NvChad "default" separator style)
        component_separators = '',
        section_separators = '',
        globalstatus = true,
      },
      sections = {
        -- Left side
        lualine_a = { 'mode' },
        lualine_b = {
          { 'filename', path = 0, symbols = { modified = '●', readonly = '', unnamed = '[No Name]' } },
          'branch',
          { 'diff', symbols = { added = ' ', modified = ' ', removed = ' ' } },
        },
        lualine_c = {},

        -- Right side
        lualine_x = {
          {
            'diagnostics',
            sources = { 'nvim_diagnostic' },
            symbols = { error = ' ', warn = ' ', hint = '󰛩 ', info = '󰋼 ' },
          },
          { lsp_server, cond = function() return #vim.lsp.get_clients { bufnr = 0 } > 0 end },
        },
        lualine_y = { cwd },
        lualine_z = { 'location' },
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
