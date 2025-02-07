local utils = require("configs.obsidian.utils")

local M = {}

M.mappings = {
  -- Insert Datetime using <leader>dt
  ["<leader>dt"] = {
    action = function()
      local datetime = "**" .. tostring(os.date("%Y-%m-%d %H:%M")) .. "**"
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { datetime })
    end,
    opts = { noremap = true, silent = true, desc = "Insert Datetime" },
  },

  -- Open Daily note using <leader>od
  ["<leader>od"] = {
    action = function()
      vim.cmd("ObsidianToday")
    end,
    opts = { noremap = true, silent = true, desc = "Open daily note" },
  },

  -- Create new note from Template <leader>ct
  ["<leader>ct"] = {
    action = function()
      vim.cmd("ObsidianNewFromTemplate")
    end,
    opts = { noremap = true, silent = true, desc = "Create new note from Template" },
  },

  -- Overrides the 'gf' mapping to work on markdown/wiki links within your vault.
  ["gf"] = {
    action = function()
      return require("obsidian").util.gf_passthrough()
    end,
    opts = { noremap = false, expr = true, buffer = true },
  },

  -- Toggle check-boxes.
  ["<leader>ch"] = {
    action = function()
      return require("obsidian").util.toggle_checkbox()
    end,
    opts = { buffer = true, desc = "Toggle check-boxes" },
  },

  -- Smart action depending on context, either follow link or toggle checkbox.
  ["<cr>"] = {
    action = function()
      return require("obsidian").util.smart_action()
    end,
    opts = { buffer = true, expr = true },
  },

  -- Create new meeting note
  ["<leader>crm"] = {
    action = function()
      utils.createMeetingNote()
    end,
    opts = { noremap = true, silent = true, desc = "Create new meeting note" },
  }
}

return M
