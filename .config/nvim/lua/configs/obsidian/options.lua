-- Options when editing Markdown files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    -- Enable word wrap
    vim.opt.wrap = true
    vim.opt.linebreak = true   -- Break lines at word boundaries
    vim.opt.showbreak = "↪ "   -- Add a visual indicator for wrapped lines

    -- Margins using foldcolumn and signcolumn
    vim.opt.signcolumn = "yes" -- Creates space on the left
    vim.opt.foldcolumn = "2"   -- Adds extra space on the left

    -- Adjust text width and virtual edit for better wrapping
    vim.opt.textwidth = 120      -- Helps with soft wrapping
    vim.opt.wrapmargin = 0      -- Prevents auto-adjusting the margin dynamically

    -- Enable soft wrap movement
    vim.opt.breakindent = true
    vim.opt.breakindentopt = "shift:2" -- Indent wrapped lines
  end,
})
