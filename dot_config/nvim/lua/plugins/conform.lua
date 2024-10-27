return {
	"stevearc/conform.nvim",
	opts = {
		formatters_by_ft = {
			ruby = { "rubocop" },
			html = { "prettierhtml" },
      python = { "black" },
			json = { "jq" },
			eruby = { "erb_format" },
			javascript = { "biome" },
			xml = { "xmllint" },
			lua = { "stylua" },
      go = { "gofmt" }
		},
		formatters = {
			rubocop = {
				options = { ignore_errors = true },
				args = { "--server", "--autocorrect-all", "--force-exclusion", "--stderr", "--stdin", "$FILENAME" },
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
	},
	config = function(_, opts)
		require("conform").setup(opts)
	end,
}
