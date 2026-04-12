require "nvchad.autocmds"

-- Workaround for WezTerm < 20250518 DECSLRM bug (wezterm/wezterm#5750).
-- Neovim 0.12+ detects DECSLRM support at runtime and uses scroll regions
-- for vertical splits/floats, but WezTerm's implementation incorrectly
-- clamps the left margin to screen height instead of width, causing
-- split-screen scroll corruption. Disable left-right margin mode.
vim.api.nvim_create_autocmd("TermResponse", {
  once = true,
  callback = function()
    local timer = vim.uv.new_timer()
    timer:start(100, 0, vim.schedule_wrap(function()
      io.stdout:write("\x1b[?69l") -- Disable DECLRMM
      timer:close()
    end))
  end,
})
