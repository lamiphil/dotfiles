require "nvchad.options"

vim.opt.relativenumber = true
vim.opt.scrolloff=999
vim.opt.wrap = false

-- Add commentstring '#' for Terraform .tf files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "terraform",
  callback = function()
    vim.bo.commentstring = "# %s"
  end,
})


