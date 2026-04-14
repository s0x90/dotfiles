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

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "vim", "lua", "luadoc", "vimdoc",
        "html", "css",
      },
    },
  },
  {
  "nvim-tree/nvim-tree.lua",
  opts = {
    view = {
      width = 30,
    },
    on_attach = function(bufnr)
      local api = require "nvim-tree.api"

      -- apply all default keymaps first
      api.config.mappings.default_on_attach(bufnr)

      local function opts(desc)
        return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
      end

      -- override <CR> with nil-guard to prevent E5108 on empty lines
      vim.keymap.set("n", "<CR>", function()
        local node = api.tree.get_node_under_cursor()
        if node then
          api.node.open.edit(node)
        end
      end, opts("Open"))

      -- same guard for double-click and 'o' which use the same function
      vim.keymap.set("n", "o", function()
        local node = api.tree.get_node_under_cursor()
        if node then
          api.node.open.edit(node)
        end
      end, opts("Open"))

    end,
  },
},
}
