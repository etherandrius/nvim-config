vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4

local capabilities = vim.lsp.protocol.make_client_capabilities()
-- Maybe capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

-- Installed by mason
local jdtls_bin = vim.fn.stdpath("data") .. "/mason/bin/jdtls"

local gradle = require('java-gradle')
local root_dir = gradle.root(vim.api.nvim_buf_get_name(0))
if not root_dir then return end
-- Once per build root, before starting JDTLS; only ignored local metadata is repaired.
gradle.prepare(root_dir)

local config = {
    cmd = { jdtls_bin, '-data', gradle.workspace(root_dir) },
    root_dir = root_dir,
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
                -- Paused by default. Change this before starting JDTLS, never live:
                -- its preference listener incorrectly resyncs every module as a root.
                updateBuildConfiguration = vim.g.java_build_configuration_update or "disabled",
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
                import = {
                    gradle = { enabled = true, wrapper = { enabled = true } },
                },
                -- JDTLS uses plural "imports" specifically for checksum approvals.
                imports = {
                    gradle = {
                        wrapper = {
                            checksums = {
                                {
                                    sha256 = '7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172',
                                    allowed = true
                                },
                                {
                                    sha256 = '7a9ce74cff467ca1bf60a4fcd9f05185acceda4d0f382434d393e17864262c5d',
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
-- Neovim sends settings again after initialize. JDTLS 1.60's Gradle listener
-- treats a changed updateBuildConfiguration value as a request to import EVERY
-- module separately, losing the root wrapper and falling back to Gradle 8.9.
-- Send the identical complete settings at initialization (also keeps autobuild
-- off from the start). Keep the special plural checksum key in both payloads.
config.settings.java.imports = config.init_options.settings.java.imports
config.init_options.settings = vim.deepcopy(config.settings)
require('jdtls').start_or_attach(config)
