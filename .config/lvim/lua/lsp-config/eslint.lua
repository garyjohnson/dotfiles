-- eslint
--
-- Config from ???
--
-- Installation:
-- npm i -g vscode-langservers-extracted
require'lspconfig'.eslint.setup{
  format = true,
  on_attach = function(client, initialize_result)
    client.server_capabilities.documentFormattingProvider = true
  end
}

