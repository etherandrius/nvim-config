-- Run: nvim --headless -u NONE -i NONE -l ~/.config/nvim/tests/notes-references.lua
local config = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
vim.opt.rtp:prepend(config)
local refs = require('notes-references')
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
root = vim.uv.fs_realpath(root)
local checks = 0
local function check(ok, label)
    assert(ok, label)
    checks = checks + 1
end
local function write(path, lines)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    vim.fn.writefile(lines, path)
end
write(root .. '/.marksman.toml', { '[core]', 'title_from_heading = false' })
write(root .. '/nested/target.md', { '# Human title, not the filename', '', '## Details', '', '[[#details]]' })
write(root .. '/other/target.md', { '# Different note with same basename' })
write(root .. '/incoming.md', {
    '---', 'links: "[[nested/target]]"', '---', '# Incoming', '',
    '[[nested/target]]', '[[nested/target#details]]',
    '[Target](nested/target.md)', '[Section](nested/target.md#details)',
    '[[other/target]]', '`[[nested/target]]`',
})
local b = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(b)
vim.api.nvim_buf_set_name(b, root .. '/nested/target.md')
vim.api.nvim_buf_set_lines(b, 0, -1, false, vim.fn.readfile(root .. '/nested/target.md'))
local original_lines = vim.api.nvim_buf_get_lines(b, 0, -1, false)
local original_tick = vim.api.nvim_buf_get_changedtick(b)

-- Failure paths must not leak an in-memory document or create any file.
local original_get_clients = vim.lsp.get_clients
local calls, handler, cancelled, fake_uri
local fake = { config = { root_dir = root }, offset_encoding = 'utf-16' }
function fake:notify(method, params)
    calls[#calls + 1] = method
    if method == 'textDocument/didOpen' then fake_uri = params.textDocument.uri end
    return true
end
function fake:request(_, _, cb)
    handler = cb
    return true, 42
end
function fake:cancel_request(id) cancelled = id end
local function request_with(client_list, opts)
    calls, handler, cancelled, fake_uri = {}, nil, nil, nil
    vim.lsp.get_clients = function() return client_list end
    local done, outcome = false, nil
    refs.request(b, function(err, locations)
        done, outcome = true, { err = err, locations = locations }
    end, opts)
    return function()
        check(vim.wait(2000, function() return done end, 10), 'request finishes')
        return outcome
    end
end
local done = request_with({})
check(done().err:match('found 0') ~= nil, 'missing client is explicit')
done = request_with({ fake, fake })
check(done().err:match('found 2') ~= nil, 'ambiguous client rejected')
done = request_with({ fake })
handler({ message = 'server failure' })
check(done().err == 'server failure', 'server errors reported')
check(calls[#calls] == 'textDocument/didClose', 'query closed on error')
check(not vim.uv.fs_stat(vim.uri_to_fname(fake_uri)), 'query never written to disk')
done = request_with({ fake }, { timeout_ms = 20 })
check(done().err:match('timed out') ~= nil, 'timeout reported')
check(cancelled == 42, 'timed-out request cancelled')
check(calls[#calls] == 'textDocument/didClose', 'query closed on timeout')
local close_count = #calls
handler(nil, {})
check(#calls == close_count, 'late response does not close twice')
local original_request = fake.request
fake.request = function() return false end
done = request_with({ fake })
check(done().err:match('Could not request') ~= nil, 'send failure reported')
check(calls[#calls] == 'textDocument/didClose', 'query closed on send failure')
fake.request = original_request
vim.lsp.get_clients = original_get_clients

-- Use the installed real server for backlink semantics, not grep approximations.
local executable = vim.env.MARKSMAN_BIN or (vim.fn.stdpath('data') .. '/mason/bin/marksman')
check(vim.fn.executable(executable) == 1, 'Marksman executable available')
local id = vim.lsp.start({ name = 'marksman', cmd = { executable, 'server' }, root_dir = root })
local client = vim.lsp.get_client_by_id(id)
check(vim.wait(15000, function() return client.initialized end, 30), 'Marksman initializes')
local function query()
    local done, failure, locations = false, nil, nil
    refs.request(b, function(err, result)
        done, failure, locations = true, err, result
    end)
    check(vim.wait(10000, function() return done end, 20), 'live reference query completes')
    check(not failure, failure or 'no request error')
    return locations
end
for _ = 1, 2 do
    local locations = query()
    check(#locations == 4, 'four explicit document backlinks, including section and Markdown links')
    local lines = {}
    for _, loc in ipairs(locations) do
        check(loc.uri == vim.uri_from_fname(root .. '/incoming.md'), 'no transient query/self/declaration locations')
        lines[#lines + 1] = loc.range.start.line
    end
    table.sort(lines)
    check(vim.deep_equal(lines, { 5, 6, 7, 8 }), 'exclude duplicate-basename target, YAML and inline code')
end
check(vim.deep_equal(vim.api.nvim_buf_get_lines(b, 0, -1, false), original_lines), 'note content unchanged')
check(vim.api.nvim_buf_get_changedtick(b) == original_tick, 'note undo/edit state unchanged')
check(#vim.fn.glob(root .. '/.marksman-note-references-*', false, true) == 0, 'no query files created')

-- Bindings are Markdown-local and do not replace gr.
vim.keymap.set('n', 'gr', '<Nop>')
dofile(config .. '/ftplugin/markdown.lua')
check(vim.fn.maparg('gr', 'n') == '<Nop>', 'gr unchanged')
check(vim.fn.maparg('gR', 'n', false, true).buffer == 1, 'gR buffer-local')
check(vim.api.nvim_buf_get_commands(b, {}).NoteReferences ~= nil, 'NoteReferences buffer command exists')
dofile(config .. '/ftplugin/markdown.lua')
check(vim.api.nvim_buf_get_commands(b, {}).NoteReferences ~= nil, 'ftplugin safe to reload')

-- Exercise the real Telescope presentation as well as the LSP request layer.
for _, plugin in ipairs({ 'plenary.nvim', 'telescope.nvim' }) do
    vim.opt.rtp:append(vim.fn.stdpath('data') .. '/lazy/' .. plugin)
end
require('telescope').setup({})
refs.show()
check(vim.wait(5000, function() return vim.bo.filetype == 'TelescopePrompt' end, 20), 'Telescope picker opens')
local prompt = vim.api.nvim_get_current_buf()
local picker = require('telescope.actions.state').get_current_picker(prompt)
check(vim.wait(3000, function() return picker.manager:num_results() == 4 end, 20), 'picker contains the four references')
require('telescope.actions').close(prompt)
check(vim.api.nvim_get_current_buf() == b, 'closing picker returns to source note')

client:stop(true)
vim.fn.delete(root, 'rf')
print(string.format('%d checks passed', checks))
vim.cmd('qa!')
