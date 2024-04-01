-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny
lvim.builtin.terminal.active = true

lvim.plugins = {
  {
    "vim-test/vim-test",
    cmd = { "TestNearest", "TestFile", "TestSuite", "TestLast", "TestVisit" },
    keys = { "<localleader>tf", "<localleader>tn", "<localleader>ts" },
    config = function()
      vim.cmd [[
          function! ToggleTermStrategy(cmd) abort
            call luaeval("require('toggleterm').exec(_A[1])", [a:cmd])
          endfunction
          let g:test#custom_strategies = {'toggleterm': function('ToggleTermStrategy')}
        ]]
      vim.g["test#strategy"] = "toggleterm"
    end,
  },
  {
    "tpope/vim-fugitive",
    cmd = {
      "G",
      "Git",
      "Gdiffsplit",
      "Gread",
      "Gwrite",
      "Ggrep",
      "GMove",
      "GDelete",
      "GBrowse",
      "GRemove",
      "GRename",
      "Glgrep",
      "Gedit"
    },
    ft = { "fugitive" }
  },
  {
    "tpope/vim-bundler",
    cmd = {"Bundler", "Bopen", "Bsplit", "Btabedit"}
  },
  {
    "tpope/vim-rails",
    lazy = false,
    cmd = {
      "Eview",
      "Econtroller",
      "Emodel",
      "Smodel",
      "Sview",
      "Scontroller",
      "Vmodel",
      "Vview",
      "Vcontroller",
      "Tmodel",
      "Tview",
      "Tcontroller",
      "Rails",
      "Generate",
      "Runner",
      "Extract"
    }
  },
}

lvim.builtin.which_key.mappings["r"] = {
  name = "Rails",
  m = { "<cmd>Emodel<cr>", "Open model" },
  vm = { "<cmd>Vmodel<cr>", "Open model in vertical split" },
  sm = { "<cmd>Smodel<cr>", "Open model in horizontal split" },
}

lvim.builtin.which_key.mappings["t"] = {
  name = "Test",
  t = { "<cmd>TestNearest<cr>", "Nearest" },
  f = { "<cmd>TestFile<cr>", "File" },
  s = { "<cmd>TestSuite<cr>", "Suite" },
}

lvim.builtin.which_key.mappings["j"] = {
  name = "JSON",
  f = { "<cmd>%!python3 -m json.tool<cr>>", "Format" }
}

lvim.builtin.which_key.mappings["T"] = {
  name = "+Terminal",
  f = { "<cmd>ToggleTerm<cr>", "Floating terminal" },
  v = { "<cmd>2ToggleTerm size=30 direction=vertical<cr>", "Split vertical" },
  h = { "<cmd>2ToggleTerm size=30 direction=horizontal<cr>", "Split horizontal" },
}

-- CTRL+D closes terminal -- can we find a better way?

-- displays source and message (useful for knowing which eslint rule is being violated)
lvim.lsp.null_ls.setup = {
  diagnostics_format = "[#{c}] #{m}",
}

-- enables floating diagnostic window
vim.diagnostic.config({
  virtual_text = {
    source = "always",  -- Or "if_many"
  },
  float = {
    source = "always",  -- Or "if_many"
  },
})

require("lvim.lsp.null-ls.formatters").setup {
  {
    exe = "prettierd",
    filetypes = {
    "graphql",
    "html",
    "json",
    "less",
    "markdown",
    "yaml",
    },
  },
}

require("lvim.lsp.null-ls.formatters").setup {
  {
    exe = "prettierd",
    filetypes = {
    "graphql",
    "html",
    "json",
    "less",
    "markdown",
    "yaml",
    },
  {
    exe = "erblint",
    filetypes = {
    "eruby",
    },
  },
  },
}

require("lsp-config/eslint")
require("lsp-config/tsserver")
require("lsp-config/ruby-lsp")
require("lsp-config/standardrb")
require("lsp-config/tailwindcss")
require("lsp-config/html")
