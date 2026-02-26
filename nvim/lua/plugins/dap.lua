return {
  {
    "rcarriga/nvim-dap-ui",
    lazy = false,
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup({
        layouts = {
          {
            elements = {
              { id = "scopes", size = 0.5 },
              { id = "breakpoints", size = 0.2 },
              { id = "stacks", size = 0.2 },
              { id = "watches", size = 0.1 },
            },
            size = 40,
            position = "left",
          },
          {
            elements = {
              { id = "repl", size = 0.5 },
              { id = "console", size = 0.5 },
            },
            size = 10,
            position = "bottom",
          },
        },
      })

 -- Auto open/close
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end

      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end

      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },

  {
    "leoluz/nvim-dap-go",
    ft = "go",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      local dap = require("dap")

      require("dap-go").setup({
        delve = {
          path = vim.fn.exepath("dlv"),
        },
        dap_configurations = {
          {
            type = "go",
            name = "Debug test (module root)",
            request = "launch",
            mode = "test",
            program = "${fileDirname}",
            --cwd = "${fileDirname}",
            cwd = require("lspconfig.util").root_pattern("go.mod")(vim.fn.getcwd()),
            args = {"-test.run", vim.fn.expand("<cword>")}, -- automatically picks test under cursor
          },
        },
      })
      --[[dap.configurations.go = {
        {
          type = "go",
          name = "Debug current test",
          request = "launch",
          mode = "test",
          program = "${fileDirname}",  -- directory of the current file
          cwd = lsp_util.root_pattern("go.mod")(vim.fn.getcwd()), -- project root
          args = {"-test.run", vim.fn.expand("<cword>")}, -- test function under cursor
        },
      }]]

      local map = vim.keymap.set
      map("n", "<F5>", function() require("dap-go").debug_test() end, { desc = "Debug Test" })
      map("n", "<F9>", function() dap.toggle_breakpoint() end, { desc = "Toggle Breakpoint" })
      map("n", "<F10>", function() dap.step_over() end, { desc = "Step Over" })
      map("n", "<F11>", function() dap.step_into() end, { desc = "Step Into" })
      map("n", "<F12>", function() dap.step_out() end, { desc = "Step Out" })
      map("n", "<leader>dr", function() dap.repl.open() end, { desc = "Open REPL" })

      vim.o.signcolumn = "yes"
      vim.fn.sign_define("DapBreakpoint", {
        text = "●", -- use a normal dot instead of emoji for max compatibility
        texthl = "DiagnosticSignError",
        linehl = "",
        numhl = "",
      })

     vim.fn.sign_define("DapStopped", {
        text = "→",
        texthl = "DiagnosticSignInfo",
        linehl = "",
        numhl = "",
     })

     vim.fn.sign_define("DapBreakpointRejected", {
        text = "◌",
        texthl = "DiagnosticSignHint",
        linehl = "",
        numhl = "",
     })

    end,
  },
  {
    "theHamsta/nvim-dap-virtual-text",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("nvim-dap-virtual-text").setup()
    end,
  }
}
