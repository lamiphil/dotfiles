return {
  {
    "stevearc/conform.nvim",
    event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- LSP package manager
  {
    "williamboman/mason.nvim",
    opts = require("configs.mason-nvim")
  },

  -- Syntax highlighting
  {
  	"nvim-treesitter/nvim-treesitter",
    opts = require("configs.nvim-treesitter")
  },

  -- Vim Tmux Navigator
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    config = function()
      require "configs.vim-tmux-navigator"
    end,
  },

  -- Auto closing HTML tags
  {
    "windwp/nvim-ts-autotag",
    ft = {
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact",
    },
    config = function()
      require("nvim-ts-autotag").setup()
    end
  },

  {
    require "configs.tailwind"
  },

  -- FZF lua
  {
    require "configs.fzf-lua"
  },

  {
    require "configs.noice"
  },

  {
    require "configs.render-markdown"
  },
}

