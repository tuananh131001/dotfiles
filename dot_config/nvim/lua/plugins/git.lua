return {
	{
		"ruifm/gitlinker.nvim",
		requires = "nvim-lua/plenary.nvim",
		config = function()
			require("gitlinker").setup({
				-- No need for default mappings
				mappings = nil,
			})

			-- Keybindings for gitlinker
			vim.keymap.set("n", "<Space>gy", function()
				require("gitlinker").get_buf_range_url("n") -- Copy link at current line
			end, { desc = "Copy Git link at current line" })

			vim.keymap.set("n", "<Space>gY", function()
				require("gitlinker").get_repo_url({ print_url = false }) -- Copy link to the whole file
			end, { desc = "Copy Git link for entire file" })
		end,
	},
}
