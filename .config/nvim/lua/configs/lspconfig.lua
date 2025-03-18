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

-- Set commentstring for HCL (including .tftest.hcl)
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "hcl", "terraform" },
  callback = function()
    vim.bo.commentstring = "# %s"
  end,
})

return {
    "neovim/nvim-lspconfig",
}
