return {
  { "tpope/vim-fugitive" },
  {
    "lewis6991/gitsigns.nvim",
    keys = {
      {
        "<leader>gy",
        function()
          return ":GBrowse!<cr>"
        end,
        desc = "Copy GitHub URL to clipboard",
        silent = true,
        expr = true,
        mode = { "n", "v", "x" },
      },
      { "<leader>gl", "<cmd>Git blame<cr>", desc = "Git Blame" },
      {
        "<leader>gd",
        function()
          local view = require("diffview.lib").get_current_view()
          if view then
            vim.g.autoformat_enabled = true
            vim.cmd.DiffviewClose()
          else
            vim.g.autoformat_enabled = false
            vim.cmd.DiffviewOpen()
          end
        end,
        desc = "Diffview",
      },
    },
    opts = {
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end

        map("n", "]c", next_hunk, "Next Hunk")
        map("n", "[c", prev_hunk, "Prev Hunk")
        map({ "n", "v" }, "<leader>gh", ":Gitsigns stage_hunk<CR>", "Stage Hunk")
        map({ "n", "v" }, "<leader>gH", ":Gitsigns reset_hunk<CR>", "Reset Hunk")
        map("n", "<leader>gb", gs.stage_buffer, "Stage Buffer")
        map("n", "<leader>gB", gs.reset_buffer, "Reset Buffer")
        map("n", "<leader>gu", gs.undo_stage_hunk, "Undo Stage Hunk")
        map("n", "<leader>go", gs.preview_hunk_inline, "Preview Hunk Inline")
        map({ "o", "x" }, "ih", gs.select_hunk, "GitSigns Select Hunk")
      end,
    },
  },
}
