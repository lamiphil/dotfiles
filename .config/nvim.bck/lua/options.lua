require "nvchad.options"

vim.opt.relativenumber = true
vim.opt.scrolloff=999
vim.opt.wrap = false
vim.opt.clipboard = "unnamedplus"

-- Add commentstring '#' for Terraform .tf files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "terraform",
  callback = function()
    vim.bo.commentstring = "# %s"
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('highlight_yank', {}),
  desc = 'Hightlight selection on yank',
  pattern = '*',
  callback = function()
    vim.highlight.on_yank { higroup = 'IncSearch', timeout = 500 }
  end,
})

-- Enable line wrap for Markdown files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true       -- Break at word boundaries
    vim.opt_local.breakindent = true     -- Indent wrapped lines
    vim.opt_local.breakindentopt = "shift:2"
  end,
})
