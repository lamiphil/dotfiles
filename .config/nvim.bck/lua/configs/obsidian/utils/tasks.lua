local M = {}
local api = vim.api
local utils = require("configs.obsidian.utils")

M.create_task_note = function ()
  local TEMPLATE_FILENAME = "task"
  local obsidian = require("obsidian").get_client()

  local util = require("obsidian.util")

  -- prevent Obsidian.nvim from injecting it's own frontmatter table
  obsidian.opts.disable_frontmatter = false

  -- prompt for note title
  -- @see: borrowed from obsidian.command.new
  local title = util.input("Enter task title : ")
  if not title then
    return
  elseif title == "" then
    title = ""
  end

  local note_name = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower() .. ".md"

  -- Get current workspace
  local current_note_path = vim.fn.expand("%:p")
  local workspace = utils.get_current_workspace(current_note_path)
  if not workspace then
    print("⚠ No Obsidian workspace found.")
    return
  end

  local tasks_folder = tostring(workspace.path) .. "/tasks/"
  local full_note_path = tasks_folder .. note_name

  -- Create the note file
  if vim.fn.isdirectory(tasks_folder) == 0 then
    vim.fn.mkdir(tasks_folder, "p")
  end

    -- Open the new note in a buffer
  vim.cmd("e " .. full_note_path)

  -- Write the template into the buffer
  obsidian:write_note_to_buffer({ path = full_note_path }, { template = TEMPLATE_FILENAME })
end

return M
