local M = {}

-- TODO: Save .md file when leaving Insert mode
-- TODO: Create function to move daily todos from the previous day to the current.
-- TODO: Create function to move to previous daily note
-- TODO: Create function to move to next daily note

M.get_obsidian_client = function()
  -- Attempt to require the obsidian module
  local obsidian_ok, obsidian = pcall(require, "obsidian")
  if not obsidian_ok then
    print("⚠ obsidian.nvim is not available")
    return nil
  end

  -- Retrieve the client
  local client = obsidian.get_client()
  if not client then
    print("⚠ Could not get obsidian client")
    return nil
  end

  return client
end

M.get_current_workspace = function(note_path)
  local client = M.get_obsidian_client()
  if not client then
    print("⚠ Client is nil")
    return nil
  end
  print("Current path: " .. note_path)

  -- Retrieve the workspace module
  local Workspace = require("obsidian.workspace")

  -- Print all workspaces before finding the correct one
  print("📂 Available Workspaces: " .. vim.inspect(client.opts.workspaces))

  -- Get the current workspace based on the current working directory
  local current_workspace = Workspace.get_workspace_for_dir(note_path, client.opts.workspaces)

  -- Ensure current_workspace is valid before concatenating
  if current_workspace then
    print("Current workspace: " .. current_workspace.name)
    return current_workspace
  else
    print("⚠ No matching workspace found for the current directory")
    return nil
  end
end

M.is_daily_note = function(note_path)
  local file = io.open(note_path, "r")
  if not file then return false end

  local in_frontmatter = false

  for line in file:lines() do
    if line:match("^%-%-%-") then
      -- Toggle frontmatter detection
      in_frontmatter = not in_frontmatter
    elseif in_frontmatter and line:match("journal") then
      file:close()
      return true
    end
  end

  file:close()
  return false
end

M.get_previous_day_filename = function(note_path)
  local current_workspace = M.get_current_workspace(note_path)
  if not current_workspace then
    print("⚠ Could not determine current workspace")
    return nil
  end

  -- Ensure path is correctly formatted
  local workspace_path = tostring(current_workspace.path)
  print("📂 Resolved workspace path: " .. workspace_path)

  -- Get yesterday's date in the expected format
  local prev_date = os.date("%Y/%m - %B/%Y-%m-%d", os.time() - 86400) -- Subtract 1 day

  -- Construct full path dynamically
  local prev_note_path = workspace_path .. "/journal/" .. prev_date .. ".md"

  print("📄 Looking for previous daily note:", prev_note_path) -- Debugging

  return prev_note_path
end

M.get_unfinished_todos = function(previous_note_path)
  local todos = {}
  local file = io.open(previous_note_path, "r")
  if file then
    local in_todo_section = false

    for line in file:lines() do
      if line:match("^## À faire aujourd'hui") then
        in_todo_section = true
      elseif in_todo_section and line:match("^## ") then
        -- Stop capturing if we reach another header
        break
      elseif in_todo_section and line:match("^%- %[ %]") then
        -- Collect only unfinished tasks under ## À faire aujourd'hui
        table.insert(todos, line)
      end
    end

    file:close()
  end
  return todos
end

M.append_todos_to_today = function(current_note_path, todos)
  if #todos == 0 then return end

  local lines = {}
  local file = io.open(current_note_path, "r")
  if file then
    for line in file:lines() do
      table.insert(lines, line)
    end
    file:close()
  end

  -- Find where to insert tasks
  local insert_index = nil
  for i, line in ipairs(lines) do
    if line:match("## À faire aujourd'hui") then
      insert_index = i + 1
      break
    end
  end

  if insert_index then
    for _, todo in ipairs(todos) do
      table.insert(lines, insert_index, todo)
      insert_index = insert_index + 1
    end
  end

  -- Write back to the file
  file = io.open(current_note_path, "w")
  if file then
    for _, line in ipairs(lines) do
      file:write(line .. "\n")
    end
    file:close()
  end
end

-- FIX: Make this function work !
M.createMeetingNote = function()
  local TEMPLATE_FILENAME = "meeting"
  local obsidian = require("obsidian").get_client()
  local utils = require("obsidian.util")

  -- prevent Obsidian.nvim from injecting it's own frontmatter table
  obsidian.opts.disable_frontmatter = false

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

  print(obsidian.opts.workspaces)
  local meetings_folder = obsidian.opts.workspaces[1].path .. "/meetings/"
  print(meetings_folder)
  local full_note_path = meetings_folder .. note_name
  --
  -- Create the note file
  if vim.fn.isdirectory(meetings_folder) == 0 then
    vim.fn.mkdir(meetings_folder, "p")
  end

    -- Open the new note in a buffer
  vim.cmd("e " .. full_note_path)

  -- Write the template into the buffer
  obsidian:write_note_to_buffer({ path = full_note_path }, { template = TEMPLATE_FILENAME })

end

return M
