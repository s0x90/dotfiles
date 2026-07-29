require("nvchad.configs.lspconfig").defaults()

-- Server settings live HERE, not in plugins/lsp.lua: this file runs at
-- User FilePost (before any vim.lsp.enable/attach), while plugins/lsp.lua
-- runs at VeryLazy — after a directly-opened file's server has already
-- started. vim.lsp.config() calls also take precedence over the lsp/*.lua
-- runtime files shipped by nvim-lspconfig.

-- Go: settings + organize-imports-on-save.
vim.lsp.config("gopls", {
  on_attach = function(client, bufnr)
    -- Organize imports on save via gopls code action.
    -- Faster than spawning `goimports` and uses gopls' in-memory module graph.
    -- Formatting itself is done by conform.nvim (gofumpt) afterwards.
    local group = vim.api.nvim_create_augroup("GoOrganizeImports", { clear = false })
    vim.api.nvim_clear_autocmds { group = group, buffer = bufnr }
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = group,
      buffer = bufnr,
      callback = function()
        local params = vim.lsp.util.make_range_params(0, client.offset_encoding or "utf-16")
        params.context = { only = { "source.organizeImports" }, diagnostics = {} }
        local result = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 1000)
        for _, res in pairs(result or {}) do
          for _, action in pairs(res.result or {}) do
            if action.edit then
              vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding or "utf-16")
            end
            if action.command then
              -- Modern API (Nvim 0.11+); fall back to the deprecated
              -- function on older versions.
              if client.exec_cmd then
                client:exec_cmd(action.command)
              else
                vim.lsp.buf.execute_command(action.command)
              end
            end
          end
        end
      end,
    })
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
        -- no fieldalignment: removed in gopls v0.17 (hover shows size/offset)
        nilness = true,
        unusedparams = true,
        unusedwrite = true,
        useany = true,
      },
      staticcheck = true,
      directoryFilters = { "-.git", "-.vscode", "-.idea", "-.venv", "-node_modules", "-.zed" },
      -- No semanticTokens: NvChad's "*" on_init strips semanticTokensProvider
      -- for every server, so requesting them here is dead config. To enable,
      -- also override on_init for gopls.
    },
  },
})

-- Python: basedpyright owns navigation/diagnostics; ruff (conform) owns
-- formatting + import sorting. Only the config is registered here — the
-- server is enabled by mason-lspconfig's automatic_enable (plugins/lsp.lua),
-- because its binary is on PATH only after mason.setup() runs.
vim.lsp.config("basedpyright", {
  settings = {
    basedpyright = {
      disableOrganizeImports = true, -- ruff_organize_imports handles this
      analysis = {
        diagnosticMode = "openFilesOnly",
        typeCheckingMode = "standard", -- default "recommended" is very noisy
        autoSearchPaths = true,
      },
    },
  },
})

local servers = { "html", "cssls", "gopls", "sqls" }
vim.lsp.enable(servers)
