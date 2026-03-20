-- vim.cmd('source ~/.vim/vimrc')

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- [[ Lazy.nvim ]] {{{
-- Install lazy.vim {{{
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out,                            "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)
-- }}}
-- [[ Plugins ]] {{{
require("lazy").setup({
    spec = {
        { import = "plugins" },
        {
            'Exafunction/codeium.vim',
            event = 'BufEnter',
            config = function()
                vim.keymap.set('i', '<C-l>', function() return vim.fn['codeium#Accept']() end,
                    { expr = true, silent = true })
                vim.keymap.set('i', '<C-h>', function() return vim.fn['codeium#CycleCompletions'](1) end,
                    { expr = true, silent = true })
                -- vim.keymap.set('i', '<C-y>', function() return vim.fn['codeium#CycleCompletions'](-1) end,
                -- { expr = true, silent = true })
                -- vim.keymap.set('i', '<c-x>', function() return vim.fn['codeium#Clear']() end,
                --     { expr = true, silent = true })
                --     Clear current suggestion	codeium#Clear()	<C-]>
                -- Next suggestion	codeium#CycleCompletions(1)	<M-]>
                -- Previous suggestion	codeium#CycleCompletions(-1)	<M-[>
                -- Insert suggestion	codeium#Accept()	<Tab>
                -- Manually trigger suggestion	codeium#Complete()	<M-Bslash>
                -- Accept word from suggestion	codeium#AcceptNextWord()	<C-k>
                -- Accept line from suggestion	codeium#AcceptNextLine()	<C-l>
            end
        },
        {
            -- Custom LSP configuration for Java jdtls
            -- Needed to support jars
            'mfussenegger/nvim-jdtls'
        },
        { -- LSP Configuration & Plugins
            'neovim/nvim-lspconfig',
            dependencies = {
                'mason-org/mason.nvim', -- Automatically install LSPs to stdpath for neovim
                'mason-org/mason-lspconfig.nvim',
                'j-hui/fidget.nvim',    -- Useful status updates for LSP
                'folke/lazydev.nvim',
            },
        },
        {
            -- Additional lua configuration, better LSP for nvim lua
            {
                "folke/lazydev.nvim",
                ft = "lua", -- only load on lua files
                opts = {
                    library = {
                        -- See the configuration section for more details
                        -- Load luvit types when the `vim.uv` word is found
                        { path = "luvit-meta/library", words = { "vim%.uv" } },
                    },
                },
            },
            { "Bilal2453/luvit-meta", lazy = true }, -- optional `vim.uv` typings
            {                                        -- optional cmp completion source for require statements and module annotations
                "hrsh7th/nvim-cmp",
                opts = function(_, opts)
                    opts.sources = opts.sources or {}
                    table.insert(opts.sources, {
                        name = "lazydev",
                        group_index = 0, -- set group index to 0 to skip loading LuaLS completions
                    })
                end,
            },
        },
        {
            'j-hui/fidget.nvim',
            config = function()
                require('fidget').setup({
                    -- :help fidget-options
                    progress = {
                        display = {
                            render_limit = 4, -- How many LSP messages to show at once
                        },
                    },
                })
            end
        },
        { -- Autocompletion
            'hrsh7th/nvim-cmp',
            dependencies = {
                'hrsh7th/cmp-nvim-lsp',
                'hrsh7th/cmp-buffer',
                'saadparwaiz1/cmp_luasnip',
                'L3MON4D3/LuaSnip',
                'rafamadriz/friendly-snippets' -- snipes for luasnip defined in vscode syntax
            },
        },
        -- qol
        { 'tpope/vim-rhubarb' },         -- for fugitive for enterprise github
        { 'tpope/vim-fugitive' },        -- essential
        { 'tpope/vim-speeddating' },     -- better (de/in)crementing of date strings: (play Thu, 11 Apr 2002 00:59:58 +0000)
        { 'tpope/vim-abolish' },         -- CoeRce to camelCase/snake_case/MixedCase crc crs crm
        { 'gcmt/taboo.vim' },            -- :TabooRename to rename tabs
        { 'scrooloose/nerdtree' },       -- TODO replace this one day
        { 'romainl/vim-qf' },            -- guickfix options :Keep :Reject :SaveList :Restore
        { 'nvim-lualine/lualine.nvim' }, -- Fancier statusline
        -- visual
        {
            'maxmx03/solarized.nvim',
            lazy = false,
            priority = 1000,
            opts = {
                transparent = {
                    enabled = false,
                    pmenu = true,
                    normal = true,
                    normalfloat = true,
                    neotree = true,
                    nvimtree = true,
                    whichkey = true,
                    telescope = true,
                    lazy = true,
                },
                on_highlights = nil,
                on_colors = nil,
                palette = 'selenized', -- solarized (default) | selenized
                variant = 'spring',    -- "spring" | "summer" | "autumn" | "winter" (default)
                error_lens = {
                    text = false,
                    symbol = false,
                },
            },
            config = function(_, opts)
                vim.o.termguicolors = true
                vim.o.background = 'light'
                require('solarized').setup(opts)
                vim.cmd.colorscheme 'solarized'
            end,
        },
        { 'xiyaowong/nvim-cursorword' },   -- :CursorWordEnable, some config in plugins.vim
        { 'etherandrius/MultipleSearch' }, -- Highlight multiple words at the same time
        { 'kshenoy/vim-signature' },       -- shows marks
        -- Highlight, edit, and navigate code
        {
            "nvim-treesitter/nvim-treesitter",
            config = function()
                local configs = require("nvim-treesitter.configs")
                configs.setup({
                    ensure_installed = { 'java', 'c', 'cpp', 'go', 'lua', 'python', 'rust', 'typescript', 'vimdoc', 'vim', 'graphql', 'terraform' },
                    modules = {},
                    ignore_install = {},
                    auto_install = true,
                    sync_install = false,
                    highlight = {
                        enable = true,
                        additional_vim_regex_highlighting = false,
                    },
                    indent = { enable = true },
                    textobjects = {
                        select = {
                            enable = true,
                            lookahead = true,
                            keymaps = {
                                ["af"] = "@function.outer",
                                ["if"] = "@function.inner",
                                ["ia"] = "@parameter.inner",
                                ["aa"] = "@parameter.outer",
                            },
                            include_surrounding_whitespace = function(table)
                                local blockList = {
                                    ["@parameter.inner"] = true,
                                    ["@parameter.outer"] = true,
                                    ["@function.inner"] = true,
                                }
                                return not blockList[table["query_string"]]
                            end
                        },
                    },
                })
            end
        },
        {
            'nvim-treesitter/playground',
            dependencies = {
                'nvim-treesitter/nvim-treesitter'
            },
        },
        { 'kmonad/kmonad-vim' },           -- kmonad syntax highlight
        {
            'norcalli/nvim-colorizer.lua', -- #e8ffd1
            config = function()
                require 'colorizer'.setup {
                    'lua',
                    'css',
                    'javascript',
                    'html',
                    'rust',
                }
            end,
        },
        -- text objects
        { 'michaeljsmith/vim-indent-object' },
        { 'numToStr/Comment.nvim' }, -- "gc" to comment visual regions/lines
        {
            'nvim-treesitter/nvim-treesitter-textobjects',
            dependencies = 'nvim-treesitter',
        },
        -- navigation
        { 'jremmen/vim-ripgrep' },
        {
            -- Global marks but better, project Specific
            'ThePrimeagen/harpoon',
            branch = "harpoon2",
            event = "VeryLazy",
            dependencies = {
                'nvim-lua/plenary.nvim',
            },
            config = function()
                local harpoon = require("harpoon")
                local git_dir = vim.fn.system("git rev-parse --git-common-dir 2>/dev/null"):gsub("\n", "")
                local harpoon_key = vim.v.shell_error == 0
                    and vim.fn.fnamemodify(git_dir, ":p")
                    or vim.loop.cwd()
                harpoon:setup({
                    settings = {
                        key = function() return harpoon_key or "/tmp" end,
                    },
                })

                vim.keymap.set('n', '<leader>rm', function()
                    harpoon.ui:toggle_quick_menu(harpoon:list())
                end, { desc = 'Harpoon files' })

                vim.api.nvim_create_user_command('HarpoonAddFile', function()
                    harpoon:list():add()
                end, {})

                vim.api.nvim_create_user_command('HarpoonList', function()
                    harpoon.ui:toggle_quick_menu(harpoon:list())
                end, {})

                -- vim.cmd("hi! link HarpoonWindow Normal")
                -- vim.cmd("hi! link HarpoonBorder Normal")
            end
        },
        { 'ggandor/lightspeed.nvim' }, -- type where you look
        { 'nvim-telescope/telescope.nvim',            branch = '0.1.x', dependencies = { 'nvim-lua/plenary.nvim' } },
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
        { 'nvim-telescope/telescope-ui-select.nvim' }, -- vim.ui.select = telescope; overrides some vim default
        -- Rust
        {
            'mrcjkb/rustaceanvim',
            version = '^8',
            lazy = false,
            init = function()
                vim.g.rustaceanvim = {
                    server = {
                        default_settings = {
                            ['rust-analyzer'] = {
                                completion = {
                                    autoimport = { enable = true },
                                    fullFunctionSignatures = { enable = true },
                                },
                                imports = {
                                    granularity = { group = 'module' },
                                    prefix = 'self',
                                },
                            },
                        },
                    },
                }
            end,
        },
        {
            'saecki/crates.nvim',
            event = { 'BufRead Cargo.toml' },
            config = function()
                require('crates').setup({
                    completion = {
                        cmp = { enabled = true },
                        crates = {
                            enabled = true,
                            min_chars = 3,
                        },
                    },
                })
            end,
        },
        -- Test
        { 'skywind3000/asyncrun.vim' }, -- :AsyncRun! echo 1; sleep 0.2; echo 2 , has a pretty good manual
    },

    install = {
        colorscheme = { "solarized" }
    },
    -- automatically check for plugin updates
    checker = { enabled = true, notify = false },
})
-- [[ Plugins ]] }}}
-- Plugin config
-- [[ LSP - keymaps ]] {{{
-- Diagnostic keymaps
vim.keymap.set('n', '[d', function()
    vim.diagnostic.jump({
        count = -1
    })
end)
vim.keymap.set('n', ']d', function()
    vim.diagnostic.jump({
        count = 1
    })
end)
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)
vim.keymap.set('n', 'ge', function()
    return vim.diagnostic.jump({
        count = 1,
        severity = vim.diagnostic.severity.ERROR
    })
end)
vim.keymap.set('n', 'gE', function()
    return vim.diagnostic.jump({
        count = -1,
        severity = vim.diagnostic.severity.ERROR
    })
end)
vim.keymap.set('n', '<leader>qe', function()
    return vim.diagnostic.setqflist({
        severity = vim.diagnostic.severity.ERROR
    })
end, { desc = "LSP Errors" })
vim.keymap.set('n', '<leader>qw', function()
    return vim.diagnostic.setqflist({
    })
end, { desc = "LSP Warnings / Info / Hints" })

local nmap = function(keys, func, desc)
    if desc then
        desc = 'LSP: ' .. desc
    end

    vim.keymap.set('n', keys, func, { desc = desc })
end

nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

vim.lsp.inlay_hint.enable(false)
nmap('<leader>ih', function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, '[I]nlay [H]ints toggle')

-- lua print(require('vim.lsp').buf_request(0, 'textDocument/typeDefinition', require('vim.lsp.util').make_position_params(), nil))
nmap('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
nmap('gd', vim.lsp.buf.definition, '[G]oto [D]efinition')
nmap('gi', vim.lsp.buf.implementation, '[G]oto [I]mplementation')
nmap('gy', vim.lsp.buf.type_definition, '[G]oto T[Y]pe Definition')
nmap('gY', vim.lsp.buf.typehierarchy, '[G]oto Type Hierarch[Y]')
nmap('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
nmap('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

-- See `:help K` for why this keymap
-- nmap('gD', vim.lsp.buf.hover, 'Hover Documentation')
-- nmap('gK', vim.lsp.buf.hover, 'Hover Documentation')
-- 'single' | 'double' | 'rounded' | 'solid' | 'shadow'
nmap('gK', function()
    vim.lsp.buf.hover({
        border = 'rounded',
        max_width = 120,
        max_height = 30,
    })
end, 'Hover Documentation')


-- Lesser used LSP functionality
-- nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
-- nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
-- nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
nmap('<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
end, '[W]orkspace [L]ist Folders')

-- Create a command `:Format` local to the LSP buffer
vim.api.nvim_create_user_command('Format', function(_)
    vim.lsp.buf.format()
end, { desc = 'Format current buffer with LSP' })
-- }}}
-- [[ nvim-jdtls - Custom setup for java ]] {{{
-- See ftplugin/java.lua
-- }}}
-- [[ Mason LSP - Servers ]] {{{
-- Enable the following language servers
--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
--
--  Add any additional override configuration in the following tables. They will be passed to
--  the `settings` field of the server config. You must look up that documentation yourself.
local servers = {
    gopls = {},
    marksman = {},
    -- rust_analyzer = {}, -- Managed by rustaceanvim, do not enable here
    lua_ls = {
        Lua = {
            workspace = {
                checkThirdParty = false,
                library = { "~/.luarocks/share/lua/5.4/" }
            },
            telemetry = { enable = false },
            diagnostics = {
                globals = { 'vim' },
            },
        },
    },
    ts_ls = {},
    -- graphql = {},
    -- gradle_ls = {},
    basedpyright = {},
    -- kotlin_language_server = {},
    -- groovyls = {}, -- Not good enough yet; Need to manually add relevant jars
    -- jdtls = {
    --     -- See ftplugin/java.lua
    -- },

    -- sumneko_lua = {
    --   Lua = {
    --     workspace = { checkThirdParty = false },
    --     telemetry = { enable = false },
    --     diagnostics = {
    --         globals = { 'vim' }
    --     }
    --   },
    -- },
}
-- }}}
-- [[ Lualine - statusline ]] {{{
-- Set lualine as statusline
-- See `:help lualine.txt`

local isGeneratedFile = function()
    local path = vim.fn.expand("%:h")
    if string.match(path, "generated") then
        return "[G]"
    end
    return ""
end

local isDiffFile = function()
    local path = vim.fn.expand("%:h")
    if string.match(path, "fugitive://") then
        return "[Diff]"
    end
    return ""
end

local javaPath = function()
    local path = vim.fn.expand("%:h")
    if path:len() == 0 then
        return ""
    end
    if path:match("jdt://") then
        path = "jdt://classpath"
    end
    if path:match("/Users/agrabauskas/Projects/java/foundry") then
        path = path:gsub("/Users/agrabauskas/Projects/java/foundry", "")
    end
    if path:match("java/com/palantir/") then
        path = path:gsub("java/com/palantir/", "J/")
    end
    if path:match("/generated/") then
        path = path:gsub("/generated/", "/G/")
    end
    if path:match("/src/test/") then
        path = path:gsub("/src/test/", "/T/")
    end
    if path:match("/src/integrationTest/") then
        path = path:gsub("/src/integrationTest/", "/IT/")
    end
    if path:match("/src/main/") then
        path = path:gsub("/src/main/", "/S/")
    end
    return "(" .. path .. ")"
end

require('lualine').setup {
    options = {
        icons_enabled = false,
        theme = 'solarized',
        component_separators = '|',
        section_separators = '',
    },
    sections = {
        lualine_a = { 'mode' },
        lualine_b = {
            'branch',
            'diagnostics' },
        lualine_c = { javaPath, 'filename' },
        lualine_x = { isGeneratedFile, isDiffFile, 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' }
    },
    inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { javaPath, 'filename' },
        lualine_x = { isGeneratedFile, isDiffFile },
        lualine_y = {},
        lualine_z = {}
    },
}
-- }}}
-- [[ Telescope ]] {{{
-- See `:help telescope` and `:help telescope.setup()`

local utils = require('telescope.utils')
local entry_display = require("telescope.pickers.entry_display")

local custom_path_display = function(_, path)
    local name = utils.path_tail(path)
    local subtype = ""
    if path:find('/java/com/palantir/') then
        path = path:gsub("java/com/palantir/", "")
    end
    if path:find('/generated/') then
        subtype = "gen "
        path = path:gsub("/generated/", "/G/")
    end
    if path:find('/src/test/') then
        subtype = "test"
        path = path:gsub("/src/test/", "/T/")
    end
    if path:find('/src/integrationTest/') then
        subtype = "itest"
        path = path:gsub("/src/integrationTest/", "/IT/")
    end
    if path:find('/src/main/') then
        subtype = "src "
        path = path:gsub("/src/main/", "/S/")
    end
    local displayer = entry_display.create({
        separator = ' ▏',
        items = {
            { width = 55 },
            { width = 5 },
            { remaining = true },
        },
    })
    return displayer({
        name,
        subtype,
        path,
    })
end


require('telescope').setup {
    defaults = {
        file_previewer = require('telescope.previewers').vim_buffer_cat.new
    },

    pickers = {
        git_files = {
            path_display = custom_path_display
        },
        find_files = {
            path_display = custom_path_display
        },
        oldfiles = {
            path_display = custom_path_display
        },
        lsp_references = {
            path_display = custom_path_display
        },
        grep_string = {
            path_display = custom_path_display
        },
        live_grep = {
            path_display = custom_path_display
        },
    },
    extensions = {
        ["ui-select"] = {
            require("telescope.themes").get_dropdown {
                -- even more opts
            }

            -- pseudo code / specification for writing custom displays, like the one
            -- for "codeactions"
            -- specific_opts = {
            --   [kind] = {
            --     make_indexed = function(items) -> indexed_items, width,
            --     make_displayer = function(widths) -> displayer
            --     make_display = function(displayer) -> function(e)
            --     make_ordinal = function(e) -> string
            --   },
            --   -- for example to disable the custom builtin "codeactions" display
            --      do the following
            --   codeactions = false,
            -- }
        }
    }

}

-- Enable telescope fzf native, if installed
pcall(require('telescope').load_extension, 'fzf')
pcall(require("telescope").load_extension, "ui-select")

-- See `:help telescope.builtin`
vim.keymap.set('n', '<leader>rh', require('telescope.builtin').oldfiles, { desc = '[R]ecent [H]istory old files' })
vim.keymap.set('n', '<leader>b', require('telescope.builtin').buffers,
    { desc = 'Search [B]uffers]' })
vim.keymap.set('n', 'z=', require('telescope.builtin').spell_suggest, { desc = 'Spell suggestions' })

vim.keymap.set('n', '<leader>sq', require('telescope.builtin').quickfix, { desc = '[S]earch [Q]uickfix' })

vim.keymap.set('n', '<leader>t', function()
    return require('telescope.builtin').git_files({
        show_untracked = true,
    })
end, { desc = 'Search Git Files' })
vim.keymap.set('n', '<leader>T', function()
    return require('telescope.builtin').find_files({
        no_ignore = true,
        hidden = true,
    })
end, { desc = 'Search ALL Files' })
vim.keymap.set('n', '<leader>m', require('telescope.builtin').git_status, { desc = 'Search [M]odified Files' })

-- nnoremap <leader>T <cmd>lua require('telescope.builtin').find_files({find_command = {'rg', '--files', '--no-ignore', '--glob', '!*.class'}})<cr>
vim.keymap.set('n', '<leader>sh', require('telescope.builtin').help_tags, { desc = '[S]earch [H]elp' })

local findFilesForWordUnderCursor = function()
    local word = vim.fn.expand "<cword>"
    require('telescope.builtin').find_files({
        search_file = word,
        no_ignore = true,
    })
end
vim.keymap.set('n', '<leader>sf', findFilesForWordUnderCursor, { desc = '[S]earch current [F]ile' })

vim.keymap.set('n', '<leader>sw', require('telescope.builtin').grep_string, {
    desc = '[S]earch current [W]ord'
})

vim.keymap.set('v', '<leader>rg', function()
    vim.cmd("normal v")
    local visual_selection = string.sub(vim.fn.getline("'<"), vim.fn.col("'<"), vim.fn.col("'>"))
    -- Escape regex special characters
    local escaped = visual_selection:gsub('[%^%$%(%)%?%*%+%[%]%{%}%%%|%.%-\\]', '\\%0')
    return require('telescope.builtin').live_grep({
        default_text = escaped,
        additional_args = { "--hidden" },
        glob = {
            "!.git",
            "!changelog",
            "!vendor",
            "!*_test.go",
            "!*Test.java",
        }
    })
end, { desc = '[S]earch source using [G]rep' })

vim.keymap.set('v', '<leader>Rg', function()
    vim.cmd("normal v")
    local visual_selection = string.sub(vim.fn.getline("'<"), vim.fn.col("'<"), vim.fn.col("'>"))
    -- Escape regex special characters
    local escaped = visual_selection:gsub('[%^%$%(%)%?%*%+%[%]%{%}%%%|%.%-\\]', '\\%0')
    return require('telescope.builtin').live_grep({
        default_text = escaped,
        glob = {
            "!changelog",
            "!vendor",
        }
    })
end
, { desc = '[S]earch all files using [G]rep' })

vim.keymap.set('n', '<leader>rg', function()
    return require('telescope.builtin').live_grep({
        additional_args = { "--hidden" },
        glob = {
            "!.git",
            "!changelog",
            "!vendor",
            "!*_test.go",
            "!*Test.java",
        }
    })
end

, { desc = '[S]earch source using [G]rep' })
vim.keymap.set('n', '<leader>Rg', function()
    return require('telescope.builtin').live_grep({
        additional_args = { "--hidden" },
        glob = {
            "!.git",
            "!changelog",
            "!vendor",
        }
    })
end
, { desc = '[S]earch all files using [G]rep' })

vim.keymap.set('n', '<leader>rdg', function()
    -- local visual_selection = string.sub(vim.fn.getline("'<"), vim.fn.col("'<"), vim.fn.col("'>"))
    return require('telescope.builtin').live_grep({
        cwd = "/Volumes/git/vscode-team/forge/packages/pipelines",
        search_dirs = {
            "authoring-vscode-extension",
            "authoring-vscode-extension-core",
            "authoring-vscode-extension-core-types",
            "authoring-vscode-extension-integration-test",
            "authoring-vscode-extension-types",
            "authoring-vscode-extension-utils",
            "authoring-vscode-extension-webviews"
        }, -- TODO(aagg): Better way to select directory
        glob = {
            "!changelog",
            "!vendor",
            "!*_test.go",
            "!*Test.java",
        }
    })
end, { desc = '[S]earch source using [G]rep' })

vim.keymap.set('n', '<leader>sd', require('telescope.builtin').diagnostics, { desc = '[S]earch [D]iagnostics' })

-- }}}
-- [[ Mason ]] {{{
-- [ nvim-cmp ] {{{
-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)
-- }}}

-- Setup mason so it can manage external tooling
require('mason').setup()

-- Ensure the servers above are installed
local mason_lspconfig = require 'mason-lspconfig'
mason_lspconfig.setup {
    automatic_enable = { exclude = { "rust_analyzer" } },
    ensure_installed = vim.tbl_keys(servers),
}

-- Apply server-specific settings and capabilities
for server_name, server_settings in pairs(servers) do
    vim.lsp.config(server_name, {
        capabilities = capabilities,
        settings = server_settings,
    })
end

-- }}}
-- [[ codeium ]] {{{
vim.g.codeium_enabled = false
vim.g.codeium_disable_bindings = 1
vim.g.codeium_log_level = "TRACE"
if vim.env.CODEIUM_PORTAL_URL and vim.env.CODEIUM_API_URL then
    vim.g.codeium_server_config = {
        portal_url = vim.env.CODEIUM_PORTAL_URL,
        api_url = vim.env.CODEIUM_API_URL,
    }
end
-- }}}
-- [[ nvim-cmp ]] {{{
local cmp = require 'cmp'
local luasnip = require 'luasnip'

require("luasnip.loaders.from_vscode").load {
    exclude = { "javascript" },
}

cmp.setup {
    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end,
    },
    mapping = cmp.mapping.preset.insert {
        ["<CR>"] = cmp.mapping.confirm({
            -- this is the important line
            behavior = cmp.ConfirmBehavior.Replace,
            select = false,
        }),
        ['<C-e>'] = cmp.mapping.abort(),
        ['<C-k>'] = function(fallback)
            if cmp.visible() then
                cmp.mapping.confirm({ select = true })(fallback)
            else
                cmp.mapping.complete()(fallback)
            end
        end
    },
    sources = {
        { name = 'nvim_lsp', group_index = 1 },
        { name = "buffer",   keyword_length = 4, group_index = 1, max_item_count = 5 },
    },
}
-- }}}
-- [[ lua-migration ]] {{{
vim.cmd('source ~/.config/nvim/lua-migration/plugins.vim')
-- }}}
-- }}}
-- [[ Custom ]] {{{
require("cargo-read-only")
require("notes-template")
require("notes-backlinks")
require("notes-tags-hover")
vim.cmd('source ~/.config/nvim/lua-migration/set.vim')
-- [[ Keymaps ]] {{{
-- See `:help vim.keymap.set()`
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

vim.cmd('source ~/.config/nvim/lua-migration/keymaps.vim')
-- }}}
vim.cmd('source ~/.config/nvim/lua-migration/augroup.vim')
-- [[ Built-in autoread ]] {{{
vim.o.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
    command = "silent! checktime",
    desc = "Auto-reload files changed outside of Neovim",
})
-- ]}}
vim.cmd('source ~/.config/nvim/lua-migration/testBlock.vim')
vim.cmd('source ~/.config/nvim/spell/abbrev.vim')
-- }}}
-- vim: foldlevel=1:foldmethod=marker
