local capabilities = vim.lsp.protocol.make_client_capabilities()
-- Maybe capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

-- Installed by mason
local jdtls_bin = vim.fn.stdpath("data") .. "/mason/bin/jdtls"

local config = {
    cmd = { jdtls_bin },
    root_dir = vim.fs.dirname(vim.fs.find({'gradlew', '.git', 'mvnw'}, { upward = true })[1]),
    on_attach = ON_ATTACH,
    capabilities = capabilities
}
require('jdtls').start_or_attach(config)

