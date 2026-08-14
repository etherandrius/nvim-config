vim.opt_local.wrap = true
-- Scroll by screen line rather than whole wrapped lines, so <C-E>/<C-Y> (and
-- anything built on them, e.g. `ze`) land where you asked instead of jumping a
-- whole paragraph.
vim.opt_local.smoothscroll = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
vim.opt_local.spell = true
vim.opt_local.colorcolumn = {}
vim.opt_local.textwidth = 0

-- Folding by heading level via treesitter
-- vim.opt_local.foldmethod = "expr"
-- vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
-- vim.opt_local.foldlevel = 99
