require "nvchad.mappings"

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

------------------------
-- Vim Tmux Navigator -- 
------------------------
map("n", "<C-h>", ":TmuxNavigateLeft<CR>", { silent = true })
map("n", "<C-j>", ":TmuxNavigateDown<CR>", { silent = true })
map("n", "<C-k>", ":TmuxNavigateUp<CR>", { silent = true })
map("n", "<C-l>", ":TmuxNavigateRight<CR>", { silent = true })

-------------------------------------------------
-- Switch toggleable and new terminal mappings --
-------------------------------------------------

-- toggleable -- 
map("n", "<leader>h", function()
  require("nvchad.term").toggle { pos = "sp" }
end, { desc = "terminal toggleable horizontal term" })

map("n", "<leader>v", function()
  require("nvchad.term").toggle { pos = "vsp" }
end, { desc = "terminal toggleable vertical term" })

-- new --
map({ "n", "t" }, "<A-v>", function()
  require("nvchad.term").new { pos = "vsp", id = "vtoggleTerm" }
end, { desc = "terminal new vertical term" })

map({ "n", "t" }, "<A-h>", function()
  require("nvchad.term").new { pos = "sp", id = "htoggleTerm" }
end, { desc = "terminal new horizontal term" })

map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

map("n", "<leader>nd", "<cmd>NoiceDismiss<CR>", {desc = "Dismiss Noice Message"})
