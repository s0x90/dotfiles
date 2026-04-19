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
        local text_width = wininfo.width - wininfo.textoff - vim.wo.sidescrolloff

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

        -- Write edited content back to the original buffer on close
        local original = line
        win:on("WinClosed", function()
          local ok, lines = pcall(vim.api.nvim_buf_get_lines, buf, 0, -1, false)
          if not ok then return end
          local new_line = table.concat(lines, "")
          if new_line ~= original then
            vim.api.nvim_buf_set_lines(src_buf, src_lnum - 1, src_lnum, false, { new_line })
          end
        end)
      end,
      desc = "Peek truncated line",
    },
  },
}
