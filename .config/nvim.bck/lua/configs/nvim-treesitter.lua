
-- Logstash grammar highlighting
-- Note: In nvim 0.10+, parser configuration is done differently
-- You may need to manually compile and add the parser to runtimepath

vim.filetype.add({
  extension = {
    conf = "logstash", -- Assuming .conf files are for Logstash
    tftest = "hcl",    -- Ensure .tftest.hcl is treated as HCL
  },
})

vim.treesitter.language.register("logstash", "logstash")

return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  dependencies = {
    "OXY2DEV/markview.nvim"
  },
  opt = {
    ensure_installed = {
      "vim",
      "lua",
      "vimdoc",
      "html",
      "css",
      "python",
      "javascript",
      "typescript",
      "tsx",
      "logstash",
      "terraform",
      "hcl",
      "markdown",
      "markdown_inline",
    },
  }
}
