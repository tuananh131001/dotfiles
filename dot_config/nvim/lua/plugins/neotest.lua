return {
  {
    "nvim-neotest/neotest",
    dependencies = {
       "nvim-neotest/nvim-nio",
           "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "olimorris/neotest-rspec",
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-rspec")({
            rspec_cmd = function()
              return vim.tbl_flatten({
                "bundle",
                "exec",
                "rspec",
              })
            end,
          }),
        },
      })
    end,
    -- Keymaps with space as leader
    keys = {
      { "<space>tt", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run File" },
      { "<space>tT", function() require("neotest").run.run(vim.loop.cwd()) end, desc = "Run All Test Files" },
      { "<space>tr", function() require("neotest").run.run() end, desc = "Run Nearest" },
      { "<space>ts", function() require("neotest").summary.toggle() end, desc = "Toggle Summary" },
      { "<space>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show Output" },
      { "<space>tO", function() require("neotest").output_panel.toggle() end, desc = "Toggle Output Panel" },
      { "<space>tS", function() require("neotest").run.stop() end, desc = "Stop" },
    },
  },
}
