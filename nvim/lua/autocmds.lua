require "nvchad.autocmds"

-- LSP navigation keymaps. A plain LspAttach autocmd registered at startup —
-- independent of plugin load order, so it catches every server no matter
-- when it attaches.
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

-- `autoread` (set in options.lua) only reloads a buffer when something runs
-- `:checktime` — it does not poll. Without this autocmd a buffer goes stale as
-- soon as anything writes the file outside nvim (the Claude Code CLI shelling
-- out to gofumpt, sed, git checkout…), and the next `:w` silently clobbers
-- those changes with the stale contents.
local checktime_failed = false

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "TermLeave" }, {
  group = vim.api.nvim_create_augroup("UserCheckTime", {}),
  callback = function()
    -- `:checktime` cannot reload a buffer from inside an autocmd callback
    -- (textlock), so it has to be deferred to the main loop — calling it
    -- directly here silently does nothing. It also errors in command-line mode.
    -- No buftype guard: `:checktime` is global and skips non-file buffers
    -- itself, and gating on the current buffer would disable reloads exactly
    -- while the cursor sits in the Claude terminal split.
    vim.schedule(function()
      if vim.fn.mode() == "c" then
        return
      end
      -- pcall so a persistent failure can't spam an error on every CursorHold,
      -- but latch a single notification: this autocmd is the only thing keeping
      -- a stale buffer from clobbering external edits on the next `:w`, so it
      -- must not fail silently.
      local ok, err = pcall(vim.cmd.checktime)
      if not ok and not checktime_failed then
        checktime_failed = true
        vim.notify("checktime failed; external file reloads are OFF: " .. tostring(err), vim.log.levels.ERROR)
      end
    end)
  end,
  desc = "Reload buffers changed on disk (Claude Code CLI, external formatters)",
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
