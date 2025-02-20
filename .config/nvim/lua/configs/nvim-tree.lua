return {
  "nvim-tree/nvim-tree.lua",
  version = "*",
  lazy = false,
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    sort = {
      sorter = "case_sensitive",
    },
    view = {
      width = 30,
    },
    filters = {
      dotfiles = false,
      git_ignored = false,
    },
    renderer = {
      icons = {
        glyphs = {
          default = "",
          symlink = "",
          bookmark = "󰆤",
          modified = "●",
          hidden = "󰜌",
          folder = {
            arrow_closed = "",
            arrow_open = "",
            default = "",
            open = "",
            empty = "",
            empty_open = "",
            symlink = "",
            symlink_open = "",
          },
          git = {
            unstaged = "󰜥",
            staged = "✓",
            unmerged = "",
            renamed = "➜",
            untracked = "󰝒",
            -- deleted = "",
            deleted = "",
            ignored = "◌",
          },
        },
      },
    },
  },
  highlights = {
    -- Custom colors for Git status in NvimTree
    NvimTreeGitDeleted = { fg = "#e06c75" },
    NvimTreeGitDirty = { fg = "#ff9e64" },  -- Modified files
    NvimTreeGitIgnored = { fg = "#6f737b" },
    NvimTreeGitMerge = { fg = "#d19a66" },
    NvimTreeGitNew = { fg = "#ff9e64" },    -- Untracked files
    NvimTreeGitRenamed = { fg = "#e5c07b" },
    NvimTreeGitStaged = { fg = "#98c379" },

    -- Git file highlight groups
    NvimTreeGitFileDeletedHL = { link = "NvimTreeGitDeleted" },
    NvimTreeGitFileDirtyHL = { link = "NvimTreeGitDirty" },
    NvimTreeGitFileIgnoredHL = { link = "NvimTreeGitIgnored" },
    NvimTreeGitFileMergeHL = { link = "NvimTreeGitMerge" },
    NvimTreeGitFileNewHL = { link = "NvimTreeGitNew" },
    NvimTreeGitFileRenamedHL = { link = "NvimTreeGitRenamed" },
    NvimTreeGitFileStagedHL = { link = "NvimTreeGitStaged" },

    -- Git folder highlight groups
    NvimTreeGitFolderDeletedHL = { link = "NvimTreeGitDeleted" },
    NvimTreeGitFolderDirtyHL = { link = "NvimTreeGitDirty" },
    NvimTreeGitFolderIgnoredHL = { link = "NvimTreeGitIgnored" },
    NvimTreeGitFolderMergeHL = { link = "NvimTreeGitMerge" },
    NvimTreeGitFolderNewHL = { link = "NvimTreeGitNew" },
    NvimTreeGitFolderRenamedHL = { link = "NvimTreeGitRenamed" },
    NvimTreeGitFolderStagedHL = { link = "NvimTreeGitStaged" },

    -- Git icon highlight groups
    NvimTreeGitStagedIcon = { link = "NvimTreeGitFileStagedHL" }
  }
}
