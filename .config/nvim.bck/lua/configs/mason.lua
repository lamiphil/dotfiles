return {
  "williamboman/mason.nvim",
  opts = {
    ensure_installed = {
      "typescript-language-server",
      "tailwindcss-language-server",
      "lua-language-server",
      "eslint-lsp",
      "pyright",
      "debugpy",
      "terraform-ls",
      "hclfmt"
    }
  },
  config = function(_, opts)
    dofile(vim.g.base46_cache .. "mason")
    require("mason").setup(opts)

    -- Auto-install packages
    vim.api.nvim_create_user_command("MasonInstallAll", function()
      if opts.ensure_installed and #opts.ensure_installed > 0 then
        vim.cmd("MasonInstall " .. table.concat(opts.ensure_installed, " "))
      end
    end, {})

    -- Auto-install on startup
    vim.defer_fn(function()
      vim.cmd "MasonInstallAll"
    end, 0)
  end
}

