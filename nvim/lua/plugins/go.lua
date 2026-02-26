-- Custom Go test runner with clear PASS/FAIL visualization
local function go_test_run(cmd_args)
  -- cmd_args: e.g. {"go", "test", "-v", "./..."}
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "gotest"

  -- Open in a bottom split (30% height)
  local win_height = math.max(15, math.floor(vim.o.lines * 0.3))
  vim.cmd("botright " .. win_height .. "split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_buf_set_name(buf, "Go Test Results")

  -- Define highlight groups
  vim.api.nvim_set_hl(0, "GoTestPass", { fg = "#a6e3a1", bold = true })
  vim.api.nvim_set_hl(0, "GoTestFail", { fg = "#f38ba8", bold = true })
  vim.api.nvim_set_hl(0, "GoTestRunning", { fg = "#f9e2af", bold = true })
  vim.api.nvim_set_hl(0, "GoTestPassLine", { fg = "#a6e3a1" })
  vim.api.nvim_set_hl(0, "GoTestFailLine", { fg = "#f38ba8" })
  vim.api.nvim_set_hl(0, "GoTestSkipLine", { fg = "#94e2d5" })

  -- Set initial content
  local header = "  RUNNING TESTS: " .. table.concat(cmd_args, " ")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { header, string.rep("─", #header + 4), "" })

  -- Highlight the header
  local ns = vim.api.nvim_create_namespace("gotest")
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { end_row = 0, end_col = #header, hl_group = "GoTestRunning" })

  -- Make the buffer writable by us
  vim.bo[buf].modifiable = true

  local output_lines = {}
  local line_count = 3 -- after header + separator + blank line

  local function append_line(line)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, { line })

    -- Apply per-line highlighting
    if line:match("^%s*--- PASS") or line:match("^ok%s") then
      vim.api.nvim_buf_set_extmark(buf, ns, line_count, 0, { end_row = line_count, end_col = #line, hl_group = "GoTestPassLine" })
    elseif line:match("^%s*--- FAIL") or line:match("^FAIL%s") then
      vim.api.nvim_buf_set_extmark(buf, ns, line_count, 0, { end_row = line_count, end_col = #line, hl_group = "GoTestFailLine" })
    elseif line:match("^%s*--- SKIP") then
      vim.api.nvim_buf_set_extmark(buf, ns, line_count, 0, { end_row = line_count, end_col = #line, hl_group = "GoTestSkipLine" })
    end

    line_count = line_count + 1
    table.insert(output_lines, line)

    -- Auto-scroll to bottom if window is still valid
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_cursor(win, { line_count, 0 })
    end
  end

  -- Run the test command asynchronously
  vim.fn.jobstart(cmd_args, {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      if data then
        vim.schedule(function()
          for _, line in ipairs(data) do
            if line ~= "" then
              append_line(line)
            end
          end
        end)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.schedule(function()
          for _, line in ipairs(data) do
            if line ~= "" then
              append_line(line)
            end
          end
        end)
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then return end
        vim.bo[buf].modifiable = true

        local separator = string.rep("═", 60)
        local result_line, hl_group, notify_level

        if exit_code == 0 then
          result_line = "  ALL TESTS PASSED"
          hl_group = "GoTestPass"
          notify_level = vim.log.levels.INFO
        else
          result_line = "  TESTS FAILED (exit code " .. exit_code .. ")"
          hl_group = "GoTestFail"
          notify_level = vim.log.levels.ERROR
        end

        -- Count test results from output
        local passed, failed, skipped = 0, 0, 0
        for _, line in ipairs(output_lines) do
          if line:match("^%s*--- PASS") then passed = passed + 1 end
          if line:match("^%s*--- FAIL") then failed = failed + 1 end
          if line:match("^%s*--- SKIP") then skipped = skipped + 1 end
        end

        local summary = string.format("  Passed: %d  |  Failed: %d  |  Skipped: %d", passed, failed, skipped)

        -- Append final result block
        append_line("")
        append_line(separator)
        local result_start = line_count
        append_line(result_line)
        local result_line_text = vim.api.nvim_buf_get_lines(buf, result_start, result_start + 1, false)[1] or ""
        vim.api.nvim_buf_set_extmark(buf, ns, result_start, 0, { end_row = result_start, end_col = #result_line_text, hl_group = hl_group })
        local summary_start = line_count
        append_line(summary)
        local summary_line_text = vim.api.nvim_buf_get_lines(buf, summary_start, summary_start + 1, false)[1] or ""
        vim.api.nvim_buf_set_extmark(buf, ns, summary_start, 0, { end_row = summary_start, end_col = #summary_line_text, hl_group = hl_group })
        append_line(separator)

        -- Also update the header to reflect final state
        vim.api.nvim_buf_set_lines(buf, 0, 1, false, { result_line })
        vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { end_row = 0, end_col = #result_line, hl_group = hl_group })

        vim.bo[buf].modifiable = false

        -- Show a notification
        vim.notify(result_line:match("^%s*(.+)") .. "\n" .. summary:match("^%s*(.+)"), notify_level, {
          title = "Go Test",
        })

        -- Set buffer keymaps: q to close
        vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>bdelete<cr>", { noremap = true, silent = true })
      end)
    end,
  })
end

-- Wrapper functions for different test scopes
local function go_test()
  go_test_run({ "go", "test", "-v", "-count=1", "./..." })
end

local function go_test_func()
  -- Find the test function name under cursor using treesitter
  local ok, ts_utils = pcall(require, "nvim-treesitter.ts_utils")
  local func_name = nil

  if ok then
    local node = ts_utils.get_node_at_cursor()
    while node do
      if node:type() == "function_declaration" then
        local name_node = node:child(1)
        if name_node then
          func_name = vim.treesitter.get_node_text(name_node, 0)
        end
        break
      end
      node = node:parent()
    end
  end

  if not func_name then
    -- Fallback: use regex to find function name
    local line = vim.api.nvim_get_current_line()
    func_name = line:match("func%s+(Test%w+)")
    if not func_name then
      -- Search upward for the nearest Test function
      local cur_line = vim.fn.line(".")
      for i = cur_line, 1, -1 do
        local l = vim.fn.getline(i)
        func_name = l:match("func%s+(Test%w+)")
        if func_name then break end
      end
    end
  end

  if not func_name or not func_name:match("^Test") then
    vim.notify("No test function found at or above cursor", vim.log.levels.WARN, { title = "Go Test" })
    return
  end

  local pkg_dir = vim.fn.expand("%:p:h")
  go_test_run({ "go", "test", "-v", "-count=1", "-run", "^" .. func_name .. "$", pkg_dir })
end

local function go_test_pkg()
  local pkg_dir = vim.fn.expand("%:p:h")
  go_test_run({ "go", "test", "-v", "-count=1", pkg_dir })
end

local function go_test_file()
  local file = vim.fn.expand("%:p")
  local pkg_dir = vim.fn.expand("%:p:h")
  -- Get all test function names in the current file
  local lines = vim.fn.readfile(file)
  local test_names = {}
  for _, line in ipairs(lines) do
    local name = line:match("func%s+(Test%w+)")
    if name then
      table.insert(test_names, name)
    end
  end
  if #test_names == 0 then
    vim.notify("No test functions found in this file", vim.log.levels.WARN, { title = "Go Test" })
    return
  end
  local pattern = "^(" .. table.concat(test_names, "|") .. ")$"
  go_test_run({ "go", "test", "-v", "-count=1", "-run", pattern, pkg_dir })
end

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

    -- Go-specific keymaps (scoped to Go filetypes)
    local map = vim.keymap.set
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "go", "gomod", "gowork", "gotmpl" },
      callback = function(ev)
        local opts = { buffer = ev.buf, silent = true }

        -- Test mappings: use custom runner with clear PASS/FAIL colors
        map("n", "<leader>gt", go_test, vim.tbl_deep_extend("force", opts, { desc = "Go Test (all)" }))
        map("n", "<leader>gtf", go_test_func, vim.tbl_deep_extend("force", opts, { desc = "Go Test Function" }))
        map("n", "<leader>gtp", go_test_pkg, vim.tbl_deep_extend("force", opts, { desc = "Go Test Package" }))
        map("n", "<leader>gF", go_test_file, vim.tbl_deep_extend("force", opts, { desc = "Go Test File" }))

        -- Go tool mappings (still use go.nvim commands)
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
