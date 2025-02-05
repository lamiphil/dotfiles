require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"

local servers = {
  "html",
  "cssls",
  "pyre",
  "ts_ls",
  "tailwindcss",
  "eslint",
  "terraformls",
  "gitlab-ci-ls"
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

return {
    "neovim/nvim-lspconfig",
}
