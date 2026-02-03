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
  Normal       = { fg = colors.color7 or "#c0c3c1", bg = "NONE" },
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

})

return M

