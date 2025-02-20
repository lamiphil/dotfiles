local M = {}

M.override = {
}

M.add = {
  MarkviewPalette1 = { fg = "#f38ba8", bg = "#4d3649", bold = true },
  MarkviewPalette2 = { fg = "#f9b387", bg = "#4d3d43", bold = true },
  MarkviewPalette3 = { fg = "#f9e2af", bg = "#4c474b", bold = true },
  MarkviewPalette4 = { fg = "#a6e3a1", bg = "#3c4948", bold = true },
  MarkviewPalette5 = { fg = "#74c7ec", bg = "#314358", bold = true },
  MarkviewPalette6 = { fg = "#b4befe", bg = "#3c405b", bold = true },

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

return M
