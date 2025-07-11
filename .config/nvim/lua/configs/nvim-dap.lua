local map = vim.keymap.set

return {
  {
    "mfussenegger/nvim-dap",
    ft = "python",
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

      -- dap_python.setup("python3")
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

      -- Toggle breakpoint
      map("n", "<leader>db", function()
        dap.toggle_breakpoint()
      end, { noremap = true, silent = true, desc = " Toggle breakpoint" })

      -- Continue / Start
      map("n", "<leader>dc", function()
        dap.continue()
      end, { noremap = true, silent = true, desc = " Start or continue debugging" })

      -- Step Over
      map("n", "<leader>do", function()
        dap.step_over()
      end, { noremap = true, silent = true, desc = " Step over" })

      -- Step Into
      map("n", "<leader>di", function()
        dap.step_into()
      end, { noremap = true, silent = true, desc = " Step into function" })

      -- Step Out
      map("n", "<leader>dO", function()
        dap.step_out()
      end, { noremap = true, silent = true, desc = " Step out of function" })

      -- Continue to next breakpoint
      map("n", "<leader>dn", function()
        require("dap").continue()
      end, { noremap = true, silent = true, desc = "Continue to next breakpoint" })

      -- Continue to cursor
      map("n", "<leader>dm", function()
        require("dap").run_to_cursor()
      end, { noremap = true, silent = true, desc = "Continue to cursor" })

      -- Terminate debugging
      map("n", "<leader>dq", function()
        dap.terminate()
      end, { noremap = true, silent = true, desc = " Terminate debugging session" })

      -- Toggle DAP UI
      map("n", "<leader>du", function()
        dapui.toggle()
      end, { noremap = true, silent = true, desc = "Toggle DAP UI" })
    end,
  },
}

