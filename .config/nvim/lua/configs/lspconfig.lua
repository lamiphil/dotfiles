require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"

local servers = {
  "html",
  "cssls",
  "pyright",
  "ts_ls",
  "tailwindcss",
  "eslint",
  "terraformls",
  -- "hclfmt",
  -- "gitlab-ci-ls",
}

local nvlsp = require "nvchad.configs.lspconfig"

-- lsps with default config
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = nvlsp.capabilities,
  }
end

-- Manual configuration for gitlab-ci-ls
-- lspconfig["gitlab-ci-ls"].setup {
--   cmd = { "gitlab-ci-language-server", "--stdio" },
--   filetypes = { "yaml", "yml" },
--   root_dir = lspconfig.util.root_pattern(".gitlab-ci.yml", ".git"),
--   on_attach = nvlsp.on_attach,
--   on_init = nvlsp.on_init,
--   capabilities = nvlsp.capabilities,
-- }
--
return {
    "neovim/nvim-lspconfig",
}
