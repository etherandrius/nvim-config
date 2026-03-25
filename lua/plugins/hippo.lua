local hippo_path = os.getenv("PROJECT_DIR") .. "/mt/hippo"
if vim.fn.isdirectory(hippo_path) == 0 then
    return {}
end

return {
    dir = hippo_path,
    build = "hippo-nvim/build.sh",
    config = function()
        vim.opt.runtimepath:append(hippo_path .. "/hippo-nvim")
        require("hippo").setup({
            notes_dir = os.getenv("NOTES_DIR"),
            log_level = "debug",
        })
    end,
}
