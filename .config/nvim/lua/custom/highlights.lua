local M = {}

-- Fonction pour lire les couleurs de pywal
local function get_pywal_colors()
  local ok, json = pcall(vim.fn.readfile, os.getenv("HOME") .. "/.cache/wal/colors.json")
  if not ok then return {} end

  local decoded = vim.fn.json_decode(table.concat(json, "\n"))
  return decoded.colors or {}
end

local colors = get_pywal_colors()

-- Tu conserves ta table override si jamais tu veux surcharger plus tard
M.override = {}

print(colors.colors1)
-- Tu ajoutes ici des groupes de highlight dynamiques
M.add = vim.tbl_extend("force", {

  -- Exemples de groupes intégrés à Neovim
  Normal       = { fg = colors.color7 or "#c0c3c1", bg = colors.color0 or "#061008" },
  LineNr       = { fg = colors.color8 or "#566959" },
  Comment      = { fg = colors.color5 or "#0BAFD4", italic = true },
  Visual       = { bg = colors.color2 or "#02AE9A" },
  CursorLine   = { bg = colors.color1 or "#028F6C" },
  StatusLine   = { fg = colors.color7 or "#c0c3c1", bg = colors.color1 or "#028F6C" },
  Pmenu        = { fg = colors.color7 or "#c0c3c1", bg = colors.color1 or "#028F6C" },

}, {

  -- Toutes tes couleurs statiques existantes ici (inchangées)
  MarkviewPalette1 = { fg = "#f38ba8", bg = "#4d3649", bold = true },
  MarkviewPalette2 = { fg = "#f9b387", bg = "#4d3d43", bold = true },
  MarkviewPalette3 = { fg = "#f9e2af", bg = "#4c474b", bold = true },
  MarkviewPalette4 = { fg = "#a6e3a1", bg = "#3c4948", bold = true },
  MarkviewPalette5 = { fg = "#74c7ec", bg = "#314358", bold = true },
  MarkviewPalette6 = { fg = "#b4befe", bg = "#3c405b", bold = true },

  -- Git status couleurs NvimTree
  NvimTreeGitDeleted = { fg = "#e06c75" },
  NvimTreeGitDirty = { fg = "#ff9e64" },
  NvimTreeGitIgnored = { fg = "#6f737b" },
  NvimTreeGitMerge = { fg = "#d19a66" },
  NvimTreeGitNew = { fg = "#ff9e64" },
  NvimTreeGitRenamed = { fg = "#e5c07b" },
  NvimTreeGitStaged = { fg = "#98c379" },

  -- Liens pour Git
  NvimTreeGitFileDeletedHL = { link = "NvimTreeGitDeleted" },
  NvimTreeGitFileDirtyHL = { link = "NvimTreeGitDirty" },
  NvimTreeGitFileIgnoredHL = { link = "NvimTreeGitIgnored" },
  NvimTreeGitFileMergeHL = { link = "NvimTreeGitMerge" },
  NvimTreeGitFileNewHL = { link = "NvimTreeGitNew" },
  NvimTreeGitFileRenamedHL = { link = "NvimTreeGitRenamed" },
  NvimTreeGitFileStagedHL = { link = "NvimTreeGitStaged" },

  NvimTreeGitFolderDeletedHL = { link = "NvimTreeGitDeleted" },
  NvimTreeGitFolderDirtyHL = { link = "NvimTreeGitDirty" },
  NvimTreeGitFolderIgnoredHL = { link = "NvimTreeGitIgnored" },
  NvimTreeGitFolderMergeHL = { link = "NvimTreeGitMerge" },
  NvimTreeGitFolderNewHL = { link = "NvimTreeGitNew" },
  NvimTreeGitFolderRenamedHL = { link = "NvimTreeGitRenamed" },
  NvimTreeGitFolderStagedHL = { link = "NvimTreeGitStaged" },

  NvimTreeGitStagedIcon = { link = "NvimTreeGitFileStagedHL" }

})

return M

