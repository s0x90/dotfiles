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
    -- LSP keymaps live in lua/autocmds.lua (a plain LspAttach autocmd
    -- registered at startup, independent of plugin load order). Server
    -- settings live in configs/lspconfig.lua, which runs at User FilePost —
    -- before the vim.lsp.enable() call below.

    require("mason").setup {}

    -- Single allowlist: mason installs exactly these and only these attach.
    -- automatic_enable is off because it enables every mason-installed
    -- server, so stray :MasonInstall experiments would keep attaching until
    -- manually uninstalled.
    local servers = {
      "eslint",
      "lua_ls",
      "jsonls",
      "html",
      "cssls",
      "basedpyright",
      "dockerls",
      "bashls",
      "marksman",
      "gopls",
      "golangci_lint_ls",
      "sqls",
      "ts_ls",
    }
    require("mason-lspconfig").setup {
      ensure_installed = servers,
      automatic_enable = false,
    }
    -- Must run after mason.setup() puts server binaries on PATH; attaches
    -- to already-open buffers, so directly-opened files are covered too.
    vim.lsp.enable(servers)

    -- Non-LSP tools that conform.nvim (stylua, ruff) and nvim-dap (debugpy)
    -- expect from mason — mason-lspconfig's ensure_installed covers servers
    -- only. refresh() is async and fetches the registry index on a fresh
    -- machine, where get_package would otherwise fail.
    -- gofumpt is NOT here: it comes from `go install mvdan.cc/gofumpt@latest`.
    local tools = { "stylua", "ruff", "debugpy" }
    local mr = require "mason-registry"
    mr.refresh(function()
      for _, name in ipairs(tools) do
        local ok, pkg = pcall(mr.get_package, name)
        if ok and not pkg:is_installed() then
          -- Surface failures with mason's own error: a missing tool otherwise
          -- degrades silently (conform falls back to LSP formatting).
          pkg:install(nil, function(success, err)
            if not success then
              vim.schedule(function()
                vim.notify(
                  ("mason: failed to install %s (%s) — formatting/debugging degraded"):format(name, err),
                  vim.log.levels.WARN
                )
              end)
            end
          end)
        end
      end
    end)

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
      -- %s$ on the text before the cursor: col is a byte index, so grabbing
      -- a single byte with sub(col, col) lands mid-sequence on multibyte
      -- text; whitespace is always single-byte, so anchoring at the end
      -- stays correct.
      elseif col == 0 or vim.fn.getline("."):sub(1, col):match "%s$" then
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
