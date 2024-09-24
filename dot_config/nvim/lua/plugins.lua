
return {
  { import = "plugins" },  -- This will load all plugins in the plugins directory
  { 'm4xshen/autoclose.nvim' },
  {
    'dense-analysis/ale',
    config = function()
        -- Configuration goes here.
        local g = vim.g

        g.ale_ruby_rubocop_auto_correct_all = 1

        g.ale_linters = {
            ruby = {'rubocop', 'ruby'},
            lua = {'lua_language_server'},
            eruby = {'erb'}
        }
    end
  },
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  { import = 'plugins' },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
      "MunifTanjim/nui.nvim",
      -- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
    }
  },
  { 'm4xshen/autoclose.nvim' },
  {
  "ibhagwan/fzf-lua",
  -- optional for icon support
  dependencies = { "nvim-tree/nvim-web-devicons" }
  },
  {"nvim-treesitter/nvim-treesitter", build = ":TSUpdate"}
}
