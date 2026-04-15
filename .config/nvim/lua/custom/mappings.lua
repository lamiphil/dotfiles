require "nvchad.mappings"

local map = vim.keymap.set

map("i", "jk", "<ESC>")
map("n", "H", "^")
map("n", "L", "$")
map("n", "<leader>sv", "<cmd>vsplit<CR>", { noremap = true, silent = true, desc = "Vertical split" })
map("n", "<leader>so", "<cmd>only<CR>", { noremap = true, silent = true, desc = "Keep focused only" })

------------------------
-- Vim Tmux Navigator --
------------------------
map("n", "<C-h>", ":TmuxNavigateLeft<CR>", { silent = true })
map("n", "<C-j>", ":TmuxNavigateDown<CR>", { silent = true })
map("n", "<C-k>", ":TmuxNavigateUp<CR>", { silent = true })
map("n", "<C-l>", ":TmuxNavigateRight<CR>", { silent = true })

------------------
--  Diagnostics --
------------------

-- Popup flottant pour l'erreur sous le curseur
vim.keymap.set("n", "<leader>e", function()
  vim.diagnostic.open_float()
end, { desc = "Show diagnostic in floating window" })

-- Liste navigable de tous les diagnostics
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostics list" })

--------------
-- NVIM DAP --
--------------

-- Lazy load DAP mappings only when dap is available
local dap_ok, dap = pcall(require, "dap")
local dapui_ok, dapui = pcall(require, "dapui")

if dap_ok then
  -- Toggle breakpoint
  map("n", "<leader>db", function()
    dap.toggle_breakpoint()
  end, { noremap = true, silent = true, desc = " Toggle breakpoint" })

  -- Continue / Start
  map("n", "<leader>dc", function()
    dap.continue()
  end, { noremap = true, silent = true, desc = " Start or continue debugging" })

  -- Step Over
  map("n", "<leader>do", function()
    dap.step_over()
  end, { noremap = true, silent = true, desc = " Step over" })

  -- Step Into
  map("n", "<leader>di", function()
    dap.step_into()
  end, { noremap = true, silent = true, desc = " Step into function" })

  -- Step Out
  map("n", "<leader>dO", function()
    dap.step_out()
  end, { noremap = true, silent = true, desc = " Step out of function" })

  -- Continue to cursor
  map("n", "<leader>dm", function()
    dap.run_to_cursor()
  end, { noremap = true, silent = true, desc = "Continue to cursor" })

  -- Terminate debugging
  map("n", "<leader>dq", function()
    dap.terminate()
  end, { noremap = true, silent = true, desc = " Terminate debugging session" })

  if dapui_ok then
    -- Toggle DAP UI
    map("n", "<leader>du", function()
      dapui.toggle()
    end, { noremap = true, silent = true, desc = "Toggle DAP UI" })
  end
end

-----------
-- Other --
-----------

-- Dismiss Noice Message
map("n", "<leader>nd", "<cmd>NoiceDismiss<CR>", {desc = "Dismiss Noice Message"})

-- Toggle Zen Mode
map("n", "<leader>zm", "<cmd>ZenMode<CR>", {desc = "Toggle ZenMode"})

-- Launch LazyGit
map("n", "<leader>lg", "<cmd>LazyGit<CR>", {desc = "Launch LazyGit"})
