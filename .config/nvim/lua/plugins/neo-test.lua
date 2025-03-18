return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    -- adapters
    -- see https://github.com/nvim-neotest/neotest?tab=readme-ov-file
    "zidhuss/neotest-minitest",
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-minitest")
      },
    })
  end
}
