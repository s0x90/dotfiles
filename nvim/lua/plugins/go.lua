return {
  "ray-x/go.nvim",
  dependencies = {
    "ray-x/guihua.lua",
    "neovim/nvim-lspconfig",
    "nvim-treesitter/nvim-treesitter",
  },
  event = "CmdlineEnter",
  ft = { "go", "gomod", "gowork", "gotmpl" },
  build = ':lua require("go.install").update_all_sync()',
  config = function()
    require("go").setup({
      -- Let lsp.lua handle gopls configuration via mason-lspconfig
      lsp_cfg = false,
      lsp_gofumpt = false, -- handled by gopls settings in lsp.lua
      lsp_keymaps = false, -- keymaps handled by lsp.lua on_attach
      lsp_codelens = false, -- handled by gopls settings in lsp.lua
      lsp_inlay_hints = { enable = false }, -- handled by gopls settings in lsp.lua

      -- Disable DAP management - keep existing dap.lua setup
      dap_debug = false,
      dap_debug_gui = false,
      dap_debug_keymap = false,

      -- Formatting: handled by conform.nvim, so disable go.nvim's own format
      lsp_document_formatting = false,

      -- Diagnostics: keep nvim default / lsp-zero handling
      diagnostic = false,

      -- Go tooling features
      goimports = "gopls",
      gofmt = "gofumpt",
      tag_transform = false,
      tag_options = "json=omitempty",
      test_runner = "go",
      verbose_tests = true,
      run_in_floaterm = false,

      -- Treesitter text objects
      textobjects = true,

      -- Icons (terminal-safe, no emoji)
      icons = { breakpoint = "●", currentpos = "→" },

      -- Disable go.nvim luasnip loading (lsp-zero already loads friendly-snippets)
      luasnip = false,
    })

    -- Go-specific tool keymaps (scoped to Go filetypes, <leader>g prefix)
    -- These do NOT conflict with lsp.lua's <leader>v prefix keymaps
    local map = vim.keymap.set
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "go", "gomod", "gowork", "gotmpl" },
      callback = function(ev)
        local opts = { buffer = ev.buf, silent = true }
        map("n", "<leader>gt", "<cmd>GoTest<cr>", vim.tbl_deep_extend("force", opts, { desc = "Go Test" }))
        map("n", "<leader>gtf", "<cmd>GoTestFunc<cr>", vim.tbl_deep_extend("force", opts, { desc = "Go Test Function" }))
        map("n", "<leader>gtp", "<cmd>GoTestPkg<cr>", vim.tbl_deep_extend("force", opts, { desc = "Go Test Package" }))
        map("n", "<leader>ga", "<cmd>GoAddTag<cr>", vim.tbl_deep_extend("force", opts, { desc = "Go Add Tags" }))
        map("n", "<leader>gra", "<cmd>GoRmTag<cr>", vim.tbl_deep_extend("force", opts, { desc = "Go Remove Tags" }))
        map("n", "<leader>gi", "<cmd>GoImpl<cr>", vim.tbl_deep_extend("force", opts, { desc = "Go Implement Interface" }))
        map("n", "<leader>gf", "<cmd>GoFillStruct<cr>", vim.tbl_deep_extend("force", opts, { desc = "Go Fill Struct" }))
        map("n", "<leader>ge", "<cmd>GoIfErr<cr>", vim.tbl_deep_extend("force", opts, { desc = "Go If Err" }))
        map("n", "<leader>gc", "<cmd>GoCoverage<cr>", vim.tbl_deep_extend("force", opts, { desc = "Go Coverage" }))
        map("n", "<leader>gl", "<cmd>GoCodeLenAct<cr>", vim.tbl_deep_extend("force", opts, { desc = "Go CodeLens Action" }))
        map("n", "<leader>gm", "<cmd>GoModTidy<cr>", vim.tbl_deep_extend("force", opts, { desc = "Go Mod Tidy" }))
      end,
    })
  end,
}
