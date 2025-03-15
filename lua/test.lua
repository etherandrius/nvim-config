-- Function to set readonly mode for cargo registry files
local function set_cargo_registry_readonly()
    local buffer_path = vim.fn.expand('%:p')
    local home = os.getenv("HOME")
    if not home then
        vim.api.nvim_echo({ { "$HOME not set?", "WarningMsg" } }, true, {})
        return
    end

    local isCargoDep = string.find(buffer_path, home .. "/.cargo/registry/src")
    local isRustup = string.find(buffer_path, home .. "/.rustup/toolchains")
    if isCargoDep or isRustup then
        vim.cmd('set readonly')
    end
end

local cargo_registry_augroup = vim.api.nvim_create_augroup("CargoRegistryReadOnly", { clear = true })
vim.api.nvim_create_autocmd({ "BufReadPost" }, {
    group = cargo_registry_augroup,
    callback = set_cargo_registry_readonly,
    desc = "Set cargo registry files to readonly mode"
})
