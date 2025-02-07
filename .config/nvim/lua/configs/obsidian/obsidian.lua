local substitutions = require("configs.obsidian.substitutions")
local mappings = require("configs.obsidian.mappings")

return {
  "epwalsh/obsidian.nvim",
  version = "*",  -- recommended, use latest release instead of latest commit
  lazy = false,
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
            substitutions = substitutions.lq_substitutions
          }
        }
      },
    },

    templates = {
      folder = "config/templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
      substitutions = {
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

    mappings = mappings.mappings,

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
    },
  },
}
