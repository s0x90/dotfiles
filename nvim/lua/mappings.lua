require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")


map("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
map("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
map("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
map("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" }) -- close current split window

map("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
map("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
map("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
map("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
map("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab

-- telescope map bindings
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files in cwd" })
map("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Fuzzy find recent files" })
map("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })
map("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor in cwd" })

-- Go (go.nvim) keybindings
map("n", "<leader>gt", "<cmd>GoTest<cr>", { desc = "Go: Run tests" })
map("n", "<leader>gf", "<cmd>GoTestFunc<cr>", { desc = "Go: Test current function" })
map("n", "<leader>gF", "<cmd>GoTestFile<cr>", { desc = "Go: Test current file" })
map("n", "<leader>gc", "<cmd>GoCoverage<cr>", { desc = "Go: Toggle coverage" })
map("n", "<leader>ga", "<cmd>GoAlt!<cr>", { desc = "Go: Alternate test/source" })
map("n", "<leader>ge", "<cmd>GoIfErr<cr>", { desc = "Go: Add if err" })
map("n", "<leader>gj", "<cmd>GoAddTag json<cr>", { desc = "Go: Add json tags" })
map("n", "<leader>gJ", "<cmd>GoRmTag json<cr>", { desc = "Go: Remove json tags" })
map("n", "<leader>gi", "<cmd>GoImpl<cr>", { desc = "Go: Implement interface" })
map("n", "<leader>gr", "<cmd>GoGenReturn<cr>", { desc = "Go: Generate return" })
map("n", "<leader>gd", "<cmd>GoDoc<cr>", { desc = "Go: Show doc" })
map("n", "<leader>gl", "<cmd>GoLint<cr>", { desc = "Go: Lint" })
map("n", "<leader>gm", "<cmd>GoModTidy<cr>", { desc = "Go: Mod tidy" })
