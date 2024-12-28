return {
	{
		"neovim/nvim-lspconfig",
		---@class PluginLspOpts
		opts = {
			---@type lspconfig.options
			servers = {
				ruby_lsp = {
					enabled = false,
				},
				solargraph = {
					enabled = lsp == "solargraph",
				},
			},
			inlay_hints = { enabled = false },
		},
	},
}
