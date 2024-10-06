
return {
  { import = "plugins" },  -- This will load all plugins in the plugins directory
  { 'm4xshen/autoclose.nvim' },
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  {"nvim-treesitter/nvim-treesitter", build = ":TSUpdate"}
}
