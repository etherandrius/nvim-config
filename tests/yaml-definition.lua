-- Run from this config: nvim --headless -u NONE -l tests/yaml-definition.lua
local config = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(config)
vim.o.hidden = true
local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/api', 'p')
vim.fn.mkdir(root .. '/conjure', 'p')
local original_cwd = vim.fn.getcwd()
local original_notify = vim.notify
local original_request = vim.lsp.buf_request_sync
-- Exercise the real LSP tagfunc, but fail if it ever tries to query a server.
vim.lsp.buf_request_sync = function(_, method)
    error('Unexpected LSP request from tags: ' .. method)
end
local messages = {}
vim.notify = function(message) messages[#messages + 1] = message end

local function write(path, lines)
    vim.fn.writefile(lines, root .. '/' .. path)
end

write('api/source.yml', {
    "$ref: '#/components/schemas/Shared'",
    '    Shared:',
    "$ref: './other.yml#/components/schemas/Shared'",
    "$ref: './unindexed.yml#/components/schemas/Unique'",
    'jsonSchema: Unique',
    'jsonSchema: Missing',
    "$ref: '#/components/schemas/Unknown'",
})
write('api/other.yml', { '    Shared:', '    Unique:' })
write('tags', {
    '!_TAG_FILE_SORTED\t1\t/sorted/',
    'Shared\tapi/other.yml\t/^    Shared:$/;"\ts',
    'Shared\tapi/source.yml\t/^    Shared:$/;"\ts',
    'Unique\tapi/other.yml\t2;"\ts',
})
write('conjure/source.yml', {
    'types:',
    '  conjure-imports:',
    '    common: "common.yml" # same-named type in a different file',
    '    missing: missing.yml',
    '  imports:',
    '    External:',
    '      external:',
    '        java: example.External',
    '  definitions:',
    '    default-package: example',
    '    objects:',
    '      Request:',
    '        fields:',
    '          local: optional<Shared>',
    '          imported: map<Shared, list<common.Shared>>',
    '          external: External',
    '          missing: missing.Shared',
    '          unknown: unknown.Shared',
    '          unresolved: NoSuchType',
    '          primitive: string',
    '      Shared:',
    '        alias: string',
})
write('conjure/common.yml', {
    'types:',
    '  definitions:',
    '    default-package: example',
    '    objects:',
    '      Shared:',
    '        alias: string',
})

write('conjure/error-service.yml', {
    'types:',
    '  conjure-imports:',
    '    other: errors-only.yml',
    '  definitions:',
    '    objects:',
    '      Id:',
    '        alias: string',
    '    errors:',
    '      Failure:',
    '        namespace: Example',
    '        code: INVALID_ARGUMENT',
    '        safe-args:',
    '          id: Id',
    'services:',
    '  TestService:',
    '    endpoints:',
    '      test:',
    '        errors:',
    '          - Failure',
    '          - other.Failure',
    '        docs: |',
    '          Can fail with Failure.',
    '          Can also fail with other.Failure.',
})
write('conjure/errors-only.yml', {
    'types:',
    '  definitions:',
    '    errors:',
    '      Failure:',
    '        namespace: Other',
    '        code: NOT_FOUND',
})

local tagfunc = 'v:lua.vim.lsp.tagfunc'
local function open(path, line, symbol)
    vim.cmd.edit(vim.fn.fnameescape(root .. '/' .. path))
    dofile(config .. '/ftplugin/yaml.lua')
    vim.bo.tagfunc = tagfunc
    local text = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]
    local column = symbol and assert(text:find(symbol, 1, true)) or 1
    vim.api.nvim_win_set_cursor(0, { line, column - 1 })
    return vim.api.nvim_get_current_buf(), column - 1
end
local function jump(key)
    local mapping = vim.fn.maparg(key or '<C-]>', 'n', false, true)
    assert(type(mapping.callback) == 'function', 'missing mapping')
    mapping.callback()
end
local function location(path, line)
    assert(vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0)) == vim.uv.fs_realpath(root .. '/' .. path),
        'wrong destination file')
    assert(vim.fn.line('.') == line, 'wrong destination line: ' .. vim.fn.line('.'))
end
local function check_jump(path, line, symbol, destination, target_line, key)
    local source, column = open(path, line, symbol)
    vim.cmd.clearjumps()
    jump(key)
    location(destination, target_line)
    assert(vim.bo[source].tagfunc == tagfunc, 'source tagfunc was not restored')
    local destination_column = vim.fn.col('.')
    vim.cmd('normal! ' .. string.char(15)) -- Ctrl-O
    location(path, line)
    assert(vim.fn.col('.') == column + 1, 'jumplist lost source column')
    vim.api.nvim_feedkeys(string.char(9), 'nx', false) -- Ctrl-I (a literal Tab)
    location(destination, target_line)
    assert(vim.fn.col('.') == destination_column, 'jumplist lost destination column')
    vim.cmd('normal! ' .. string.char(20)) -- Ctrl-T
    location(path, line)
    assert(vim.fn.col('.') == column + 1, 'tag stack lost source column')
end

local ok, err = xpcall(function()
    -- Tags must be found by walking upward from the file, not just from cwd.
    vim.cmd.cd(vim.fn.fnameescape(root .. '/conjure'))
    check_jump('api/source.yml', 1, nil, 'api/source.yml', 2)
    check_jump('api/source.yml', 3, nil, 'api/other.yml', 1, 'gd')
    assert(vim.bo[vim.fn.bufnr(root .. '/api/other.yml')].tagfunc == '', 'changed target tagfunc')
    check_jump('api/source.yml', 4, nil, 'api/other.yml', 2) -- :tag fallback
    check_jump('api/source.yml', 5, 'Unique', 'api/other.yml', 2)
    check_jump('api/source.yml', 5, 'Unique', 'api/other.yml', 2, 'gd')

    open('api/source.yml', 7)
    jump()
    location('api/source.yml', 7)
    assert(messages[#messages]:find('No tag for Unknown', 1, true))
    assert(vim.bo.tagfunc == tagfunc)

    -- A regular YAML gd still reaches the LSP when there is no tag.
    local definition = vim.lsp.buf.definition
    local called = false
    vim.lsp.buf.definition = function() called = true end
    open('api/source.yml', 6, 'Missing')
    jump('gd')
    vim.lsp.buf.definition = definition
    assert(called, 'lost regular YAML LSP fallback')
    assert(vim.bo.tagfunc == tagfunc)

    -- Cleanup must also run when an underlying tag operation throws.
    local taglist = vim.fn.taglist
    vim.fn.taglist = function() error('test taglist failure') end
    local success, failure = pcall(jump)
    vim.fn.taglist = taglist
    assert(not success and tostring(failure):find('test taglist failure', 1, true))
    assert(vim.bo.tagfunc == tagfunc, 'tagfunc not restored on error')

    -- Conjure needs no tags file, and must disambiguate via conjure-imports.
    vim.fn.delete(root .. '/tags')
    check_jump('conjure/source.yml', 14, 'Shared', 'conjure/source.yml', 21, 'gd')
    check_jump('conjure/source.yml', 15, 'Shared', 'conjure/source.yml', 21)
    check_jump('conjure/source.yml', 15, 'common', 'conjure/common.yml', 5, 'gd')
    check_jump('conjure/source.yml', 15, 'Shared>>', 'conjure/common.yml', 5)
    check_jump('conjure/source.yml', 16, 'External', 'conjure/source.yml', 6)
    for line, symbol in pairs({ [17] = 'missing.Shared', [18] = 'unknown.Shared', [19] = 'NoSuchType', [20] = 'string' }) do
        open('conjure/source.yml', line, symbol)
        local count = #messages
        jump('gd')
        location('conjure/source.yml', line)
        assert(#messages == count + 1, 'missing unresolved-type warning')
        assert(vim.bo.tagfunc == tagfunc)
    end

    -- Error names resolve locally or through imports, even in errors-only files.
    -- Same-named errors in different files must not be confused.
    check_jump('conjure/error-service.yml', 19, 'Failure', 'conjure/error-service.yml', 9, 'gd')
    check_jump('conjure/error-service.yml', 19, 'Failure', 'conjure/error-service.yml', 9)
    check_jump('conjure/error-service.yml', 20, 'other', 'conjure/errors-only.yml', 4, 'gd')
    check_jump('conjure/error-service.yml', 20, 'Failure', 'conjure/errors-only.yml', 4)
    check_jump('conjure/error-service.yml', 13, 'Id', 'conjure/error-service.yml', 6, 'gd')
    -- Sentence-ending punctuation in docs is not part of the identifier.
    check_jump('conjure/error-service.yml', 22, 'Failure', 'conjure/error-service.yml', 9, 'gd')
    check_jump('conjure/error-service.yml', 23, 'Failure', 'conjure/errors-only.yml', 4, 'gd')

    -- Local and imported definitions use unsaved buffer contents.
    open('conjure/common.yml', 5)
    vim.api.nvim_buf_set_lines(0, 4, 4, false, { '      # unsaved comment' })
    open('conjure/source.yml', 15, 'common')
    jump('gd')
    location('conjure/common.yml', 6)
    open('conjure/source.yml', 14, 'Shared')
    vim.api.nvim_buf_set_lines(0, 20, 20, false, { '      # unsaved comment' })
    jump('gd')
    location('conjure/source.yml', 22)
end, debug.traceback)

vim.notify = original_notify
vim.lsp.buf_request_sync = original_request
vim.cmd.cd(vim.fn.fnameescape(original_cwd))
vim.fn.delete(root, 'rf')
if not ok then
    error(err)
end
print('PASS: YAML tags, LSP isolation/fallback, Conjure types/errors, Ctrl-O/Ctrl-I, and Ctrl-T')
