local hippo_path = os.getenv("PROJECT_DIR") .. "/mt/hippo"
if vim.fn.isdirectory(hippo_path) == 0 then
    return {}
end

return {
    dir = hippo_path,
    -- The plugin is pure Lua; it runs the `hippo` CLI, which this installs.
    build = "cargo install --path hippo-cli --locked",
    config = function()
        vim.opt.runtimepath:append(hippo_path .. "/hippo-nvim")
        require("hippo").setup({
            notes_dir = os.getenv("NOTES_DIR"),
            log_level = "warn",
        })
    end,
}
