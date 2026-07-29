return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },
  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "vim",
        "lua",
        "luadoc",
        "vimdoc",
        "html",
        "css",
        "python",
      },
    },
    -- On the `main`-branch rewrite, setup() ignores ensure_installed — install
    -- the parsers explicitly so the list above is actually declarative.
    -- Only missing ones: install() on already-present parsers can still kick
    -- off async update/compile jobs at startup after revision bumps.
    config = function(_, opts)
      require("nvim-treesitter").setup(opts)
      local installed = require("nvim-treesitter.config").get_installed "parsers"
      local missing = vim.tbl_filter(function(lang)
        return not vim.tbl_contains(installed, lang)
      end, opts.ensure_installed)
      if #missing > 0 then
        require("nvim-treesitter").install(missing)
      end
    end,
  },
}
