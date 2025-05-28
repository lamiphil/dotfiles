local todos = require("configs.obsidian.utils.todos")
local tasks = require("configs.obsidian.utils.tasks")
local meetings = require("configs.obsidian.utils.meetings")

local M = {}

M.mappings = {
  -- Insert Datetime using <leader>dt
  ["<leader>dt"] = {
  action = function()
    local datetime = "**" .. os.date("%Y-%m-%d %H:%M") .. "**"
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { datetime })
  end,
  opts = { noremap = true, silent = true, desc = "Insert Datetime at Cursor" },
},


  -- Open Daily note using <leader>od
  ["<leader>od"] = {
    action = function()
      vim.cmd("ObsidianToday")
    end,
    opts = { noremap = true, silent = true, desc = "Open daily note" },
  },

  -- Open tomorrows note using <leader>ok
  ["<leader>ok"] = {
    action = function()
      vim.cmd("ObsidianTomorrow")
    end,
    opts = { noremap = true, silent = true, desc = "Open tomorrow's note" },
  },

  -- Open yesterday's note using <leader>oj
  ["<leader>oj"] = {
    action = function()
      vim.cmd("ObsidianYesterday")
    end,
    opts = { noremap = true, silent = true, desc = "Open yesterday's note" },
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
  -- TODO: Make checking a todo in a daily note remove the todo from _todos.md
  ["<leader>ch"] = {
    action = function()
      todos.check_todo()
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
      meetings.create_meeting_note()
    end,
    opts = { noremap = true, silent = true, desc = "Create new meeting note" },
  },

  -- Create new task note
  ["<leader>crt"] = {
    action = function()
      tasks.create_task_note()
    end,
    opts = { noremap = true, silent = true, desc = "Create new task note" },
  },

  -- Add new TODO
  ["<leader>td"] = {
    action = function()
      todos.add_todo()
    end,
    opts = {noremap = true, silent = true, desc = "Add new TODO" },
  },

  -- Show and select open task notes
  ["<leader>ot"] = {
    action = function()
      vim.cmd("ObsidianSearch status: open")
    end,
    opts = { noremap = true, silent = true, desc = "Show and select open task notes" },
  }

}

return M
