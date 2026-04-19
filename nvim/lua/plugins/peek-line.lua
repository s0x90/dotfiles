-- Peek truncated line in a Snacks.win floating popup
-- When nowrap is set and a line extends beyond the visible area (e.g. covered
-- by neominimap), this lets you view the full line content in a popup.
-- The line is editable — changes are written back on close.
return {
  "folke/snacks.nvim",
  keys = {
    {
      "<leader>pl",
      function()
        local line = vim.api.nvim_get_current_line()
        local src_buf = vim.api.nvim_get_current_buf()
        local src_lnum = vim.api.nvim_win_get_cursor(0)[1]
        local wininfo = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
        local text_width = math.max(1, wininfo.width - wininfo.textoff - vim.wo.sidescrolloff)

        if vim.fn.strdisplaywidth(line) <= text_width then
          vim.notify("Line is not truncated", vim.log.levels.INFO)
          return
        end

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })

        local ft = vim.bo.filetype
        if ft and ft ~= "" then
          vim.bo[buf].filetype = ft
        end

        local win_width = math.min(math.floor(vim.o.columns * 0.8), 120)
        local wrapped_height = math.ceil(vim.fn.strdisplaywidth(line) / win_width) + 1

        local win = Snacks.win({
          buf = buf,
          width = win_width,
          height = math.min(wrapped_height, math.floor(vim.o.lines * 0.4)),
          position = "float",
          border = {
            { "╭", "NvimTreeWinSeparator" },
            { "─", "NvimTreeWinSeparator" },
            { "╮", "NvimTreeWinSeparator" },
            { "│", "NvimTreeWinSeparator" },
            { "╯", "NvimTreeWinSeparator" },
            { "─", "NvimTreeWinSeparator" },
            { "╰", "NvimTreeWinSeparator" },
            { "│", "NvimTreeWinSeparator" },
          },
          title = " Peek Line (editable) ",
          title_pos = "center",
          wo = { wrap = true, linebreak = true },
          bo = { modifiable = true, buftype = "nofile" },
          keys = {
            q = "close",
            ["<Esc>"] = "close",
          },
        })

        -- Block <CR> to enforce single-line editing
        vim.keymap.set({ "n", "i" }, "<CR>", "<NOP>", { buffer = buf, silent = true })

        -- Write edited content back to the original buffer on close
        local original = line
        win:on("WinClosed", function()
          if not vim.api.nvim_buf_is_valid(src_buf) or not vim.api.nvim_buf_is_loaded(src_buf) then
            return
          end

          local ok, lines = pcall(vim.api.nvim_buf_get_lines, buf, 0, -1, false)
          if not ok then return end
          local new_line = lines[1] or ""

          if new_line == original then return end

          local line_count = vim.api.nvim_buf_line_count(src_buf)
          if src_lnum < 1 or src_lnum > line_count then return end

          -- Verify source line hasn't changed while popup was open
          local current = vim.api.nvim_buf_get_lines(src_buf, src_lnum - 1, src_lnum, false)[1]
          if current ~= original then
            vim.notify("Source line changed while popup was open, skipping write-back", vim.log.levels.WARN)
            return
          end

          pcall(vim.api.nvim_buf_set_lines, src_buf, src_lnum - 1, src_lnum, false, { new_line })
        end)
      end,
      desc = "Peek truncated line",
    },
  },
}
