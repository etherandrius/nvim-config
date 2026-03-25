vim.opt_local.wrap = true
vim.opt_local.spell = true
vim.opt_local.colorcolumn = {}
vim.opt_local.textwidth = 0

-- Folding by heading level via treesitter
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt_local.foldlevel = 99
