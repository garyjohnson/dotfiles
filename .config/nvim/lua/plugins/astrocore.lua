-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    -- Configure core features of AstroNvim
    features = {
      large_buf = { size = 1024 * 256, lines = 10000 }, -- set global limits for large files for disabling features like treesitter
      autopairs = true,                                 -- enable autopairs at start
      cmp = true,                                       -- enable completion at start
      diagnostics_mode = 3,                             -- diagnostic mode on start (0 = off, 1 = no signs/virtual text, 2 = no virtual text, 3 = on)
      highlighturl = true,                              -- highlight URLs at start
      notifications = true,                             -- enable notifications at start
    },
    -- Diagnostics configuration (for vim.diagnostics.config({...})) when diagnostics are on
    diagnostics = {
      virtual_text = true,
      underline = true,
    },
    -- vim options can be configured here
    options = {
      opt = {                  -- vim.opt.<key>
        relativenumber = true, -- sets vim.opt.relativenumber
        number = true,         -- sets vim.opt.number
        spell = false,         -- sets vim.opt.spell
        signcolumn = "yes",    -- sets vim.opt.signcolumn to yes
        wrap = false,          -- sets vim.opt.wrap
      },
      g = {                    -- vim.g.<key>
        -- configure global vim variables (vim.g)
        -- NOTE: `mapleader` and `maplocalleader` must be set in the AstroNvim opts or before `lazy.setup`
        -- This can be found in the `lua/lazy_setup.lua` file
      },
      -- Mappings can be configured through AstroCore as well.
      -- NOTE: keycodes follow the casing in the vimdocs. For example, `<Leader>` must be capitalized
    },
    mappings = {
      n = {
        ["<Leader>T"] = { desc = "Test" },
        ["<Leader>Tt"] = { function()
          require("neotest").output_panel.open()
          require("neotest").run.run()
        end, desc = "Run nearest test" },
        ["<Leader>Tf"] = { function()
          require("neotest").output_panel.open()
          require("neotest").run.run(vim.fn.expand("%"))
        end, desc = "Run file" },
        ["<Leader>Ta"] = { function()
          require("neotest").output_panel.open()
          require("neotest").run.run({ suite=true })
        end, desc = "Run test suite" },
        ["<Leader>Ts"] = { function() require("neotest").summary.toggle() end, desc = "Toggle test summary panel" },
        ["<Leader>To"] = { function() require("neotest").output_panel.toggle() end, desc = "Toggle test output panel" },
        ["<Leader>Tp"] = { function() require("neotest").output.open({ auto_close = true }) end, desc = "Toggle test output popover" },

        ["<Leader>X"] = { desc = "Explorer" },
        ["<Leader>Xg"] = { "<cmd>Neotree filesystem reveal_force_cwd<cr>", desc = "Go to file in explorer" },
        ["<Leader>Xc"] = { ":let @+=expand(\"%\")<cr>", desc = "Put current buffer name in system clipboard" },

        ["<Leader>A"] = { desc = "AstroNvim" },
        ["<Leader>Ac"] = { "<cmd>e ~/.config/nvim/lua/plugins/astrocore.lua<cr><cmd>Neotree filesystem show reveal_force_cwd<cr>", desc = "Open AstroNvim config" },
      },
    },
  },
}
