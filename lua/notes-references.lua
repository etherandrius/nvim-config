local M = {}
local sequence = 0

-- References are position-based in LSP. With title_from_heading=false, an H1
-- denotes a heading, not the document. Query a transient link to the document
-- instead; Marksman then supplies semantic backlinks (including section links).
-- The query exists only in the server: no file, editor buffer, or self-link is
-- written. Always close it, including on error/timeout.
function M.request(bufnr, callback, opts)
    bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
    opts = opts or {}
    local clients = vim.lsp.get_clients({ bufnr = bufnr, name = 'marksman' })
    if #clients ~= 1 then
        callback('Expected one attached Marksman client; found ' .. #clients)
        return
    end
    local client = clients[1]
    local name = vim.api.nvim_buf_get_name(bufnr)
    local path = vim.uv.fs_realpath(name) or vim.fs.normalize(name)
    local root = client.config.root_dir
    if type(root) ~= 'string' or root == '' then
        callback('Marksman has no workspace root for this note')
        return
    end
    root = vim.uv.fs_realpath(root) or vim.fs.normalize(root)
    local prefix = root:gsub('/+$', '') .. '/'
    if path:sub(1, #prefix) ~= prefix then
        callback('The current note is outside the Marksman workspace')
        return
    end
    local relative = path:sub(#prefix + 1)
    if not (relative:match('%.md$') or relative:match('%.markdown$')) or relative:find('%c') then
        callback('NoteReferences requires a Markdown filename without control characters')
        return
    end
    relative = relative:gsub('%.markdown$', ''):gsub('%.md$', '')
    -- A root-relative path avoids conflating duplicate basenames. Escape wiki
    -- syntax delimiters while retaining ordinary path separators and Unicode.
    relative = relative:gsub('[%%%[%]#|]', function(char)
        return string.format('%%%02X', char:byte())
    end)

    local query_path
    repeat
        sequence = sequence + 1
        query_path = prefix .. '.marksman-note-references-' .. vim.fn.getpid() .. '-' .. sequence .. '.md'
    until not vim.uv.fs_stat(query_path)
    local uri = vim.uri_from_fname(query_path)
    if not client:notify('textDocument/didOpen', {
        textDocument = { uri = uri, languageId = 'markdown', version = 1, text = '[[' .. relative .. ']]' },
    }) then
        callback('Could not open the Marksman reference query')
        return
    end

    local finished, timer = false, nil
    local function finish(err, locations)
        if finished then return end
        finished = true
        if timer and not timer:is_closing() then
            timer:stop()
            timer:close()
        end
        client:notify('textDocument/didClose', { textDocument = { uri = uri } })
        if err then
            callback(type(err) == 'table' and (err.message or vim.inspect(err)) or tostring(err))
            return
        end
        local result, seen = {}, {}
        if locations == vim.NIL then locations = nil end
        for _, location in ipairs(locations or {}) do
            local key = location.uri .. ':' .. vim.json.encode(location.range)
            if location.uri ~= uri and not seen[key] then
                seen[key] = true
                result[#result + 1] = location
            end
        end
        callback(nil, result, client.offset_encoding)
    end

    local sent, request_id = client:request('textDocument/references', {
        textDocument = { uri = uri },
        position = { line = 0, character = 2 },
        context = { includeDeclaration = false },
    }, finish, bufnr)
    if not sent then
        finish('Could not request Marksman note references')
    elseif not finished then
        timer = vim.defer_fn(function()
            -- Close first so cancellation callbacks cannot overwrite the timeout.
            finish('Marksman note references timed out')
            client:cancel_request(request_id)
        end, opts.timeout_ms or 5000)
    end
end

function M.show()
    local bufnr = vim.api.nvim_get_current_buf()
    local title = 'Note references: ' .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':t:r')
    M.request(bufnr, function(err, locations, encoding)
        if err then
            vim.notify(err, vim.log.levels.WARN)
            return
        end
        -- Do not open a picker over an unrelated buffer after the user switches.
        if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_get_current_buf() ~= bufnr then return end
        if #locations == 0 then
            vim.notify('No whole-note references found', vim.log.levels.INFO)
            return
        end
        local items = vim.lsp.util.locations_to_items(locations, encoding)
        local available, pickers = pcall(require, 'telescope.pickers')
        if not available then
            vim.fn.setqflist({}, ' ', { title = title, items = items })
            vim.cmd('copen')
            return
        end
        local config = require('telescope.config')
        local picker_opts = vim.tbl_extend('force', {}, config.pickers.lsp_references or {})
        pickers.new(picker_opts, {
            prompt_title = title,
            finder = require('telescope.finders').new_table({
                results = items,
                entry_maker = picker_opts.entry_maker or require('telescope.make_entry').gen_from_quickfix(picker_opts),
            }),
            previewer = config.values.qflist_previewer(picker_opts),
            sorter = config.values.generic_sorter(picker_opts),
            push_cursor_on_edit = true,
            push_tagstack_on_edit = true,
        }):find()
    end)
end

return M
