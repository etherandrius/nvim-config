-- Keep buffers and rust-analyzer diagnostics in sync with files changed outside
-- of Neovim (cargo, scripts, agents). Platform independent.

-- Poll once a second, so buffers reload while nvim sits idle. The FocusGained /
-- BufEnter / CursorHold autocmds in init.lua only fire on activity.
-- checktime only stats the loaded buffers, so this is cheap.
local reload_timer = assert(vim.uv.new_timer())
reload_timer:start(1000, 1000, vim.schedule_wrap(function()
    local mode = vim.api.nvim_get_mode().mode
    if mode:sub(1, 1) == "c" or vim.fn.getcmdwintype() ~= "" then
        return -- checktime isn't allowed in the command line / cmdwin
    end
    vim.cmd("silent! checktime")
end))

-- rust-analyzer only runs `cargo check` when nvim saves a file, so its compiler
-- diagnostics go stale when files change on disk. Re-run it (debounced) after
-- an external change is reloaded, and when nvim regains focus.
local flycheck_timer = assert(vim.uv.new_timer())
local function rust_flycheck_soon()
    flycheck_timer:stop()
    flycheck_timer:start(500, 0, vim.schedule_wrap(function()
        if #vim.lsp.get_clients({ name = "rust-analyzer" }) > 0 and vim.fn.exists(":RustLsp") == 2 then
            pcall(vim.cmd.RustLsp, "flyCheck")
        end
    end))
end

local group = vim.api.nvim_create_augroup("external-changes", { clear = true })
vim.api.nvim_create_autocmd("FileChangedShellPost", {
    group = group,
    pattern = { "*.rs", "Cargo.toml", "Cargo.lock" },
    callback = rust_flycheck_soon,
    desc = "Re-run cargo check after a Rust file changed outside of Neovim",
})
vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = rust_flycheck_soon,
    desc = "Re-run cargo check when returning to Neovim",
})
