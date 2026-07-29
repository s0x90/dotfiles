require "nvchad.autocmds"

-- LSP navigation keymaps. A plain LspAttach autocmd registered at startup,
-- NOT inside a lazy-loaded plugin: VeryLazy fires too late for servers that
-- attach to a directly-opened file at User FilePost (gopls & co. via
-- configs/lspconfig.lua) — their LspAttach event would be missed.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspKeymaps", {}),
  callback = function(ev)
    local map = vim.keymap.set
    local opts = { buffer = ev.buf, remap = false }

    map("n", "gr", function()
      vim.lsp.buf.references()
    end, vim.tbl_deep_extend("force", opts, { desc = "LSP Goto Reference" }))
    map("n", "gd", function()
      vim.lsp.buf.definition()
    end, vim.tbl_deep_extend("force", opts, { desc = "LSP Goto Definition" }))
    map("n", "K", function()
      vim.lsp.buf.hover { border = "rounded" }
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
      vim.lsp.buf.signature_help { border = "rounded" }
    end, vim.tbl_deep_extend("force", opts, { desc = "LSP Signature Help" }))
  end,
})

-- Workaround for WezTerm < 20250518 DECSLRM bug (wezterm/wezterm#5750).
-- Neovim 0.12+ detects DECSLRM support at runtime and uses scroll regions
-- for vertical splits/floats, but WezTerm's implementation incorrectly
-- clamps the left margin to screen height instead of width, causing
-- split-screen scroll corruption. Disable left-right margin mode.
vim.api.nvim_create_autocmd("TermResponse", {
  once = true,
  callback = function()
    local timer = vim.uv.new_timer()
    timer:start(
      100,
      0,
      vim.schedule_wrap(function()
        io.stdout:write "\x1b[?69l" -- Disable DECLRMM
        timer:close()
      end)
    )
  end,
})
