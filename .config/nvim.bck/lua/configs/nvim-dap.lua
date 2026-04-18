local map = vim.keymap.set

return {
  {
    "mfussenegger/nvim-dap",
    lazy = true,
    dependencies = {
	  "nvim-neotest/nvim-nio",
      "rcarriga/nvim-dap-ui",
      "mfussenegger/nvim-dap-python",
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      local dap_python = require("dap-python")

      require("dapui").setup({})
      require("nvim-dap-virtual-text").setup({
        commented = true, -- Show virtual text alongside comment
      })

      dap_python.setup("python3")
      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Launch current file",
          program = "${file}", -- le fichier Python actuellement ouvert
          pythonPath = function()
            local venv = os.getenv("VIRTUAL_ENV")
            if venv and vim.fn.executable(venv .. "/bin/python3") == 1 then
              return venv .. "/bin/python"
            end
            return "python3"
          end,
        },
        {
          type = "python",
          request = "launch",
          name = "Launch with arguments",
          program = "${file}",
          args = function()
            local input = vim.fn.input("Arguments: ")
            return vim.fn.split(input, " ", true)
          end,
          pythonPath = function()
            local venv = os.getenv("VIRTUAL_ENV")
            if venv and vim.fn.executable(venv .. "/bin/python3") == 1 then
              return venv .. "/bin/python"
            end
            return "python3"
          end,
        }
      }


      vim.fn.sign_define("DapBreakpoint", {
        text = "",
        texthl = "DiagnosticSignError",
        linehl = "",
        numhl = "",
      })

      vim.fn.sign_define("DapBreakpointRejected", {
        text = "", -- or "❌"
        texthl = "DiagnosticSignError",
        linehl = "",
        numhl = "",
      })

      vim.fn.sign_define("DapStopped", {
        text = "", -- or "→"
        texthl = "DiagnosticSignWarn",
        linehl = "Visual",
        numhl = "DiagnosticSignWarn",
      })

      -- Automatically open/close DAP UI
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
    end,
  },
}

