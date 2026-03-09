local value = os.getenv("NOTES_PATH")
if value then
    value = value:gsub("/$", "")
    local notes_dir = vim.fn.expand(value)
    vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "*.md",
        callback = function()
            local filepath = vim.fn.expand("%:p")
            -- Only run if file is in notes directory
            if not string.find(filepath, notes_dir, 1, true) then
                print("no?", filepath, notes_dir)
                return
            end
            -- Only apply template if file is empty
            local line_count = vim.api.nvim_buf_line_count(0)
            if line_count == 1 and vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "" then
                local date = os.date("%Y-%m-%d")
                local filename = vim.fn.expand("%:t:r") -- filename without extension
                local lines = {
                    "# " .. filename,
                    "",
                    "Date: " .. date,
                    "Tags: ",
                    "",
                    "---",
                    "",
                    "",
                }
                vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
                -- Place cursor at the end
                vim.api.nvim_win_set_cursor(0, { #lines, 0 })
            end
        end,
    })
end
