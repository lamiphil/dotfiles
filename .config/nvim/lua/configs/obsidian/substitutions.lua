local M = {}
M.lq_substitutions = {
  -- Returns date like "5 février 2025"
  long_date = function()
    return os.date("%-d %B %Y")
  end,

  -- Returns list of active tasks in form of wiki links
  active_tasks = function()

    local tasks_dir = "~/notes/tasks/"

    local handle = io.popen("rg 'status: open' " .. tasks_dir)
    local results = handle:read("*a")
    handle:close()

    print("🔍 Ripgrep Results:\n" .. results)

    local tasks = {}

    for line in results:gmatch("[^\r\n]+") do

      print("➡ Processing line: " .. line)
      local task = line:match(".*/(.-)%.md:status: open")

      if task then

        print("✅ Matched task: " .. task)
        local task_wiki_link = "[[" .. task .. "]]"
        table.insert(tasks, task_wiki_link)
      end
    end

    -- Return the tasks as a Markdown list or a fallback message
    if #tasks > 0 then
      return table.concat(tasks, "\n")
    else
      return "No tasks in progress."
    end
  end,

  todos = function()

    local utils = require("configs.obsidian.utils")
    local current_note_path = vim.fn.expand("%:p")

    -- Extract unfinished todos from the previous note
    local todos = utils.get_todos(current_note_path)
    if #todos == 0 then
      print("✅ No Todos.")
    end

    -- Append unfinished todos to today's note
    utils.append_todos_to_today(current_note_path, todos)
    print("✅ Todos appended to today's note.")
    return table.concat(todos, "\n")
  end,

  todays_tasks = function()

    if not opened_note_filename then
      print("⚠ No note detected yet.")
      return "No reference note available."
    end

    print("TEST " .. opened_note_filename)
    -- Check if the note follows the YYYY-MM-DD format (daily note)
    local note_date = opened_note_filename:match("(%d%d%d%d%-%d%d%-%d%d)")

    if not note_date then
      print("⚠ Not a daily note. Skipping task lookup.")
      return "This note is not a daily note." -- ✅ Always return a string
    end

    -- Extract just the day (e.g., "05" from "2025-02-05")
    local reference_day = tonumber(note_date:match("-(%d%d)$"))

    print("📅 Using reference day:", reference_day) -- Debugging output

    -- Directory containing your tasks
    local tasks_dir = "~/notes/tasks"

    -- Get list of markdown files in tasks directory
    local handle = io.popen("find " .. tasks_dir .. " -name '*.md' -type f")
    if not handle then
      print("❌ Failed to list files in " .. tasks_dir)
      return "Error retrieving tasks."
    end

    local files = handle:read("*a")
    handle:close()

    local matching_files = {}

    for file in files:gmatch("[^\r\n]+") do
      -- Get file modification time
      local stat = vim.loop.fs_stat(file)
      if stat then
        local mtime = os.date("*t", stat.mtime) -- Convert timestamp to table
        local file_day = tonumber(mtime.day) -- Extract day of modification

        -- If the file's modification day matches the daily note's day
        if file_day == reference_day then
          -- Extract just the filename without path or .md
          local filename = file:match(".*/(.-)%.md")
          if filename then
            table.insert(matching_files, "[[" .. filename .. "]]") -- Format as wiki link
          end
        end
      end
    end

    -- ✅ Ensure it always returns a string
    if #matching_files > 0 then
      return table.concat(matching_files, "\n")
    else
      return "No tasks modified on " .. note_date .. "." -- ✅ Always return a string
    end

  end

}

return M
