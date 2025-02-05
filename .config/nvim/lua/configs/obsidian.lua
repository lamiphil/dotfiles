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
        name = "work",
        path = "~/notes/lq",
      },
      {
        name = "perso",
        path = "~/notes/perso"
      }
    },

    templates = {
      folder = "config/templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
      substitutions = {
        long_date = function()
          return os.date("%-d %B %Y")
        end,

        active_tasks = function()

          local tasks_dir = "~/notes/lq/tâches/"

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
        end

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
  },
}
