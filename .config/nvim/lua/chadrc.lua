-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig

-- vim.api.nvim_set_hl(0, "MarkviewHeading1", { fg = "#e06c75", bold = true }) -- Soft Red
-- vim.api.nvim_set_hl(0, "MarkviewHeading2", { fg = "#d19a66", bold = true }) -- Orange
-- vim.api.nvim_set_hl(0, "MarkviewHeading3", { fg = "#e5c07b", bold = true }) -- Yellow
-- vim.api.nvim_set_hl(0, "MarkviewHeading4", { fg = "#98c379", bold = true }) -- Green
-- vim.api.nvim_set_hl(0, "MarkviewHeading5", { fg = "#61afef", bold = true }) -- Blue
-- vim.api.nvim_set_hl(0, "MarkviewHeading6", { fg = "#c678dd", bold = true }) -- Purple

-- Onedark-inspired colors for heading signs
vim.api.nvim_set_hl(0, "MarkviewHeading1Sign", { fg = "#e06c75", bold = true }) -- Soft Red
vim.api.nvim_set_hl(0, "MarkviewHeading2Sign", { fg = "#d19a66", bold = true }) -- Orange
vim.api.nvim_set_hl(0, "MarkviewHeading3Sign", { fg = "#e5c07b", bold = true }) -- Yellow
vim.api.nvim_set_hl(0, "MarkviewHeading4Sign", { fg = "#98c379", bold = true }) -- Green
vim.api.nvim_set_hl(0, "MarkviewHeading5Sign", { fg = "#61afef", bold = true }) -- Blue
vim.api.nvim_set_hl(0, "MarkviewHeading6Sign", { fg = "#c678dd", bold = true }) -- Purple

local M = {}
local highlights = require "custom.highlights"

M.base46 = {
	theme = "onedark",
  hl_add = highlights.add
}

return M
