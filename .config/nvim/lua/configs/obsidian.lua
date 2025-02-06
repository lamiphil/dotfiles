return {
  "epwalsh/obsidian.nvim",
  version = "*",  -- recommended, use latest release instead of latest commit
  lazy = true,
  ft = "markdown",
  enabled = true,
  dependencies = {
    -- Required.
    "nvim-lua/plenary.nvim",
    -- Optionnal
    "hrsh7th/nvim-cmp"
  },
  opts = {
    workspaces = {
      {
        name = "perso",
        path = "~/notes/perso"
      },
      {
        name = "work",
        path = "~/notes",
        overrides = {
          templates = {

            substitutions = {
              -- Returns list of active tasks in form of wiki links
              active_tasks = function()

                local tasks_dir = "~/notes/tâches/"

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

              todays_tasks = function ()

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
                local tasks_dir = "~/notes/Tâches"

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
          }
        }
      },
    },

    templates = {
      folder = "config/templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
      substitutions = {

        -- Returns date like "5 février 2025"
        long_date = function()
          return os.date("%-d %B %Y")
        end,
      },
    },

    daily_notes = {
      -- Optional, if you keep daily notes in a separate directory.
      folder = "journal",
      -- Optional, if you want to change the date format for the ID of daily notes.
      date_format = "%Y/%m - %B/%Y-%m-%d",
      -- Optional, if you want to change the date format of the default alias of daily notes.
      alias_format = "%-d %B %Y",
      -- Optional, default tags to add to each new daily note created.
      default_tags = { "journal" },
      -- Optional, if you want to automatically insert a template from your template directory like 'daily.md'
      template = "journal.md"
    },

    mappings = {
      -- Insert Datetime using <leader>dt
      ["<leader>dt"] = {
        action = function()
          local datetime = tostring(os.date("%Y-%m-%d %H:%M"))
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
      }
    },

    -- Use markview.nvim rendering instead
    ui = {
      enable = false,
    },

    attachments = {
      img_folder = "config/attachments"
    },

    callbacks = {
      enter_note = function(client, note)
        local note_path = tostring(note.path)
        opened_note_filename = note_path:match("([^/]+)%.md$")

        if opened_note_filename then
            print("📄 Entered note:", opened_note_filename)
        else
            print("⚠ Could not extract  note filename.")
        end
      end,
    }
  },
}
