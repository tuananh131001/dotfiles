return {
	"stevearc/conform.nvim",
	opts = {
		formatters_by_ft = {
			ruby = { "rubocop" },
			html = { "prettierhtml" },
			json = { "jq" },
			eruby = { "erb_format" },
			javascript = { "biome" },
			xml = { "xmllint" },
			lua = { "stylua" },
		},
		formatters = {
			rubocop = {
				options = { ignore_errors = true },
				args = { "--server", "--auto-correct-all", "--force-exclusion", "--stderr", "--stdin", "$FILENAME" },
			},
			prettier = {
				options = {
					ft_parsers = {
						eruby = "html",
					},
				},
			},
			prettierhtml = {
				command = "prettier",
				args = { "--parser", "html", "--print-width", "200" },
			},
		},
		-- Add format on save
		format_on_save = {
			timeout_ms = 3000,
			lsp_fallback = true,
		},
	},
	config = function(_, opts)
		require("conform").setup(opts)
	end,
}
