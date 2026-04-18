local M = {}
local api = vim.api

-- TODO: Create function to move to previous daily note
-- TODO: Create function to move to next daily note
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

return M
