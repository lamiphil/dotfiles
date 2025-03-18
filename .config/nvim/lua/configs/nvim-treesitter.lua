
-- Logstash grammar highlighting
local parser_config = require "nvim-treesitter.parsers".get_parser_configs()

parser_config.logstash = {
  install_info = {
    url = "~/code/perso/dotfiles/repos/tree-sitter-logstash",
    files = {"src/parser.c"},
    branch = "master",
  },
}

vim.filetype.add({
  extension = {
    conf = "logstash", -- Assuming .conf files are for Logstash
    tftest = "hcl",    -- Ensure .tftest.hcl is treated as HCL
  },
})

vim.treesitter.language.register("logstash", "logstash")

return {
  "nvim-treesitter/nvim-treesitter",
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
      "marksman"
    },
  }
}
