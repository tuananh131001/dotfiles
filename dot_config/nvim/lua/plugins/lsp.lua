return {
	{
		"williamboman/mason.nvim",
		lazy = false,
		config = function()
			require("mason").setup()
		end,
	},
	{
		"williamboman/mason-lspconfig",
		lazy = false,
		opts = {
			auto_install = true,
		},
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = { "solargraph", "gopls", "ts_ls", "pyright", "rubocop" }, -- Correct LSP for TypeScript/JavaScript
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		lazy = false,
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			local lspconfig = require("lspconfig")
			lspconfig.solargraph.setup({
				capabilities = capabilities,
			})
			lspconfig.lua_ls.setup({})
			lspconfig.pyright.setup({})
			lspconfig.rubocop.setup({
				capabilities = capabilities,
			})
			lspconfig.gopls.setup({
				capabilities = capabilities,
				settings = {
					gopls = {
						analyses = {
							unusedparams = true,
						},
						staticcheck = true,
					},
				},
			})
			lspconfig.ts_ls.setup({
				capabilities = capabilities,
			})
		end,
		vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation LSP" }),
		vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Action LSP" }),
		vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, { desc = "Goto Definition LSP" }),
		vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, { desc = "Goto References LSP" }),
		vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, { desc = "Format File LSP" }),
		vim.keymap.set("n", "<leader>gc", vim.lsp.buf.implementation, { desc = "Goto Implementation LSP" }),
		vim.keymap.set("n", "<leader>grn", vim.lsp.buf.rename, { desc = "Rename LSP" }),
	},
}
