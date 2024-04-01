local util = require 'lspconfig.util'

require'lspconfig'.html.setup{
    cmd = { 'vscode-html-language-server', '--stdio' },
    filetypes = { 'html', 'templ', 'erb', 'eruby' },
    root_dir = util.root_pattern('package.json', '.git'),
    single_file_support = true,
    settings = {},
    init_options = {
      provideFormatter = true,
      embeddedLanguages = { css = true, javascript = true },
      configurationSection = { 'html', 'css', 'javascript' }
    }
  }
