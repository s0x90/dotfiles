return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
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

  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },
  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, conf)
      conf.defaults.mappings.i = {
        ["<C-n>"] = require("telescope.actions").move_selection_next,
        ["<C-j>"] = require("telescope.actions").move_selection_previous,
      }

     -- or 
     -- table.insert(conf.defaults.mappings.i, your table)
      return conf
    end,

  },
  {
  "nvim-tree/nvim-tree.lua",
  opts = {
    view = {
      width = 30,  -- decrease to whatever you want
    },
  },
},
}
