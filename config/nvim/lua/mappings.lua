require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- Switch toggleable and new terminal mappings
-- toggleable
map("n", "<leader>h", function()
  require("nvchad.term").toggle { pos = "sp" }
end, { desc = "terminal toggleable horizontal term" })

map("n", "<leader>v", function()
  require("nvchad.term").toggle { pos = "vsp" }
end, { desc = "terminal toggleable vertical term" })

map({ "n", "t" }, "<leader>i", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm" }
end, { desc = "terminal toggle floating term" })

-- new
map({ "n", "t" }, "<A-v>", function()
  require("nvchad.term").new { pos = "vsp", id = "vtoggleTerm" }
end, { desc = "terminal new vertical term" })

map({ "n", "t" }, "<A-h>", function()
  require("nvchad.term").new { pos = "sp", id = "htoggleTerm" }
end, { desc = "terminal new horizontal term" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
