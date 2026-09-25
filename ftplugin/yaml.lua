-- Jump from an OpenAPI/OmniAPI reference to its definition via the tags file.
--
-- `<cword>` is useless on a line like
--   $ref: '../common/ontology-api.yml#/components/schemas/ActionTypeRid'
-- because `/` and `.` split the word. This reads the whole ref instead: the
-- last path segment is the tag name, and the file part (when present)
-- disambiguates names that exist in both the OmniAPI and legacy OpenAPI specs.

local function ref_on_line()
    local line = vim.api.nvim_get_current_line()
    return line:match("['\"]([^'\"]-#/[^'\"]+)['\"]") or line:match("%$ref:%s*(%S+#/%S+)")
end

-- Jump to one specific taglist entry. Deliberately not `:{count}tag`: that
-- counts in `:tselect` order, which promotes matches in the current file,
-- whereas taglist() returns tags-file order. Indexing across the two inverts.
local function goto_tag(tag)
    local from = vim.fn.getpos('.')
    from[1] = vim.api.nvim_get_current_buf()
    vim.fn.settagstack(vim.fn.win_getid(), { items = { { tagname = tag.name, from = from } } }, 'a')

    vim.cmd('edit ' .. vim.fn.fnameescape(tag.filename))
    if tag.cmd:match('^%d+$') then
        vim.cmd(tag.cmd)
    else
        vim.fn.cursor(1, 1)
        vim.fn.search(tag.cmd:gsub('^/', ''):gsub('/$', ''), 'cW')
    end
end

local function jump_to_ref()
    local ref = ref_on_line()
    if not ref then
        -- Bare OmniAPI reference (`jsonSchema: AnthropicJsonSchemaOutputFormat`);
        -- the builtin behaviour is already correct.
        local keys = vim.api.nvim_replace_termcodes('<C-]>', true, false, true)
        vim.cmd('normal! ' .. keys)
        return
    end

    local name = ref:match('([^/]+)$')
    local file = ref:match('^([^#]*)')
    local matches = vim.fn.taglist('^' .. vim.fn.escape(name, '\\.*$^~[]') .. '$')

    if vim.tbl_isempty(matches) then
        vim.notify('No tag for ' .. name .. ' (stale tags file?)', vim.log.levels.WARN)
        return
    end

    local want = (file ~= '' and vim.fn.simplify(vim.fn.expand('%:p:h') .. '/' .. file))
        or vim.fn.expand('%:p')

    for _, tag in ipairs(matches) do
        if vim.fn.simplify(vim.fn.fnamemodify(tag.filename, ':p')) == want then
            goto_tag(tag)
            return
        end
    end

    -- Ref points somewhere the tags file does not cover: let the user pick.
    vim.cmd((#matches == 1 and 'tag ' or 'tjump ') .. name)
end

vim.keymap.set('n', '<C-]>', jump_to_ref, { buffer = true, desc = 'Jump to $ref / component definition' })
