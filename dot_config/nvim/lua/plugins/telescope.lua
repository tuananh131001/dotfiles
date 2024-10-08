return {
  {
	"nvim-telescope/telescope.nvim",
	branch = "0.1.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		"nvim-tree/nvim-web-devicons",
		"folke/todo-comments.nvim",
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")

		telescope.setup({
			defaults = {
				path_display = { "smart" },
				reviewer = true,
				layout_config = {
					horizontal = {
						preview_cutoff = 1,
					},
				},
				mappings = {
					i = {
						["<C-k>"] = actions.move_selection_previous, -- move to prev result
						["<C-j>"] = actions.move_selection_next, -- move to next result
						["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
					},
				},
			},
		})

		telescope.load_extension("fzf")

		-- set keymaps
		local keymap = vim.keymap -- for conciseness
		local builtin = require("telescope.builtin")

		keymap.set("n", "<Space>ff", "<cmd>Telescope find_files<cr>", { desc = "[F]ind [F]ind files in cwd" })
		keymap.set("n", "<Space>fp", "<cmd>Telescope spell_suggest<cr>", { desc = "[F]ind Spell [S]uggest" })
		keymap.set("n", "<Space>fr", "<cmd>Telescope oldfiles<cr>", { desc = "[F]ind [R]ecent files" })
		keymap.set("n", "<Space>sp", "<cmd>Telescope live_grep<cr>", { desc = "[F]ind [S]tring in cwd" })
		keymap.set("n", "<Space>fb", builtin.buffers, { desc = "[ ] Find Existing Buffers" })
		keymap.set("n", "<Space>fg", "<cmd>Telescope git_files<cr>", { desc = "[F]ind [G]it files" })
		keymap.set("n", "<Space>fd", builtin.diagnostics, { desc = "[F]ind [D]iagnostics" })
		keymap.set(
			"n",
			"<Space>gs",
			"<cmd>Telescope grep_string<cr>",
			{ desc = "[F]ind String Under [C]ursor in CMD" }
		)
		keymap.set("n", "<Space>ft", "<cmd>TodoTelescope<cr>", { desc = "[F]ind [T]odos" })
		keymap.set("n", "<Space>fk", builtin.keymaps, { desc = "[F]ind [K]eymaps" })

		-- Slightly advanced example of overriding default behavior and theme
		keymap.set("n", "<Space>/", function()
			-- You can pass additional configuration to Telescope to change the theme, layout, etc.
			builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
				winblend = 10,
				previewer = false,
			}))
		end, { desc = "[/] Fuzzily search in current buffer" })

		-- Shortcut for searching your Neovim configuration files
		keymap.set("n", "<Space>fn", function()
			builtin.find_files({ cwd = vim.fn.stdpath("config") })
		end, { desc = "[F]ind [N]eovim Files" })
	end,
  }
}
