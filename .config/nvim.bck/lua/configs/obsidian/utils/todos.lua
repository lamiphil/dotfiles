local M = {}
local api = vim.api
local utils = require("configs.obsidian.utils")

M.get_todos = function(note_path)
  local todos = {}

  local workspace = utils.get_current_workspace(note_path)
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
  local util = require("obsidian.util")

  -- Prompt for new todo
  local new_todo = util.input("Enter new TODO :")

  if not new_todo or new_todo == "" then
    print("⚠ No TODO entered.")
    return
  end

  -- Get current workspace
  local current_note_path = vim.fn.expand("%:p")
  local workspace = utils.get_current_workspace(current_note_path)
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
  local workspace = utils.get_current_workspace(current_note_path)
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
  local workspace = utils.get_current_workspace(current_note_path)
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

return M
