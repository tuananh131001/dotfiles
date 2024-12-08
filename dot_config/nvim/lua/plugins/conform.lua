return {
	"stevearc/conform.nvim",
	opts = {
		format = {
			timeout_ms = 3000,
			async = false,
			quiet = false,
		},
		formatters_by_ft = {
			ruby = { "rubocop" },
			html = { "prettierhtml" },
			python = { "isort", "black" },
			json = { "jq" },
			eruby = { "erb_format" },
			javascript = { "biome" },
      typescript = { { "prettierd", "prettier" } },
			xml = { "xmllint" },
			lua = { "stylua" },
			go = { "gofmt" },
		},
		formatters = {
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
