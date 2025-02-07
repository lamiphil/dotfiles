return {
  "OXY2DEV/markview.nvim",
  lazy = false,
  enabled = true,
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons"
  },

  config = function()
    -- Ensure markview is installed before trying to load presets
    local ok, presets = pcall(require, "markview.presets")
    if not ok then
      vim.notify("markview.presets not found!", vim.log.levels.ERROR)
      return
    end

    require("markview").setup({
      preview = {
        icon_provider = "devicons"
      },
      markdown = {
        headings = presets.headings.glow,
        horizontal_rules = presets.horizontal_rules.thick,
        tables = presets.tables.rounded
      },
    })
  end
}
