
return {
	"rmagatti/auto-session",
  event = "VimEnter",
  cmd = { "AutoSession save", "AutoSession restore", "AutoSession delete" },
	config = function()
		local auto_session = require("auto-session")

		auto_session.setup({
			auto_restore_enabled = true,
			auto_session_suppress_dirs = { "~/", "~/Dev/", "~/Downloads", "~/Documents", "~/Desktop/" },
			pre_save_cmds = {
				function()
					-- Close nvim-tree before saving session to prevent
					-- restoring a stale tree buffer with no backing node data
					local ok, api = pcall(require, "nvim-tree.api")
					if ok then
						api.tree.close()
					end
				end,
			},
		})

    local keymap = vim.keymap

  	keymap.set("n", "<leader>sr", "<cmd>AutoSession restore<CR>", { desc = "Restore session for cwd" }) -- restore last workspace session for current directory
		keymap.set("n", "<leader>sw", "<cmd>AutoSession save<CR>", { desc = "Save session for auto session root dir" }) -- save workspace session for current working directory

	end,
}
