local M = {}
local api = vim.api

-- TODO: Save .md file when leaving Insert mode
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
  -- Extract the filename from the path
  local filename = note_path:match("^.+/(.+)$")
  print("Debug: Extracted filename -", filename or "nil")

  -- Check if the filename matches the daily note pattern YYYY-MM-DD.md
  if filename and filename:match("^%d%d%d%d%-%d%d%-%d%d%.md$") then
    print("Debug: Filename matches daily note pattern.")
    return true
  else
    print("Debug: Filename does not match daily note pattern.")
  end

  -- Attempt to open the file
  local file = io.open(note_path, "r")
  if not file then
    print("Debug: Failed to open file at path -", note_path)
    return false
  else
    print("Debug: Successfully opened file.")
  end

  local in_frontmatter = false
  for line in file:lines() do
    print("Debug: Reading line -", line)
    if line:match("^%-%-%-") then
      in_frontmatter = not in_frontmatter  -- Toggle front matter flag
      print("Debug: Toggled in_frontmatter to", in_frontmatter)
    elseif in_frontmatter and line:match("tags:") then
      print("Debug: Found 'tags:' line in front matter.")
      -- Check for the presence of 'journal' tag
      if line:match("journal") then
        print("Debug: 'journal' tag found.")
        file:close()
        return true
      else
        print("Debug: 'journal' tag not found in 'tags:' line.")
      end
    end
  end

  file:close()
  print("Debug: End of file reached without finding 'journal' tag.")
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

  local seconds_in_a_day = 86400
  local current_time = os.time()
  local prev_note_path

  -- Get yesterday's date in the expected format
  while true do
    current_time = current_time - seconds_in_a_day
    local prev_date = os.date("%Y/%m - %B/%Y-%m-%d", current_time) -- Subtract 1 day
    prev_note_path = workspace_path .. "/journal/" .. prev_date .. ".md"

    -- Check if the file exists
    local file = io.open(prev_note_path, "r")

    if file then 
      file:close()
      print("📄 Found previous daily note: " .. prev_note_path)
      return prev_note_path
    end

    -- Safety check to prevent infinite loop (optional)
    if current_time < os.time() - (365 * seconds_in_a_day) then
      print("⚠ No previous daily note found in the past year")
      return nil
    end
  end
end

M.get_todos = function(note_path)
  local todos = {}

  local workspace = M.get_current_workspace(note_path)
  if not workspace then
    print("⚠ Could not determine current workspace")
    return todos
  end

  local todos_file_path = tostring(workspace.path) .. "/tasks/_todos.md"
  print("📂 Retrieving todos from:", todos_file_path)

  -- Open the file for reading
  local file = io.open(todos_file_path, "r")
  if not file then
    print("⚠ Could not open TODOs file:", todos_file_path)
    return todos
  end

  -- Read and collect unfinished tasks
  for line in file:lines() do
    if line:match("^%- %[ %]") then
      print("TODO found :" .. line)
      table.insert(todos, line)
    end
  end

  file:close()

  -- If no tasks were found, return a default message
  if #todos == 0 then
    return { "✅ No unfinished tasks in _todos.md" }
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
    if line:match("## À faire") then
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

M.add_todo = function()
  local utils = require("obsidian.util")

  -- Prompt for new todo
  local new_todo = utils.input("Enter new TODO :")

  if not new_todo or new_todo == "" then
    print("⚠ No TODO entered.")
    return
  end

  -- Get current workspace
  local current_note_path = vim.fn.expand("%:p")
  local workspace = M.get_current_workspace(current_note_path)
  if not workspace then
    print("⚠ No Obsidian workspace found.")
    return
  end

  -- Ensure absolute path
  local todos_file_path = tostring(workspace.path) .. "/tasks/_todos.md"
  print("📂 Writing TODO to:", todos_file_path)

  -- Open the file for appending
  local file = io.open(todos_file_path, "a")
  if not file then
    print("⚠ Could not open _todos.md for writing.")
    return
  end

  -- Write the new TODO as a Markdown task
  file:write("- [ ] " .. new_todo .. "\n")
  file:close()

  print("✅ TODO added: " .. new_todo)
end

M.complete_todo = function() 

  local current_note_path = vim.fn.expand("%:p")
  local workspace = M.get_current_workspace(current_note_path)
  if not workspace then
    print("⚠ No Obsidian workspace found.")
    return
  end

  -- Ensure absolute path
  local todos_file_path = tostring(workspace.path) .. "/tasks/_todos.md"
  print("📂 Writing TODO to:", todos_file_path)
  M.is_daily_note()

end

M.check_todo = function() 

  local current_note_path = vim.fn.expand("%:p")
  local workspace = M.get_current_workspace(current_note_path)
  if not workspace then
    print("⚠ No Obsidian workspace found.")
    return
  end

  -- Ensure absolute path
  local todos_file_path = tostring(workspace.path) .. "/tasks/_todos.md"
  local current_buf = api.nvim_get_current_buf()
  local lines = api.nvim_buf_get_lines(current_buf, 0, -1, false)

  -- Get checked todos from daily note
  local checked_todos = {}
  for _, line in ipairs(lines) do
    local todo = line:match("%- %[x%] (.+)")
    if todo then
      table.insert(checked_todos, todo)
    end
  end

  -- Check current todos in _TODOS.md
  local todos_file = io.open(todos_file_path, "r")
  if not todos_file then 
    print("❌ Could not open TODOs file")
    return
  end
  local todos_line = {}
  for line in todos_file:lines() do
    table.insert(todos_line, line)
  end
  todos_file:close()

  -- Remove TODOs that match with checked todos from daily note
  local updated_lines = {}
  for _, line in ipairs(todos_line) do
    local todo = line:match("%- %[ %] (.+)") -- Only unchecked todos
    if todo and vim.tbl_contains(checked_todos, todo) then
      -- Skip this line
    else
      table.insert(updated_lines, line)
    end
  end
  
  -- Rewrite file
  local out = io.open(todos_file_path, "w")
  for _, line in ipairs(updated_lines) do
    out:write(line .. "\n")
  end
  out:close()

  print("✅ TODOs updated in _todos.md !")

end



M.create_meeting_note = function()
  local TEMPLATE_FILENAME = "meeting"
  local obsidian = require("obsidian").get_client()
  local utils = require("obsidian.util")

  -- prevent Obsidian.nvim from injecting it's own frontmatter table
  obsidian.opts.disable_frontmatter = false

  -- prompt for note title
  -- @see: borrowed from obsidian.command.new
  local title = utils.input("Enter meeting title : ")
  if not title then
    return
  elseif title == "" then
    title = ""
  end

  local current_date = os.date("%Y-%m-%d")
  local note_name = current_date .. " - " .. title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower() .. ".md"

  -- Get current workspace
  local current_note_path = vim.fn.expand("%:p")
  local workspace = M.get_current_workspace(current_note_path)
  if not workspace then
    print("⚠ No Obsidian workspace found.")
    return
  end

  local date_folder = os.date("%Y/%m - %B/")
  local meetings_folder = tostring(workspace.path) .. "/meetings/" .. date_folder
  local full_note_path = meetings_folder .. note_name

  -- Create the note file
  if vim.fn.isdirectory(meetings_folder) == 0 then
    vim.fn.mkdir(meetings_folder, "p")
  end

    -- Open the new note in a buffer
  vim.cmd("e " .. full_note_path)

  -- Write the template into the buffer
  obsidian:write_note_to_buffer({ path = full_note_path }, { template = TEMPLATE_FILENAME })

end

M.create_task_note = function ()
  local TEMPLATE_FILENAME = "task"
  local obsidian = require("obsidian").get_client()

  local utils = require("obsidian.util")

  -- prevent Obsidian.nvim from injecting it's own frontmatter table
  obsidian.opts.disable_frontmatter = false

  -- prompt for note title
  -- @see: borrowed from obsidian.command.new
  local title = utils.input("Enter task title : ")
  if not title then
    return
  elseif title == "" then
    title = ""
  end

  local note_name = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower() .. ".md"

  -- Get current workspace
  local current_note_path = vim.fn.expand("%:p")
  local workspace = M.get_current_workspace(current_note_path)
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
