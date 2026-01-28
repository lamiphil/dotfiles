require("nvchad.configs.lspconfig").defaults()

local servers = {
  "html",
  "cssls",
  "pyright",
  "ts_ls",
  "tailwindcss",
  "eslint",
  "terraformls",
}

local nvlsp = require "nvchad.configs.lspconfig"

-- Check if we're on nvim 0.11+ and use the new API
if vim.lsp.config then
  -- New API for nvim 0.11+
  for _, lsp in ipairs(servers) do
    vim.lsp.config(lsp, {
      on_attach = nvlsp.on_attach,
      on_init = nvlsp.on_init,
      capabilities = nvlsp.capabilities,
    })
  end
else
  -- Fallback to old API for older versions
  local lspconfig = require "lspconfig"
  for _, lsp in ipairs(servers) do
    lspconfig[lsp].setup {
      on_attach = nvlsp.on_attach,
      on_init = nvlsp.on_init,
      capabilities = nvlsp.capabilities,
    }
  end
end

return {
    "neovim/nvim-lspconfig",
}
