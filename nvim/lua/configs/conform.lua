local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    -- Go: only run gofumpt via conform. Import organization is handled by
    -- gopls' `source.organizeImports` code action on save (see plugins/lsp.lua),
    -- which is much faster than spawning `goimports` (no module graph rescan).
    go = { "gofumpt" },
    -- css = { "prettier" },
    -- html = { "prettier" },
  },

  format_on_save = {
    -- These options will be passed to conform.format()
    -- 3000ms gives slow formatters (e.g. first-run gofumpt on cold caches)
    -- enough headroom without blocking the editor for too long.
    timeout_ms = 3000,
    lsp_fallback = true,
  },
}

return options
