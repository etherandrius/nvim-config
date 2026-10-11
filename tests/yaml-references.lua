-- nvim --headless -u NONE -l tests/yaml-references.lua
-- NVIM_TEST_TELESCOPE=1 also exercises the installed Telescope picker + jumplist.
local config = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(config)
vim.o.hidden = true
local telescope = vim.env.NVIM_TEST_TELESCOPE == '1'
if telescope then
    for _, plugin in ipairs({ 'plenary.nvim', 'telescope.nvim' }) do
        vim.opt.runtimepath:append(vim.fn.stdpath('data') .. '/lazy/' .. plugin)
    end
    require('telescope').setup({ defaults = { initial_mode = 'normal' } })
end
local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/.git', 'p')
root = vim.uv.fs_realpath(root)
local fixtures = {}
local function write(path, text)
    vim.fn.mkdir(vim.fs.dirname(root .. '/' .. path), 'p')
    fixtures[path] = vim.split(text, '\n', { trimempty = true })
    vim.fn.writefile(fixtures[path], root .. '/' .. path)
end
write('.gitignore', 'ignored/')
write('spec/types.yml', [[
types:
  imports:
    External:
      external:
        java: example.External
  definitions:
    objects:
      Thing:
        alias: string
      Unused:
        alias: string
      Usage:
        fields:
          local: Thing
          external: External
          Thing: string
    errors:
      Failure:
        namespace: Example
        code: INVALID_ARGUMENT
services:
  Example:
    endpoints:
      fetch:
        returns: Thing
        errors:
          - Failure
        docs: |
          May return Thing or fail with Failure.
# Thing in a whole-line comment is not a reference.
]])
write('other/types.yml', [[
types:
  definitions:
    objects:
      Thing:
        alias: string
    errors:
      Failure:
        namespace: Other
        code: NOT_FOUND
]])
write('client/use.yml', [[
types:
  conjure-imports:
    defs: ../spec/types.yml
    alt: ../other/types.yml
  definitions:
    objects:
      Thing:
        alias: string
      Request:
        fields:
          both: map<defs.Thing, list<defs.Thing>>
          unrelated: map<alt.Thing, Thing>
          longer: defs.ThingExtra
          unknown: nonexistent.Thing
services:
  Example:
    endpoints:
      fetch:
        errors:
          - defs.Failure
          - alt.Failure
        docs: |
          Can return defs.Thing.
]])
write('consumer.yaml', [[
types:
  conjure-imports:
    differentAlias: spec/types.yml
services:
  Another:
    endpoints:
      fetch:
        returns: differentAlias.Thing
        errors:
          - differentAlias.Failure
]])
write('ignored/generated.yml', [[
types:
  conjure-imports:
    defs: ../spec/types.yml
services:
  Generated:
    docs: defs.Thing
]])
write('ordinary.yml', 'description: defs.Thing')
write('unsaved.yml', [[
types:
  conjure-imports:
    defs: spec/types.yml
services:
  Unsaved:
    docs: Nothing here yet.
]])

local notifications = {}
local notify = vim.notify
vim.notify = function(message) notifications[#notifications + 1] = message end
local original_request = vim.lsp.buf_request_sync
vim.lsp.buf_request_sync = function() error('References must not use LSP tagfunc') end
local navigation = require('conjure-definition')
local function find(path, text, symbol, occurrence)
    for number, line in ipairs(fixtures[path]) do
        if line:find(text, 1, true) then
            local column = 0
            for _ = 1, occurrence or 1 do
                column = assert(line:find(symbol, column + 1, true))
            end
            return number, column
        end
    end
    error('fixture text not found: ' .. text)
end
local function open(path, text, symbol)
    vim.cmd.edit(vim.fn.fnameescape(root .. '/' .. path))
    dofile(config .. '/ftplugin/yaml.lua')
    vim.bo.tagfunc = 'v:lua.vim.lsp.tagfunc'
    local row, column = find(path, text, symbol)
    vim.api.nvim_win_set_cursor(0, { row, column - 1 })
end
local function references()
    local result
    assert(navigation.references(function(value) result = value end))
    assert(vim.wait(10000, function() return result ~= nil end), 'reference search timed out')
    assert(not result.error, result.error)
    assert(result.skipped == 0)
    return result
end
local function check(result, expected)
    local actual = {}
    for _, item in ipairs(result.items) do
        actual[item.filename .. ':' .. item.lnum .. ':' .. item.col] = true
    end
    assert(#result.items == #expected, 'expected ' .. #expected .. ' references, got ' .. #result.items)
    for _, item in ipairs(expected) do
        local row, column = find(unpack(item))
        local key = root .. '/' .. item[1] .. ':' .. row .. ':' .. column
        assert(actual[key], 'missing reference: ' .. key)
    end
end

local ok, err = xpcall(function()
    open('spec/types.yml', '      Thing:', 'Thing')
    local expected = {
        { 'spec/types.yml', 'local: Thing', 'Thing' },
        { 'spec/types.yml', 'returns: Thing', 'Thing' },
        { 'spec/types.yml', 'May return Thing', 'Thing' },
        { 'client/use.yml', 'both:', 'defs.Thing', 1 },
        { 'client/use.yml', 'both:', 'defs.Thing', 2 },
        { 'client/use.yml', 'Can return', 'defs.Thing' },
        { 'consumer.yaml', 'returns:', 'differentAlias.Thing' },
    }
    check(references(), expected)
    -- Starting from an imported use yields the same declaration identity.
    open('client/use.yml', 'both:', 'defs.Thing')
    check(references(), expected)
    open('spec/types.yml', '      Failure:', 'Failure')
    check(references(), {
        { 'spec/types.yml', '- Failure', 'Failure' },
        { 'spec/types.yml', 'May return Thing', 'Failure' },
        { 'client/use.yml', '- defs.Failure', 'defs.Failure' },
        { 'consumer.yaml', '- differentAlias.Failure', 'differentAlias.Failure' },
    })
    open('spec/types.yml', '    External:', 'External')
    check(references(), { { 'spec/types.yml', 'external: External', 'External' } })
    open('spec/types.yml', '      Unused:', 'Unused')
    check(references(), {})

    -- Include unsaved uses even if ripgrep cannot find the name on disk.
    open('unsaved.yml', 'Nothing here', 'Nothing')
    fixtures['unsaved.yml'][6] = '    docs: defs.Thing'
    vim.api.nvim_buf_set_lines(0, 0, -1, false, fixtures['unsaved.yml'])
    open('spec/types.yml', '      Thing:', 'Thing')
    expected[#expected + 1] = { 'unsaved.yml', 'docs:', 'defs.Thing' }
    check(references(), expected)

    -- Selecting a gr result must support one Ctrl-O back and Ctrl-I forward,
    -- both within the same file and across files. Opening/cancelling a picker
    -- should not insert an intermediate jump.
    for _, source in ipairs({
        { 'client/use.yml', 'Can return', 'defs.Thing' },
        { 'spec/types.yml', '      Thing:', 'Thing' },
    }) do
        -- An already-open destination at a different position must not become
        -- an intermediate Ctrl-O stop during a cross-file selection.
        open('client/use.yml', 'unknown:', 'nonexistent.Thing')
        open(unpack(source))
        local buffer, position = vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)
        local window = vim.api.nvim_get_current_win()
        vim.cmd.clearjumps()
        vim.fn.maparg('gr', 'n', false, true).callback()
        if telescope then
            assert(vim.wait(10000, function() return vim.bo.filetype == 'TelescopePrompt' end))
            local prompt = vim.api.nvim_get_current_buf()
            local state = require('telescope.actions.state')
            assert(vim.wait(10000, function()
                return state.get_current_picker(prompt):get_selection() ~= nil
            end))
            require('telescope.actions').select_default(prompt)
        else
            assert(vim.wait(10000, function() return vim.bo.buftype == 'quickfix' end))
            vim.cmd.cclose()
            vim.cmd.cfirst()
        end
        assert(vim.api.nvim_get_current_win() == window)
        local target_buffer, target_position = vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)
        assert(vim.api.nvim_buf_get_name(0) == root .. '/client/use.yml')
        assert(target_position[1] == find('client/use.yml', 'both:', 'defs.Thing'))
        vim.cmd('normal! ' .. string.char(15))
        assert(vim.api.nvim_get_current_buf() == buffer, 'Ctrl-O returned to wrong buffer')
        assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), position), 'Ctrl-O returned to wrong position')
        vim.api.nvim_feedkeys(string.char(9), 'nx', false)
        assert(vim.api.nvim_get_current_buf() == target_buffer)
        assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), target_position),
            'Ctrl-I returned to wrong position: expected ' .. vim.inspect(target_position)
                .. ', got ' .. vim.inspect(vim.api.nvim_win_get_cursor(0)) .. ', source ' .. source[1])
    end

    if telescope then
        open('spec/types.yml', '      Thing:', 'Thing')
        local buffer, position = vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)
        vim.cmd.clearjumps()
        vim.fn.maparg('gr', 'n', false, true).callback()
        assert(vim.wait(10000, function() return vim.bo.filetype == 'TelescopePrompt' end))
        require('telescope.actions').close(vim.api.nvim_get_current_buf())
        assert(vim.api.nvim_get_current_buf() == buffer)
        assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), position))
        assert(#vim.fn.getjumplist()[1] == 0, 'cancelled picker polluted the jumplist')
    end

    -- Empty results leave navigation alone, and tool failures must not look like
    -- a successful empty search.
    open('spec/types.yml', '      Unused:', 'Unused')
    local before = #notifications
    vim.fn.maparg('gr', 'n', false, true).callback()
    assert(vim.wait(10000, function() return #notifications > before end))
    assert(notifications[#notifications]:find('No references found', 1, true))
    open('spec/types.yml', '      Thing:', 'Thing')
    local system, failure = vim.system, nil
    vim.system = function(_, _, callback) callback({ code = 2, stderr = 'test rg failure' }) end
    navigation.references(function(result) failure = result end)
    vim.system = system
    assert(vim.wait(10000, function() return failure ~= nil end))
    assert(failure.error:find('test rg failure', 1, true))

    -- Non-Conjure YAML keeps the existing Telescope LSP references binding.
    local builtin = package.loaded['telescope.builtin']
    local called = false
    package.loaded['telescope.builtin'] = { lsp_references = function() called = true end }
    open('ordinary.yml', 'description:', 'description')
    vim.fn.maparg('gr', 'n', false, true).callback()
    package.loaded['telescope.builtin'] = builtin
    assert(called, 'lost non-Conjure LSP references fallback')
end, debug.traceback)

vim.notify = notify
vim.lsp.buf_request_sync = original_request
vim.fn.delete(root, 'rf')
if not ok then error(err) end
print('PASS: Conjure references, imports/errors, unsaved buffers, ' .. (telescope and 'Telescope' or 'quickfix')
    .. ' selection, Ctrl-O/Ctrl-I, and LSP fallback')
