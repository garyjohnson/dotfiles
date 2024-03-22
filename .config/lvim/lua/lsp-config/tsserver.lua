-- tsserver
--
-- Config from: ???
require'lspconfig'.tsserver.setup({
    on_attach = function(client, bufnr)
        client.server_capabilities.documentFormattingProvider = false
    end
})
