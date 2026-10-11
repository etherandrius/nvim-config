local M = {}

local function show(result)
    if result.error then
        vim.notify(result.error, vim.log.levels.WARN)
        return
    end
    if result.skipped > 0 then
        vim.notify(('Conjure references: skipped %d unreadable files'):format(result.skipped), vim.log.levels.WARN)
    end
    if #result.items == 0 then
        vim.notify('No references found: ' .. result.title)
        return
    end

    local available, pickers = pcall(require, 'telescope.pickers')
    if available then
        local config = require('telescope.config')
        -- Use the same entry formatting as the existing LSP references picker.
        local opts = vim.tbl_extend('force', {}, config.pickers.lsp_references or {}, { cwd = result.root })
        local attach = opts.attach_mappings
        opts.attach_mappings = function(prompt, map)
            if attach and attach(prompt, map) == false then return false end
            local actions = require('telescope.actions')
            actions.select_default:replace(function()
                local entry = require('telescope.actions.state').get_selected_entry()
                if not entry then return end
                local item = entry.value
                actions.close(prompt)
                -- Telescope's ordinary edit can add the destination buffer's old
                -- cursor as an intermediate jump. Use the same single-jump path
                -- as built-in LSP definitions instead (columns here are bytes).
                local position = { line = item.lnum - 1, character = item.col - 1 }
                vim.lsp.util.show_document({
                    uri = vim.uri_from_fname(item.filename),
                    range = { start = position, ['end'] = position },
                }, 'utf-8', { focus = true })
            end)
            return true
        end
        pickers.new(opts, {
            prompt_title = result.title,
            push_cursor_on_edit = true,
            push_tagstack_on_edit = true,
            finder = require('telescope.finders').new_table({
                results = result.items,
                entry_maker = opts.entry_maker or require('telescope.make_entry').gen_from_quickfix(opts),
            }),
            previewer = config.values.qflist_previewer(opts),
            sorter = config.values.generic_sorter(opts),
        }):find()
    else
        vim.fn.setqflist({}, ' ', { title = result.title, items = result.items })
        vim.cmd.copen()
    end
end

function M.show()
    if not require('conjure-definition').references(show) then
        require('telescope.builtin').lsp_references()
    end
end

return M
