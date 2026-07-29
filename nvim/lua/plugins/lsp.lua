return {
  "hrsh7th/nvim-cmp",
  event = "VeryLazy",
  dependencies = {
    -- LSP Support
    { "neovim/nvim-lspconfig" },
    { "williamboman/mason.nvim" },
    { "williamboman/mason-lspconfig.nvim" },

    -- Autocompletion
    { "hrsh7th/cmp-nvim-lsp" },
    { "L3MON4D3/LuaSnip" },
    { "rafamadriz/friendly-snippets" },
    { "hrsh7th/cmp-buffer" },
    { "hrsh7th/cmp-path" },
    { "hrsh7th/cmp-cmdline" },
    { "saadparwaiz1/cmp_luasnip" },
  },
  config = function(_, opts)
    -- LSP keymaps live in lua/autocmds.lua (plain LspAttach autocmd, loaded
    -- at startup) so they cover servers that attach before this VeryLazy
    -- plugin loads. Server settings live in configs/lspconfig.lua for the
    -- same reason.

    require("mason").setup {}
    require("mason-lspconfig").setup {
      ensure_installed = {
        "eslint",
        "kotlin_lsp",
        "lua_ls",
        "jsonls",
        "html",
        "basedpyright",
        "dockerls",
        "bashls",
        "marksman",
        "gopls",
      },
      -- v2 auto-enables EVERY mason-installed server; keep stale python
      -- servers and the ruff LSP (binary used only by conform) from attaching.
      automatic_enable = {
        exclude = { "pylsp", "pyright", "ruff" },
      },
    }

    local cmp = require "cmp"
    local luasnip = require "luasnip"
    local cmp_select = { behavior = cmp.SelectBehavior.Select }

    require("luasnip.loaders.from_vscode").lazy_load()

    -- Snippet-aware mappings (former lsp-zero cmp_action helpers, inlined
    -- verbatim when lsp-zero was dropped — it provided nothing else).
    local function luasnip_jump(dir)
      return cmp.mapping(function(fallback)
        if luasnip.jumpable(dir) then
          luasnip.jump(dir)
        else
          fallback()
        end
      end, { "i", "s" })
    end

    local supertab = cmp.mapping(function(fallback)
      local col = vim.fn.col "." - 1

      if cmp.visible() then
        cmp.select_next_item(cmp_select)
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      elseif col == 0 or vim.fn.getline("."):sub(col, col):match "%s" then
        fallback()
      else
        cmp.complete()
      end
    end, { "i", "s" })

    local shift_supertab = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item(cmp_select)
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" })

    -- `/` cmdline setup.
    cmp.setup.cmdline("/", {
      mapping = cmp.mapping.preset.cmdline(),
      sources = {
        { name = "buffer" },
      },
    })

    -- `:` cmdline setup.
    cmp.setup.cmdline(":", {
      mapping = cmp.mapping.preset.cmdline(),
      sources = cmp.config.sources({
        { name = "path" },
      }, {
        {
          name = "cmdline",
          option = {
            ignore_cmds = { "Man", "!" },
          },
        },
      }),
    })

    -- Defining an explicit `config` suppresses lazy.nvim's auto-setup, which
    -- previously applied NvChad's merged spec opts (base46-themed menu,
    -- icon formatting, extra sources). Consecutive cmp.setup calls merge, so
    -- apply NvChad's opts first, then override with ours — same effective
    -- order as before this file owned the nvim-cmp spec.
    cmp.setup(opts)

    cmp.setup {
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
      window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
      },
      sources = {
        { name = "nvim_lsp" },
        { name = "luasnip", keyword_length = 2 },
        { name = "buffer", keyword_length = 3 },
        { name = "path" },
      },
      mapping = cmp.mapping.preset.insert {
        ["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
        ["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
        ["<CR>"] = cmp.mapping.confirm { select = true },
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-f>"] = luasnip_jump(1),
        ["<C-b>"] = luasnip_jump(-1),
        ["<Tab>"] = supertab,
        ["<S-Tab>"] = shift_supertab,
      },
    }
  end,
}
