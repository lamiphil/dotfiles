local M = {}

-- FIX: Make this function work !
M.createMeetingNote = function()
  local TEMPLATE_FILENAME = "meeting"
  local obsidian = require("obsidian").get_client()
  local utils = require("obsidian.util")

  -- prevent Obsidian.nvim from injecting it's own frontmatter table
  obsidian.opts.disable_frontmatter = true

  -- prompt for note title
  -- @see: borrowed from obsidian.command.new
  local note
  local title = utils.input("Enter meeting title: ")
  if not title then
    return
  elseif title == "" then
    title = ""
  end

  local current_date = os.date("%Y-%m-%d")
  local note_name = current_date .. "-" .. title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower() .. ".md"

  local meetings_folder = obsidian.opts.workspaces[1].path .. "/meetings/"
  local full_note_path = meeting_folder .. note_name
  --
  -- Create the note file
  if vim.fn.isdirectory(meeting_folder) == 0 then
    vim.fn.mkdir(meeting_folder, "p")
  end

    -- Open the new note in a buffer
  vim.cmd("e " .. full_path)

  -- Write the template into the buffer
  obsidian:write_note_to_buffer({ path = full_path }, { template = TEMPLATE_FILENAME })

end

return M
