vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4

local capabilities = vim.lsp.protocol.make_client_capabilities()
-- Maybe capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

-- Installed by mason
local jdtls_bin = vim.fn.stdpath("data") .. "/mason/bin/jdtls"

local config = {
    cmd = { jdtls_bin },
    root_dir = vim.fs.dirname(vim.fs.find({ 'gradlew', 'settings.gradle', 'build.gradle', '.git', 'mvnw' },
        { upward = true })[1]),
    capabilities = capabilities,
    settings = {
        java = {
            classpath = {
                outputPath = "build",
            },
            project = {
                sourcePaths = { "build/generated/sources" },
                outputPath = "build",
            },
            configuration = {
                updateBuildConfiguration = "disabled",
            },
            import = {
                gradle = {
                    enabled = true,
                    wrapper = { enabled = true },
                    annotationProcessing = { enabled = true },
                },
            },

            implementationCodeLens = "all",
            saveactions = {
                organizeimports = false,
            },
            completion = {
                importOrder = {},
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
