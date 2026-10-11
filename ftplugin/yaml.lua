-- Jump to Conjure source declarations or OpenAPI/OmniAPI definitions in tags.
--
-- `<cword>` is useless on a line like
--   $ref: '../common/ontology-api.yml#/components/schemas/ActionTypeRid'
-- because `/` and `.` split the word. This reads the whole ref instead: the
-- last path segment is the tag name, and the file part (when present)
-- disambiguates names that exist in both the OmniAPI and legacy OpenAPI specs.

-- Find repository tags even when Neovim was opened in a nested directory.
vim.opt_local.tags:prepend('./tags;')

local function ref_on_line()
    local line = vim.api.nvim_get_current_line()
    return line:match("['\"]([^'\"]-#/[^'\"]+)['\"]") or line:match("%$ref:%s*(%S*#/%S+)")
end

local function with_file_tags(action)
    -- LSP attachment sets tagfunc=vim.lsp.tagfunc. That redirects taglist() to
    -- workspace/symbol, which yamlls does not support. Bypass it for the entire
    -- jump (including :tag/:tjump), then restore the *source* buffer on errors
    -- as well as success. Do not disable LSP navigation elsewhere.
    local buffer = vim.api.nvim_get_current_buf()
    local tagfunc = vim.bo[buffer].tagfunc
    vim.bo[buffer].tagfunc = ''
    local ok, err = pcall(action)
    if vim.api.nvim_buf_is_valid(buffer) then
        vim.bo[buffer].tagfunc = tagfunc
    end
    if not ok then
        error(err, 0)
    end
end

local function canonical_path(filename)
    return vim.uv.fs_realpath(filename) or vim.fn.simplify(vim.fn.fnamemodify(filename, ':p'))
end

-- Jump to one specific taglist entry. Deliberately not `:{count}tag`: that
-- counts in `:tselect` order, which promotes matches in the current file,
-- whereas taglist() returns tags-file order. Indexing across the two inverts.
local function goto_tag(tag)
    local from = vim.fn.getpos('.')
    from[1] = vim.api.nvim_get_current_buf()
    -- Like vim.lsp.util.show_document: record the source for Ctrl-O / Ctrl-I.
    -- Suppress intermediate edit/line jumps so one Ctrl-O returns to the call site.
    vim.cmd("normal! m'")
    if canonical_path(tag.filename) ~= canonical_path(vim.api.nvim_buf_get_name(0)) then
        vim.cmd('keepjumps edit ' .. vim.fn.fnameescape(tag.filename))
    end
    vim.fn.settagstack(vim.fn.win_getid(), { items = { { tagname = tag.name, from = from } } }, 'a')
    if tag.cmd:match('^%d+$') then
        vim.api.nvim_win_set_cursor(0, { tonumber(tag.cmd), 0 })
    else
        vim.fn.cursor(1, 1)
        vim.fn.search(tag.cmd:gsub('^/', ''):gsub('/$', ''), 'cW')
    end
end

local function jump_to_ref(use_lsp_fallback)
    local conjure = require('conjure-definition').resolve()
    if conjure then
        if conjure.tag then
            goto_tag(conjure.tag)
        else
            vim.notify(conjure.error, vim.log.levels.WARN)
        end
        return
    end

    local ref = ref_on_line()
    -- Bare OmniAPI references use the word under the cursor.
    local name = ref and ref:match('([^/]+)$') or vim.fn.expand('<cword>')
    local file = ref and ref:match('^([^#]*)') or ''
    local matches = vim.fn.taglist('^' .. vim.fn.escape(name, '\\.*$^~[]') .. '$')

    if vim.tbl_isempty(matches) then
        if use_lsp_fallback and not ref then
            vim.lsp.buf.definition()
        else
            vim.notify('No tag for ' .. name .. ' (missing or stale tags file?)', vim.log.levels.WARN)
        end
        return
    end

    local want = canonical_path(file ~= '' and (vim.fn.expand('%:p:h') .. '/' .. file)
        or vim.fn.expand('%:p'))

    for _, tag in ipairs(matches) do
        if canonical_path(tag.filename) == want then
            goto_tag(tag)
            return
        end
    end

    -- Ref points somewhere the tags file does not cover: let the user pick.
    vim.cmd({ cmd = #matches == 1 and 'tag' or 'tjump', args = { name } })
end

vim.keymap.set('n', '<C-]>', function()
    with_file_tags(function() jump_to_ref(false) end)
end, { buffer = true, desc = 'Jump to API / Conjure definition (tags)' })
vim.keymap.set('n', 'gd', function()
    with_file_tags(function() jump_to_ref(true) end)
end, { buffer = true, desc = 'Jump to API / Conjure definition (LSP fallback)' })

vim.keymap.set('n', 'gr', function()
    require('conjure-references').show()
end, { buffer = true, desc = 'Conjure references (LSP fallback)' })

local undo = 'setlocal tags< | silent! nunmap <buffer> <C-]> | silent! nunmap <buffer> gd'
    .. ' | silent! nunmap <buffer> gr'
vim.b.undo_ftplugin = vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. ' | ' .. undo) or undo
