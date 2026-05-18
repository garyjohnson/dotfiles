-- Toggle function wired to <Leader>Z. Activates zen-mode layout and enables
-- render-markdown in tandem so they turn on/off together.
local function toggle_reader_mode()
  local zen = require "zen-mode"
  local rm = require "render-markdown"

  zen.toggle {
    window = {
      width = 80, -- narrow reading column
      options = {
        wrap = true,
        linebreak = true, -- wrap at word boundaries, not mid-word
        number = false,
        signcolumn = "no",
      },
    },
    on_open = function() rm.enable() end,
    on_close = function() rm.disable() end,
  }
end

return {
  -- zen-mode: centers a narrow window and strips UI chrome (statusline, numbers, etc.)
  -- https://github.com/folke/zen-mode.nvim
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    keys = {
      { "<Leader>Z", toggle_reader_mode, desc = "Toggle reader mode" },
    },
  },

  -- render-markdown: renders markdown syntax visually in-buffer (headers, tables,
  -- bold/italic, inline images). Only active when reader mode is on.
  -- https://github.com/MeanderingProgrammer/render-markdown.nvim
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = {}, -- not loaded for any filetype by default — toggled manually
    dependencies = { "3rd/image.nvim" },
    opts = {
      render_modes = { "n", "c" }, -- render in normal and command mode
      image = { enabled = true },
    },
  },

  -- image.nvim: renders images inline using the Kitty graphics protocol.
  -- iTerm2 has supported this protocol since v3.5.
  -- https://github.com/3rd/image.nvim
  {
    "3rd/image.nvim",
    opts = {
      backend = "kitty",
      integrations = {}, -- render-markdown handles its own integration
    },
  },
}
