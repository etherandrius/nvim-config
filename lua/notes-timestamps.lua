local M = {}

function M.now()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

-- Only touch top-level timestamp fields; never guess a legacy note's creation time.
function M.update(lines, timestamp, is_new)
  local result = vim.deepcopy(lines)
  local closing
  if result[1] == "---" then
    for i = 2, #result do
      if result[i] == "---" or result[i] == "..." then
        closing = i
        break
      end
    end
    if not closing then return nil, "Unclosed YAML frontmatter" end
  else
    table.insert(result, 1, "---")
    table.insert(result, 2, "---")
    table.insert(result, 3, "")
    closing = 2
  end

  local created, updated, note_type
  for i = 2, closing - 1 do
    if result[i]:match("^createdTime:") then
      if created then return nil, "Duplicate createdTime field" end
      created = i
    elseif result[i]:match("^updatedTime:") then
      if updated then return nil, "Duplicate updatedTime field" end
      updated = i
    elseif result[i]:match("^type:") then
      if note_type then return nil, "Duplicate type field" end
      note_type = i
    end
  end
  -- Missing fields go at the top of the frontmatter: createdTime, then updatedTime.
  if updated then
    result[updated] = 'updatedTime: "' .. timestamp .. '"'
  else
    updated = created and created + 1 or 2
    table.insert(result, updated, 'updatedTime: "' .. timestamp .. '"')
  end
  if is_new and not created then
    table.insert(result, updated, 'createdTime: "' .. timestamp .. '"')
    updated = updated + 1
  end
  -- A genuinely new manual note defaults to leaf. Never infer the role of a
  -- legacy note or overwrite an explicit hub; :CreateHub supplies type: hub.
  if is_new and not note_type then
    table.insert(result, updated + 1, "type: leaf")
  end
  return result
end

function M.is_note(filepath, notes_dir)
  if not notes_dir or notes_dir == "" then return false end
  local root = vim.fs.normalize(vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(notes_dir), ":p"))):gsub("/$", "")
  local path = vim.fs.normalize(vim.fn.resolve(vim.fn.fnamemodify(filepath, ":p")))
  local name = vim.fs.basename(path)
  return path:sub(1, #root + 1) == root .. "/"
    and path:match("%.md$") ~= nil
    and name ~= "AGENTS.md" and name ~= "CLAUDE.md" and name ~= "todo.md"
end

function M.setup()
  local group = vim.api.nvim_create_augroup("NotesTimestamps", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    pattern = "*.md",
    callback = function(event)
      local path = vim.api.nvim_buf_get_name(event.buf)
      if not M.is_note(path, os.getenv("NOTES_DIR")) then return end
      local is_new = vim.uv.fs_stat(path) == nil
      if not is_new and not vim.bo[event.buf].modified then return end
      local lines = vim.api.nvim_buf_get_lines(event.buf, 0, -1, false)
      local updated, err = M.update(lines, M.now(), is_new)
      if not updated then
        -- Refuse the save rather than silently writing a note without valid timestamps.
        error("Note timestamps: " .. err)
      end
      if vim.deep_equal(lines, updated) then return end
      local view = vim.fn.winsaveview()
      vim.api.nvim_buf_set_lines(event.buf, 0, -1, false, updated)
      vim.fn.winrestview(view)
    end,
  })
end

return M
