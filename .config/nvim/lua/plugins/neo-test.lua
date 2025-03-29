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
    "olimorris/neotest-rspec",
    "nvim-neotest/neotest-jest",
    "marilari88/neotest-vitest",
  },
  config = function()
    require("neotest").setup {
      adapters = {
        require "neotest-minitest",
        require "neotest-rspec",
        require "neotest-jest",
        require "neotest-vitest",
      },
      diagnostic = {
        enabled = true,
        severity = 1,
      },
      opts = {
        discovery = {
          enabled = false
        }
      }
    }
  end,
}
