return {
	{
		"neovim/nvim-lspconfig",
		config = function()
			local nvim_lsp = require("lspconfig")

			-- Set space as the leader key
			vim.g.mapleader = " "

			-- Use an on_attach function to only map the following keys
			-- after the language server attaches to the current buffer
			local on_attach = function(client, bufnr)
				local function buf_set_keymap(...)
					vim.api.nvim_buf_set_keymap(bufnr, ...)
				end
				local function buf_set_option(...)
					vim.api.nvim_buf_set_option(bufnr, ...)
				end

				--Enable completion triggered by <c-x><c-o>
				buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")

				-- Mappings.
				local opts = { noremap = true, silent = true }
				-- See `:help vim.lsp.*` for documentation on any of the below functions
				buf_set_keymap("n", "<space>gD", "<Cmd>lua vim.lsp.buf.declaration()<CR>", opts)
				buf_set_keymap("n", "<space>gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", opts)
				buf_set_keymap("n", "<space>K", "<Cmd>lua vim.lsp.buf.hover()<CR>", opts)
				buf_set_keymap("n", "<space>gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
				buf_set_keymap("n", "<space>k", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
				buf_set_keymap("n", "<space>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", opts)
				buf_set_keymap("n", "<space>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", opts)
				buf_set_keymap(
					"n",
					"<space>wl",
					"<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>",
					opts
				)
				buf_set_keymap("n", "<space>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", opts)
				buf_set_keymap("n", "<space>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
				buf_set_keymap("n", "<space>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
				buf_set_keymap("n", "<space>gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
				buf_set_keymap("n", "<space>e", "<cmd>lua vim.diagnostic.open_float()<CR>", opts)
				buf_set_keymap("n", "<space>[", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
				buf_set_keymap("n", "<space>]", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)
				buf_set_keymap("n", "<space>q", "<cmd>lua vim.diagnostic.setloclist()<CR>", opts)
				buf_set_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.format()<CR>", opts)
			end

			-- Use a loop to conveniently call 'setup' on multiple servers and
			-- map buffer local keybindings when the language server attaches
			local servers = { "ruby_lsp" }
			for _, lsp in ipairs(servers) do
				nvim_lsp[lsp].setup({
					on_attach = on_attach,
					flags = {
						debounce_text_changes = 150,
					},
				})
			end
		end,
	},
}
