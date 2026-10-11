-- Resolve Conjure type and error references directly from their source files. Unlike a
-- repository-wide tag search, this respects file-local names and conjure-imports.
local M = {}

local function parse(lines)
    local spec = { objects = {}, errors = {}, imports = {}, files = {}, is_conjure = false }
    local parents = {}
    for number, line in ipairs(lines) do
        local indent, key, value = line:match('^(%s*)([%w_-]+):%s*(.*)$')
        if key then
            while #parents > 0 and parents[#parents].indent >= #indent do
                table.remove(parents)
            end
            local keys = {}
            for _, parent in ipairs(parents) do
                keys[#keys + 1] = parent.key
            end
            local path = table.concat(keys, '.')
            if path == 'types' and (key == 'definitions' or key == 'imports' or key == 'conjure-imports') then
                spec.is_conjure = true
            elseif path == 'types.definitions.objects' then
                spec.objects[key] = number
            elseif path == 'types.definitions.errors' then
                spec.errors[key] = number
            elseif path == 'types.imports' then
                -- External types resolve to their local import declaration, not
                -- to generated Java or an unrelated same-named repository type.
                spec.imports[key] = number
            elseif path == 'types.conjure-imports' then
                spec.files[key] = value:match('^"([^"]+)"')
                    or value:match("^'([^']+)'") or value:match('^([^%s#]+)')
            end
            parents[#parents + 1] = { key = key, indent = #indent }
        end
    end
    return spec
end

local function symbols(line)
    local start = 1
    return function()
        local first, last = line:find('[%a_][%w_.]*', start)
        if first then
            start = last + 1
            -- References also appear in docs, where a sentence may end in Name.
            return line:sub(first, last):gsub('%.+$', ''), first, last
        end
    end
end

local function symbol_at_cursor()
    local column = vim.api.nvim_win_get_cursor(0)[2] + 1
    for symbol, first, last in symbols(vim.api.nvim_get_current_line()) do
        if column >= first and column <= last then
            return symbol
        end
    end
end

local function read_source(filename)
    local buffer = vim.fn.bufnr(filename)
    if buffer ~= -1 and vim.api.nvim_buf_is_loaded(buffer) then
        return vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
    end
    return vim.fn.readfile(filename)
end

-- nil means this is not a Conjure document; otherwise return a tag-shaped
-- location or a useful error. Never fall back to a same-named type in another file.
function M.resolve()
    local spec = parse(vim.api.nvim_buf_get_lines(0, 0, -1, false))
    if not spec.is_conjure then
        return nil
    end
    local symbol = symbol_at_cursor()
    if not symbol then
        return { error = 'Put the cursor on a Conjure type or error name' }
    end

    local filename = vim.api.nvim_buf_get_name(0)
    local namespace, name = symbol:match('^([%w_]+)%.([%w_]+)$')
    name = name or symbol
    if namespace then
        local import = spec.files[namespace]
        if not import then
            return { error = 'Unknown Conjure import: ' .. namespace }
        end
        filename = vim.fn.simplify(vim.fn.fnamemodify(filename, ':h') .. '/' .. import)
        local ok, lines = pcall(read_source, filename)
        if not ok then
            return { error = 'Cannot read Conjure import: ' .. filename }
        end
        spec = parse(lines)
    end

    local number = spec.objects[name] or spec.errors[name] or spec.imports[name]
    if not number then
        return { error = 'No Conjure declaration for ' .. symbol .. ' (built-in type or missing definition)' }
    end
    return { tag = { name = symbol, filename = filename, cmd = tostring(number) } }
end

local function canonical_path(filename)
    return vim.uv.fs_realpath(filename) or vim.fn.simplify(vim.fn.fnamemodify(filename, ':p'))
end

local reference_request = 0

-- Asynchronous, import-aware references within the current repository (or the
-- current file's directory outside Git). Includes documentation mentions, but
-- not declarations, mapping keys, or whole-line comments. This is source-level
-- navigation, not references from generated Java/TypeScript or other repos.
-- Return false only for non-Conjure documents, so the caller can use its LSP.
function M.references(callback)
    reference_request = reference_request + 1
    local request = reference_request
    local resolved = M.resolve()
    if not resolved then
        return false
    end
    if resolved.error then
        callback(resolved)
        return true
    end
    if vim.fn.executable('rg') == 0 then
        callback({ error = 'Conjure references require ripgrep (rg)' })
        return true
    end

    local source = canonical_path(vim.api.nvim_buf_get_name(0))
    local target = canonical_path(resolved.tag.filename)
    local name = resolved.tag.name:match('([%w_]+)$')
    local root = vim.fs.root(source, '.git') or vim.fs.dirname(source)
    -- Prefilter asynchronously, respecting normal ripgrep ignore rules. Resolve
    -- aliases below rather than treating every same-named word as a reference.
    vim.system({ 'rg', '-l', '-0', '-F', '-g', '*.yml', '-g', '*.yaml', '--', name, root },
        { text = true, timeout = 10000 }, vim.schedule_wrap(function(result)
            if request ~= reference_request then
                return -- A newer gr superseded this search.
            end
            if result.code ~= 0 and result.code ~= 1 then
                local detail = vim.trim(result.stderr or '')
                if detail == '' then detail = 'exit code ' .. tostring(result.code) end
                callback({ error = 'Conjure reference search failed: ' .. detail })
                return
            end
            local files = { [source] = true, [target] = true }
            for filename in (result.stdout or ''):gmatch('[^%z]+') do
                files[canonical_path(filename)] = true
            end
            -- The on-disk prefilter cannot see new references in unsaved files.
            local buffers = {}
            for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_loaded(buffer) and vim.bo[buffer].buftype == '' then
                    local filename = canonical_path(vim.api.nvim_buf_get_name(buffer))
                    if filename == source or filename == target
                        or (vim.startswith(filename, root .. '/') and filename:match('%.ya?ml$')) then
                        files[filename] = true
                        buffers[filename] = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
                    end
                end
            end

            local items, skipped = {}, 0
            for filename in pairs(files) do
                local ok, lines = true, buffers[filename]
                if not lines then
                    ok, lines = pcall(read_source, filename)
                end
                if not ok then
                    skipped = skipped + 1
                else
                    local spec = parse(lines)
                    if spec.is_conjure then
                        local names = {}
                        if filename == target then
                            names[name] = true
                        end
                        for alias, import in pairs(spec.files) do
                            if canonical_path(vim.fs.dirname(filename) .. '/' .. import) == target then
                                names[alias .. '.' .. name] = true
                            end
                        end
                        for number, line in ipairs(lines) do
                            if not line:match('^%s*#') then
                                local key_end = line:match('^%s*[%w_-]+():') or 0
                                for symbol, column in symbols(line) do
                                    if column > key_end and names[symbol] then
                                        items[#items + 1] = {
                                            filename = filename, lnum = number, col = column, text = line,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
            table.sort(items, function(a, b)
                if a.filename ~= b.filename then return a.filename < b.filename end
                if a.lnum ~= b.lnum then return a.lnum < b.lnum end
                return a.col < b.col
            end)
            callback({ items = items, title = 'Conjure references: ' .. name, root = root, skipped = skipped })
        end))
    return true
end

return M
