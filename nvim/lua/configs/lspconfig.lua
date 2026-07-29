require("nvchad.configs.lspconfig").defaults()

-- Server settings live HERE, not in plugins/lsp.lua: this file runs at
-- User FilePost, before plugins/lsp.lua (VeryLazy) calls vim.lsp.enable,
-- so every config is registered before any server starts. vim.lsp.config()
-- calls also take precedence over the lsp/*.lua runtime files shipped by
-- nvim-lspconfig.

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
        -- Build params from bufnr, not the current window: on :wa this
        -- autocmd fires for buffers that aren't in the focused window, and
        -- make_range_params(0, ...) would target the wrong file.
        local params = {
          textDocument = vim.lsp.util.make_text_document_params(bufnr),
          range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
          context = { only = { "source.organizeImports" }, diagnostics = {} },
        }
        local result = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 1000)
        if not result then
          -- notify_once: on a cold gopls cache every save times out for a
          -- while; one warning is signal, one per save is noise.
          vim.notify_once("gopls: organize imports timed out (cold cache?)", vim.log.levels.WARN)
          return
        end
        for _, res in pairs(result) do
          if res.err then
            vim.notify("gopls organize imports: " .. res.err.message, vim.log.levels.WARN)
          end
          for _, action in pairs(res.result or {}) do
            -- Edits only: executing a command here would resolve async,
            -- landing after the write (and after conform's format pass) and
            -- leaving the just-saved buffer modified. gopls returns
            -- organizeImports as an edit when the client supports
            -- workspace edits, which Neovim does.
            if action.edit then
              vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding or "utf-16")
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
-- formatting + import sorting. Only the config is registered here — all
-- servers are enabled in plugins/lsp.lua, because their binaries are on
-- PATH only after mason.setup() runs.
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
