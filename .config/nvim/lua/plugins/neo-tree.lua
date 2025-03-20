return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = {
        visible = true,
        show_hidden_count = true,
        hide_dotfiles = false,
        hide_gitignored = false,
        hide_by_name = {
          ".git",
          ".DS_Store",
          "thumbs.db",
          "node_modules",
        },
        never_show = {},
      },
    },
    window = {
      mappings = {
        -- Disable fuzzy finding so we can just search the buffer
        -- https://github.com/nvim-neo-tree/neo-tree.nvim/issues/791
        ["/"] = "noop",
      },
    },
  },
}
