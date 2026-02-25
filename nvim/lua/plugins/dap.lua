return {
  {
    "mfussenegger/nvim-dap",
  },

  { "nvim-neotest/nvim-nio" },
  
  {
    "rcarriga/nvim-dap-ui",
    lazy = false,
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
    require("dapui").setup()
    end,
  },

  {
    "leoluz/nvim-dap-go",
    lazy = false,
    ft = "go",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("dap-go").setup()
    end,
  },
}
