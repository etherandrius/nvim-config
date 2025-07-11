local capabilities = vim.lsp.protocol.make_client_capabilities()
-- Maybe capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

-- Installed by mason
local jdtls_bin = vim.fn.stdpath("data") .. "/mason/bin/jdtls"

local config = {
    cmd = { jdtls_bin },
    root_dir = vim.fs.dirname(vim.fs.find({ 'gradlew', '.git', 'mvnw' }, { upward = true })[1]),
    on_attach = ON_ATTACH,
    capabilities = capabilities,
    settings = {
        java = {
            saveactions = {
                organizeimports = false,
            },
            completion = {
                importorder = {},
            },
            autobuild = {
                enabled = false,
            },
            -- jdt = {
            --     ls = {
            --         -- DEBUG: add arguments -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=127.0.0.1:1044 and run jdb -attach 127.0.0.1
            --         vmargs = "-noverify -Xmx8G -XX:+UseG1GC -XX:+UseStringDeduplication",
            --         androidSupport = {
            --             enabled = "off",
            --         },
            --     },
            -- },
        }
    },
    init_options = {
        settings = {
            java = {
                imports = {
                    gradle = {
                        enabled = true,
                        wrapper = {
                            enabled = true,
                            checksums = {
                                {
                                    sha256 = '7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172',
                                    allowed = true
                                }
                            }
                        }
                    }
                },
                -- jdt = {
                --     ls = {
                --         -- DEBUG: add arguments -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=127.0.0.1:1044 and run jdb -attach 127.0.0.1
                --         vmargs = "-noverify -Xmx8G -XX:+UseG1GC -XX:+UseStringDeduplication",
                --         androidSupport = {
                --             enabled = "off",
                --         },
                --     },
                -- },
            }
        },
    },

}
require('jdtls').start_or_attach(config)
