-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny

local function augroup(name)
  return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
end

lvim.builtin.terminal.active = true

-- path=3 is show absolute path with ~ home dir
lvim.builtin.lualine.sections.lualine_b = { { "filename", path = 3 } }

-- prevent long paths from being truncated
lvim.builtin.telescope.defaults = {
  path_display = { "absolute" },
  wrap_results = true
}

lvim.plugins = {
  {
    "barrett-ruth/import-cost.nvim",
    build = 'sh install.sh yarn',
    config = true
  },
  {
    "zbirenbaum/copilot-cmp",
    event = "InsertEnter",
    dependencies = { "zbirenbaum/copilot.lua" },
    config = function()
      vim.defer_fn(function()
        require("copilot").setup()     -- https://github.com/zbirenbaum/copilot.lua/blob/master/README.md#setup-and-configuration
        require("copilot_cmp").setup() -- https://github.com/zbirenbaum/copilot-cmp/blob/master/README.md#configuration
      end, 100)
    end,
  },
  {
    'TobinPalmer/pastify.nvim',
    cmd = { 'Pastify', 'PastifyAfter' },
    event = { 'BufReadPost' }, -- Load after the buffer is read, I like to be able to paste right away
    keys = {
      { noremap = true, mode = "x", '<leader>p', "<cmd>PastifyAfter<CR>" },
      { noremap = true, mode = "n", '<leader>p', "<cmd>PastifyAfter<CR>" },
      { noremap = true, mode = "n", '<leader>P', "<cmd>Pastify<CR>" },
    },
    config = function()
      require('pastify').setup {
        opts = {
          absolute_path = false,
          save = 'local',
          filename = function() return vim.fn.expand("%:t:r") .. '_' .. os.date('%Y-%m-%d_%H-%M-%S') end,
          local_path = '/src/images/',
        },
        ft = {
          html = '<img src="$IMG$" alt="">',
          markdown = '![]($IMG$)',
          css = 'background-image: url("$IMG$");',
          js = 'const img = new Image(); img.src = "$IMG$";',
          xml = '<image src="$IMG$" />',
        }
      }
    end
  },
  {
    "preservim/vim-pencil",
    init = function()
      vim.g["pencil#wrapModeDefault"] = "soft"
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup("pencil"),
        pattern = { "markdown,mkd,md" },
        callback = vim.fn['pencil#init'],
      })
    end,

  },
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
  { "tpope/vim-rhubarb" },
  {
    "tpope/vim-bundler",
    cmd = { "Bundler", "Bopen", "Bsplit", "Btabedit" }
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
    },
  },
  {
    "bkad/CamelCaseMotion",
    config = function()
      vim.cmd [[
        map <silent> \w <Plug>CamelCaseMotion_w
        map <silent> \b <Plug>CamelCaseMotion_b
        map <silent> \e <Plug>CamelCaseMotion_e
        map <silent> \ge <Plug>CamelCaseMotion_ge
      ]]
    end,
  },
  {
    url = "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
    config = function()
      require("lsp_lines").setup()
    end,
  }
}

-- add to LSP menu
lvim.builtin.which_key.mappings["lg"] = {
  "<cmd>lua require('lsp_lines').toggle()<cr>", "Toggle LSP lines"
}

lvim.builtin.which_key.mappings["k"] = {
  name = "Copilot",
  p = { ":Copilot panel<cr>", "Open Copilot panel" },
}

lvim.builtin.which_key.mappings["r"] = {
  name = "Rails",
  a = { "<cmd>AV<cr>", "Open associated file in vertical split" },
  ae = { "<cmd>A<cr>", "Open associated file" },
  m = { "<cmd>Vmodel<cr>", "Open model in vertical split" },
  me = { "<cmd>Emodel<cr>", "Open model" },
  ms = { "<cmd>Smodel<cr>", "Open model in horizontal split" },
  c = { "<cmd>Vcontroller<cr>", "Open controller in vertical split" },
  ce = { "<cmd>Econtroller<cr>", "Open controller" },
  cs = { "<cmd>Scontroller<cr>", "Open controller in horizontal split" },
  v = { "<cmd>Vview<cr>", "Open view in vertical split" },
  ve = { "<cmd>Eview<cr>", "Open view" },
  sv = { "<cmd>Sview<cr>", "Open view in horizontal split" },
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

lvim.builtin.which_key.mappings["x"] = {
  name = "+Explorer",
  g = { "<cmd>NvimTreeFindFile<cr>", "Go to file in explorer" },
  c = { ":let @+=expand(\"%\")<cr>", "Put current buffer name in system clipboard" },
}

-- CTRL+D closes terminal -- can we find a better way?

-- enables floating diagnostic window
-- vim.diagnostic.config({
--   virtual_text = {
--     source = "always",  -- Or "if_many"
--   },
--   float = {
--     source = "always",  -- Or "if_many"
--   },
-- })

null_ls = require("null-ls")
null_ls.setup({
  sources = {
    null_ls.builtins.formatting.prettierd,
    null_ls.builtins.formatting.erb_format.with({
      extra_args = { "--print-width=120" }
    }),
    null_ls.builtins.diagnostics.erb_lint,
  },
})

-- displays source and message (useful for knowing which eslint rule is being violated)
lvim.lsp.null_ls.setup = {
  diagnostics_format = "[#{c}] #{m}",
}

-- treat thor jobs as ruby files
vim.filetype.add {
  pattern = {
    ['.*%.thor'] = 'ruby',
  }
}

vim.filetype.add {
  pattern = {
    -- openapi
    ['.*openapi.*%.ya?ml'] = 'yaml.openapi',
    ['.*openapi.*%.json'] = 'json.openapi',
  },
}

require("lsp-config/eslint")
require("lsp-config/tsserver")
require("lsp-config/ruby-lsp")
require("lsp-config/standardrb")
require("lsp-config/tailwindcss")
require("lsp-config/html")
require("lsp-config/vacuum")

-- Disable virtual text
vim.diagnostic.config({ virtual_text = false })
