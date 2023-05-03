-- vim.cmd('source ~/.vim/vimrc')

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.cmd('source ~/.config/nvim/lua-migration/color.vim')

-- [[ Packer ]] {{{
-- Install packer {{{
local install_path = vim.fn.stdpath 'data' .. '/site/pack/packer/start/packer.nvim'
local is_bootstrap = false
if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
  is_bootstrap = true
  vim.fn.system { 'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path }
  vim.cmd [[packadd packer.nvim]]
end
-- }}}
-- [[ Plugins ]] {{{
require('packer').startup(function(use)
  -- Package manager
  use 'wbthomason/packer.nvim'

  -- LSP Configuration & Plugins
  use {
    'neovim/nvim-lspconfig',
    requires = {
      'williamboman/mason.nvim', -- Automatically install LSPs to stdpath for neovim
      'williamboman/mason-lspconfig.nvim',
      'j-hui/fidget.nvim', -- Useful status updates for LSP
      'folke/neodev.nvim', -- Additional lua configuration, makes nvim stuff amazing
    },
  }

  use { -- Autocompletion
    'hrsh7th/nvim-cmp',
    requires = { 'hrsh7th/cmp-nvim-lsp', 'L3MON4D3/LuaSnip', 'saadparwaiz1/cmp_luasnip' },
  }

  -- qol
  use 'tpope/vim-rhubarb' -- for fugitive for enterprise github
  use 'tpope/vim-fugitive' -- essential
  use 'tpope/vim-speeddating' -- better (de/in)crementing of date strings: (play Thu, 11 Apr 2002 00:59:58 +0000)
  use 'tpope/vim-abolish' -- CoeRce to camelCase/snake_case/MixedCase crc crs crm
  use 'djoshea/vim-autoread' -- auto-reads changes to files TODO change this to inbuild nvim inode reader stuff
  use 'gcmt/taboo.vim' -- :TabooRename to rename tabs
  use 'scrooloose/nerdtree' -- TODO replace this one day
  use 'romainl/vim-qf' -- quickfix options
  use 'tpope/vim-sleuth' -- Detect tabstop and shiftwidth automatically
  use 'nvim-lualine/lualine.nvim' -- Fancier statusline

  -- visual
  use 'osyo-manga/vim-brightest' -- highlights current word in red
  use 'vim-scripts/MultipleSearch' -- Highlight multiple words at the same time
  use 'kshenoy/vim-signature' -- shows marks
  use 'mtdl9/vim-log-highlighting' -- syntax for log files
  use { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    'nvim-treesitter/playground',
    run = function()
      pcall(require('nvim-treesitter.install').update { with_sync = true })
    end,
  }

  -- text objects
  use 'michaeljsmith/vim-indent-object'
  use 'numToStr/Comment.nvim' -- "gc" to comment visual regions/lines
  use {
    'nvim-treesitter/nvim-treesitter-textobjects',
    after = 'nvim-treesitter',
  }

  -- navigation
  use 'jremmen/vim-ripgrep'
  use 'ThePrimeagen/harpoon' -- Global marks but better, project Specific
  use 'ggandor/lightspeed.nvim' -- type where you look
  use { 'nvim-telescope/telescope.nvim', branch = '0.1.x', requires = { 'nvim-lua/plenary.nvim' } }
  use { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make', cond = vim.fn.executable 'make' == 1 }

-- }}}
--- packer setup {{{
  -- Add custom plugins to packer from ~/.config/nvim/lua/custom/plugins.lua
  local has_plugins, plugins = pcall(require, 'custom.plugins')
  if has_plugins then
    plugins(use)
  end

  if is_bootstrap then
    require('packer').sync()
  end
end)

-- When we are bootstrapping a configuration, it doesn't
-- make sense to execute the rest of the init.lua.
--
-- You'll need to restart nvim, and then it will work.
if is_bootstrap then
  print '=================================='
  print '    Plugins are being installed'
  print '    Wait until Packer completes,'
  print '       then restart nvim'
  print '=================================='
  return
end

-- Automatically source and re-compile packer whenever you save this init.lua
local packer_group = vim.api.nvim_create_augroup('Packer', { clear = true })
vim.api.nvim_create_autocmd('BufWritePost', {
  command = 'source <afile> | silent! LspStop | silent! LspStart | PackerCompile',
  group = packer_group,
  pattern = vim.fn.expand '$MYVIMRC',
})
-- }}}
-- [[Plugin Configuration]] {{{
-- [[ LSP - keymaps ]] {{{
-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)
vim.keymap.set('n', 'ge', function ()
    return vim.diagnostic.goto_next({
        severity = vim.diagnostic.severity.ERROR
    })
end)
vim.keymap.set('n', 'gE', function ()
    return vim.diagnostic.goto_prev({
        severity = vim.diagnostic.severity.ERROR
    })
end)
vim.keymap.set('n', '<leader>qe', function ()
    return vim.diagnostic.setqflist({
        severity = vim.diagnostic.severity.ERROR
    })
end, { desc = "LSP Errors"})
vim.keymap.set('n', '<leader>qw', function ()
    return vim.diagnostic.setqflist({
        severity = { vim.diagnostic.severity.WARN, vim.diagnostic.severity.HINT, vim.diagnostic.severity.INFO }
    })
end, { desc = "LSP Warnings / Info / Hints"})

local on_attach = function(_, bufnr)
  local nmap = function(keys, func, desc)
    if desc then
      desc = 'LSP: ' .. desc
    end

    vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
  end

  nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
  nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

  nmap('gd', vim.lsp.buf.definition, '[G]oto [D]efinition')
  nmap('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
  nmap('gi', vim.lsp.buf.implementation, '[G]oto [I]mplementation')
  nmap('gy', vim.lsp.buf.type_definition, '[G]oto T[Y]pe Definition')
  nmap('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
  nmap('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

  -- See `:help K` for why this keymap
  nmap('gD', vim.lsp.buf.hover, 'Hover Documentation')

  -- Lesser used LSP functionality
  -- nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
  nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
  nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
  nmap('<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, '[W]orkspace [L]ist Folders')

  -- Create a command `:Format` local to the LSP buffer
  vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
    vim.lsp.buf.format()
  end, { desc = 'Format current buffer with LSP' })
end
-- }}}
-- [[ LSP - Servers ]] {{{
-- Enable the following language servers
--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
--
--  Add any additional override configuration in the following tables. They will be passed to
--  the `settings` field of the server config. You must look up that documentation yourself.
local servers = {
  gopls = {},
  rust_analyzer = {},
  jdtls = {
      java = { completion = { importOrder = {} } },
  },

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

local isGeneratedFile = function ()
    local path = vim.fn.expand("%:h")
    if string.match(path, "generated") then
        return "[G]"
    end
    return ""
end

local isDiffFile = function ()
    local path = vim.fn.expand("%:h")
    if string.match(path, "fugitive://") then
        return "[Diff]"
    end
    return ""
end

local javaPath = function ()
    local path = vim.fn.expand("%:h")
    if path:len() == 0 then
        return ""
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
    if path:match("/src/main/") then
        path = path:gsub("/src/main/", "/S/")
    end
    return "(" .. path .. ")"
end

require('lualine').setup {
    options = {
        icons_enabled = false,
        theme = require('solarized-lualine'),
        component_separators = '|',
        section_separators = '',
    },
    sections = {
        lualine_a = {'mode'},
        lualine_b = {
            'branch',
            {
                'diff',
                diff_color = {
                  added = { fg = 2 },
                  modified = { fg = 3 },
                  removed = { fg = 1 },
                }
            },
            'diagnostics'},
        lualine_c = {javaPath, 'filename'},
        lualine_x = {isGeneratedFile, isDiffFile, 'filetype'},
        lualine_y = {'progress'},
        lualine_z = {'location'}
    },
    inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {javaPath, 'filename'},
        lualine_x = {isGeneratedFile, isDiffFile},
        lualine_y = {},
        lualine_z = {}
    },
    diff_color = {
        added = {
          fg = 0,
        },
        modified = {
          fg = 0,
        },
        removed = {
          fg = 0,
        },
    }
}
-- }}}
-- [[ Telescope ]] {{{
-- See `:help telescope` and `:help telescope.setup()`

local utils = require('telescope.utils')
local entry_display = require("telescope.pickers.entry_display")

local custom_path_display = function(_opts, path)
    local name = utils.path_tail(path)
    local path = path
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
}

-- Enable telescope fzf native, if installed
pcall(require('telescope').load_extension, 'fzf')

-- See `:help telescope.builtin`
vim.keymap.set('n', '<leader>rh', require('telescope.builtin').oldfiles, { desc = '[R]ecent [H]istory old files' })
vim.keymap.set('n', '<leader>b',require('telescope.builtin').current_buffer_fuzzy_find, { desc = '[B] Fuzzily search in current buffer]' })
vim.keymap.set('n', 'z=',require('telescope.builtin').spell_suggest, { desc = 'Spell suggestions' })

vim.keymap.set('n', '<leader>t', require('telescope.builtin').git_files, { desc = 'Search Git Files' })
vim.keymap.set('n', '<leader>T', function ()
    return require('telescope.builtin').find_files({
        no_ignore = true,
    })
end
, { desc = 'Search ALL Files' })
-- nnoremap <leader>T <cmd>lua require('telescope.builtin').find_files({find_command = {'rg', '--files', '--no-ignore', '--glob', '!*.class'}})<cr>
vim.keymap.set('n', '<leader>sh', require('telescope.builtin').help_tags, { desc = '[S]earch [H]elp' })

local findFilesForWordUnderCursor = function ()
    local word = vim.fn.expand "<cword>"
    require('telescope.builtin').find_files({
        grep_open_files = true,
        search_file = word,
        no_ignore = true,
    })
end
vim.keymap.set('n', '<leader>sf', findFilesForWordUnderCursor, { desc = '[S]earch current [F]ile' })

local findFilesForWordUnderCursor = function ()
    local word = vim.fn.expand "<cword>"
    require('telescope.builtin').find_files({
        grep_open_files = true,
        search_file = word,
        no_ignore = false,
    })
end
vim.keymap.set('n', '<leader>sF', findFilesForWordUnderCursor, { desc = '[S]earch current [F]ile' })

vim.keymap.set('n', '<leader>sw', require('telescope.builtin').grep_string, {
    desc = '[S]earch current [W]ord'
})

vim.keymap.set('v', '<leader>rg', function ()
    vim.cmd("normal v")
    local visual_selection = string.sub(vim.fn.getline("'<"), vim.fn.col("'<"), vim.fn.col("'>"))
    return require('telescope.builtin').live_grep({
        default_text = visual_selection,
        glob = {
            "!changelog",
            "!vendor",
            "!*_test.go",
            "!*Test.java",
        }
    })
end
, { desc = '[S]earch source using [G]rep' })
vim.keymap.set('v', '<leader>Rg', function ()
    vim.cmd("normal v")
    local visual_selection = string.sub(vim.fn.getline("'<"), vim.fn.col("'<"), vim.fn.col("'>"))
    return require('telescope.builtin').live_grep({
        default_text = visual_selection,
        glob = {
            "!changelog",
            "!vendor",
        }
    })
end
, { desc = '[S]earch all files using [G]rep' })

vim.keymap.set('n', '<leader>rg', function ()
    return require('telescope.builtin').live_grep({
        glob = {
            "!changelog",
            "!vendor",
            "!*_test.go",
            "!*Test.java",
        }
    })
end
, { desc = '[S]earch source using [G]rep' })
vim.keymap.set('n', '<leader>Rg', function ()
    return require('telescope.builtin').live_grep({
        glob = {
            "!changelog",
            "!vendor",
        }
    })
end
, { desc = '[S]earch all files using [G]rep' })

vim.keymap.set('n', '<leader>sd', require('telescope.builtin').diagnostics, { desc = '[S]earch [D]iagnostics' })

-- }}}
-- [[ Treesitter ]] {{{
-- See `:help nvim-treesitter`
require('nvim-treesitter.configs').setup {
  -- Add languages to be installed here that you want installed for treesitter
  ensure_installed = { 'java', 'c', 'cpp', 'go', 'lua', 'python', 'rust', 'typescript', 'help', 'vim' },
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
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
      include_surrounding_whitespace = function (table)
        local blockList = {
            ["@parameter.inner"] = true,
            ["@parameter.outer"] = true,
            ["@function.inner"] = true,
        }
        return not blockList[table["query_string"]]
    end
    },
  },
}
--- }}}
-- [[ Mason ]] {{{
-- [ nvim-cmp {{{
-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)
-- }}}

-- Setup mason so it can manage external tooling
require('mason').setup()

-- Ensure the servers above are installed
local mason_lspconfig = require 'mason-lspconfig'

mason_lspconfig.setup {
  ensure_installed = vim.tbl_keys(servers),
}

mason_lspconfig.setup_handlers {
  function(server_name)
    require('lspconfig')[server_name].setup {
      capabilities = capabilities,
      on_attach = on_attach,
      settings = servers[server_name],
    }
  end,
}
-- }}}
-- [[ nvim-cmp ]] {{{
local cmp = require 'cmp'
local luasnip = require 'luasnip'

cmp.setup {
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert {
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete({}),
    ['<C-n>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { 'i', 's' }),
    ['<C-p>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { 'i', 's' }),
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
  },
}
-- }}}
-- [[ Harpoon ]] {{{

require("telescope").load_extension('harpoon')
vim.keymap.set('n', '<leader>rm', require('harpoon.ui').toggle_quick_menu, { desc = 'Harpoon files' })
vim.api.nvim_create_user_command('HarpoonAddFile', function() 
    return require('harpoon.mark').add_file()
end, {})
vim.api.nvim_create_user_command('HarpoonList', function() 
    return require('harpoon.ui').toggle_quick_menu()
end
    , {})

vim.cmd("hi! link HarpoonWindow Normal")
vim.cmd("hi! link HarpoonBorder Normal")

require("harpoon").setup({
    menu = {
        width = math.min(vim.api.nvim_win_get_width(0) - 10, 180),
    }
})

-- }}}
-- Simple Setups {{{
require('Comment').setup()
require('neodev').setup()
require('fidget').setup()
-- }}}

vim.cmd('source ~/.config/nvim/lua-migration/plugins.vim')
-- }}}
-- }}}

-- [[ Settings ]] {{{
-- [[ Options ]] {{{

vim.cmd('source ~/.config/nvim/lua-migration/set.vim')
-- }}}
-- [[ Keymaps ]] {{{
-- See `:help vim.keymap.set()`

vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

vim.cmd('source ~/.config/nvim/lua-migration/keymaps.vim')
-- }}}
-- }}}

-- [[ Random ]] {{{
vim.cmd('source ~/.config/nvim/lua-migration/testBlock.vim')
vim.cmd('source ~/.config/nvim/spell/abbrev.vim')
-- }}}
-- vim: set foldmethod=marker: set foldlevel=0
