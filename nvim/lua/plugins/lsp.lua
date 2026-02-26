return {
  "VonHeikemen/lsp-zero.nvim",
  event = "VeryLazy",
  branch = "v2.x",
  dependencies = {
    -- LSP Support
    { "neovim/nvim-lspconfig" }, -- Required
    { -- Optional
      "williamboman/mason.nvim",
    },
    { "williamboman/mason-lspconfig.nvim" }, -- Optional

    -- Autocompletion
    { "hrsh7th/nvim-cmp" }, -- Required
    { "hrsh7th/cmp-nvim-lsp" }, -- Required
    { "L3MON4D3/LuaSnip" }, -- Required
    { "rafamadriz/friendly-snippets" },
    { "hrsh7th/cmp-buffer" },
    { "hrsh7th/cmp-path" },
    { "hrsh7th/cmp-cmdline" },
    { "saadparwaiz1/cmp_luasnip" },
  },
  config = function()
    local lsp = require "lsp-zero"
    local map = vim.keymap.set

    lsp.on_attach(function(client, bufnr)
      local opts = { buffer = bufnr, remap = false }

      map("n", "gr", function()
        vim.lsp.buf.references()
      end, vim.tbl_deep_extend("force", opts, { desc = "LSP Goto Reference" }))
      map("n", "gd", function()
        vim.lsp.buf.definition()
      end, vim.tbl_deep_extend("force", opts, { desc = "LSP Goto Definition" }))
      map("n", "K", function()
        vim.lsp.buf.hover()
      end, vim.tbl_deep_extend("force", opts, { desc = "LSP Hover" }))
      map("n", "<leader>vws", function()
        vim.lsp.buf.workspace_symbol()
      end, vim.tbl_deep_extend("force", opts, { desc = "LSP Workspace Symbol" }))
      map("n", "<leader>vd", function()
        vim.diagnostic.setloclist()
      end, vim.tbl_deep_extend("force", opts, { desc = "LSP Show Diagnostics" }))
      map("n", "[d", function()
        vim.diagnostic.jump { count = -1 }
      end, vim.tbl_deep_extend("force", opts, { desc = "Previous Diagnostic" }))
      map("n", "]d", function()
        vim.diagnostic.jump { count = 1 }
      end, vim.tbl_deep_extend("force", opts, { desc = "Next Diagnostic" }))
      map("n", "<leader>vca", function()
        vim.lsp.buf.code_action()
      end, vim.tbl_deep_extend("force", opts, { desc = "LSP Code Action" }))
      map("n", "<leader>vrr", function()
        vim.lsp.buf.references()
      end, vim.tbl_deep_extend("force", opts, { desc = "LSP References" }))
      map("n", "<leader>vrn", function()
        vim.lsp.buf.rename()
      end, vim.tbl_deep_extend("force", opts, { desc = "LSP Rename" }))
      map("i", "<C-h>", function()
        vim.lsp.buf.signature_help()
      end, vim.tbl_deep_extend("force", opts, { desc = "LSP Signature Help" }))
    end)

    require("mason").setup {}
    require("mason-lspconfig").setup {
      ensure_installed = {
        "eslint",
        "kotlin_lsp",
        "lua_ls",
        "jsonls",
        "html",
        "pylsp",
        "dockerls",
        "bashls",
        "marksman",
        "gopls",
      },
      handlers = {
        lsp.default_setup,
        lua_ls = function()
          local lua_opts = lsp.nvim_lua_ls()
          require("lspconfig").lua_ls.setup(lua_opts)
        end,
        gopls = function()
          require("lspconfig").gopls.setup {
            on_attach = function(client, bufnr)
              lsp.default_keymaps { buffer = bufnr }
            end,
            settings = {
              gopls = {
                gofumpt = true,
                codelenses = {
                  gc_details = false,
                  generate = true,
                  regenerate_cgo = true,
                  run_govulncheck = true,
                  test = true,
                  tidy = true,
                  upgrade_dependency = true,
                  vendor = true,
                },
                hints = {
                  assignVariableTypes = true,
                  compositeLiteralFields = true,
                  compositeLiteralTypes = true,
                  constantValues = true,
                  functionTypeParameters = true,
                  parameterNames = true,
                  rangeVariableTypes = true,
                },
                analyses = {
                  fieldalignment = true,
                  nilness = true,
                  unusedparams = true,
                  unusedwrite = true,
                  useany = true,
                },
                staticcheck = true,
                directoryFilters = { "-.git", "-.vscode", "-.idea", "-.venv", "-node_modules", ".zed" },
                semanticTokens = true,
              },
            },
          }
        end,
      },
    }

    local cmp_action = require("lsp-zero").cmp_action()
    local cmp = require "cmp"
    local cmp_select = { behavior = cmp.SelectBehavior.Select }

    require("luasnip.loaders.from_vscode").lazy_load()

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

    cmp.setup {
      snippet = {
        expand = function(args)
          require("luasnip").lsp_expand(args.body)
        end,
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
        ["<C-f>"] = cmp_action.luasnip_jump_forward(),
        ["<C-b>"] = cmp_action.luasnip_jump_backward(),
        ["<Tab>"] = cmp_action.luasnip_supertab(),
        ["<S-Tab>"] = cmp_action.luasnip_shift_supertab(),
      },
    }
  end,
}
