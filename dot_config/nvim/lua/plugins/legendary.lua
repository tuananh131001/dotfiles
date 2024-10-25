return {
	{
		"mrjones2014/legendary.nvim",
		cond = not vim.g.vscode,
		priority = 10000,
		lazy = false,
		dependencies = { "kkharji/sqlite.lua" },
		keys = {
			{ "<c-p>", "<cmd>Legendary<cr>", mode = { "n", "v" } },
		},
		opts = {
			extensions = {
				lazy_nvim = true,
			},
			commands = {
				{
					":FormatFile",
					function()
            require('conform').format()
					end,
					desc = "Format file",
				},
				{
					":CopyFileName",
					function()
						vim.cmd("let @+ = expand('%')")
						vim.notify("Copied file name to clipboard")
					end,
					desc = "CopyFileName",
				},
				{
					":CopyAbsoluteFilePath",
					function()
						vim.cmd("let @+ = expand('%:p')")
						vim.notify("Copied ABSOLUTE file path to clipboard")
					end,
					desc = "CopyAbsoluteFilePath",
				},
				{
					":CopyRelativePathWithCurrentLine",
					function()
						local path = vim.fn.expand("%:p:.")
						local current_line = vim.fn.line(".")

						vim.fn.setreg("+", path .. ":" .. current_line)
						vim.notify("Copied RELATIVE file path with current LINE to clipboard")
					end,
					desc = "CopyRelativePathWithCurrentLine",
				},
				{
					":CopyRelativeFilePath",
					function()
						vim.cmd("let @+ = expand('%:p:.')")
						vim.notify("Copied RELATIVE file path to clipboard")
					end,
					desc = "CopyRelativeFilePath",
				},
				{
					":Rspec",
					function()
						local path = vim.fn.expand("%:p:.")
						local current_line = vim.fn.line(".")

						vim.fn.setreg("+", "bundle exec rspec " .. path .. ":" .. current_line)
						vim.notify("Copied RSPEC")
					end,
					desc = "CopyRelativePathWithCurrentLine",
				},
				{
					":DisableAutoformat",
					function()
						vim.g.autoformat = false
					end,
					desc = "DisableAutoformat",
				},
				{
					":EnableAutoformat",
					function()
						vim.g.autoformat = true
					end,
					desc = "EnableAutoformat",
				},
				{
					":ToggleAutoformat",
					function()
						vim.g.autoformat = not vim.g.autoformat
					end,
					desc = "ToggleAutoformat",
				},
			},
		},
	},
}
