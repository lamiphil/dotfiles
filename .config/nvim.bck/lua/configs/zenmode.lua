return {
  "folke/zen-mode.nvim",
  event = "VeryLazy", -- charge seulement quand tu appelles la commande/mapping
  keys = {
    { "<leader>z", "<cmd>ZenMode<CR>", desc = "Toggle Zen Mode" },
  },

  opts = {
    window = {
      backdrop = 0.95,
      width = 0.6,
      height = 0.95,
      options = {
        number = false,
        relativenumber = true,
        signcolumn = "no",
        cursorline = false,
        cursorcolumn = false,
        foldcolumn = "0",
        list = false,
      },
    },

    plugins = {
      options = {
        enabled = true,
        ruler = false,
        showcmd = false,
      },
      gitsigns = { enabled = true },
      tmux = { enabled = true },
      kitty = {
        enabled = true,
        font = "+2", -- grossit la police Kitty en Zen
      },
      -- twilight = { enabled = true }, -- décommente si tu installes twilight.nvim
    },

    on_open = function()
      -- Sauvegarde de certains réglages
      vim.g._zen_saved_opts = {
        laststatus = vim.o.laststatus,
        cmdheight = vim.o.cmdheight,
        showmode = vim.o.showmode,
        conceallevel = vim.o.conceallevel,
        virtual_text = vim.diagnostic.config().virtual_text,
      }

      vim.o.laststatus = 0
      vim.o.cmdheight = 0
      vim.o.showmode = false
      vim.o.conceallevel = 2
      vim.diagnostic.config({ virtual_text = false })
    end,

    on_close = function()
      local saved = vim.g._zen_saved_opts or {}
      vim.o.laststatus   = saved.laststatus or 2
      vim.o.cmdheight    = saved.cmdheight or 1
      vim.o.showmode     = saved.showmode or true
      vim.o.conceallevel = saved.conceallevel or 0

      if saved.virtual_text ~= nil then
        vim.diagnostic.config({ virtual_text = saved.virtual_text })
      end
    end,
  },
}

