return {
    {
    "folke/noice.nvim",
    opts = {
      cmdline = { format = { lua = false } },
      lsp = {
        progress = { enabled = false },
        hover = { enabled = false },
        signature = { enabled = false },
      },
      preset = {
        bottom_search = true,
        long_message_to_split = true,
        inc_rename = false,
      },
      messages = { enabled = false },
      notify = { enabled = false },
      popupmenu = { enabled = false },
      smart_move = { enabled = false },
    },
  },
}
