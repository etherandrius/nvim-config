local REFS_PATTERN = "^Refs: "

local function find_first_heading(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:match("^#+%s") then
      return i - 1  -- 0-indexed
    end
  end
  return nil
end

local function find_refs_line(bufnr, after_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, after_line + 1, after_line + 3, false)
  for i, line in ipairs(lines) do
    if line:match(REFS_PATTERN) then
      return after_line + i  -- 0-indexed
    end
  end
  return nil
end

local function write_backlinks(bufnr, title_line, filenames)
  local refs_text = "Refs: " .. table.concat(filenames, ", ")
  local existing = find_refs_line(bufnr, title_line)

  if existing then
    local current = vim.api.nvim_buf_get_lines(bufnr, existing, existing + 1, false)[1]
    if current == refs_text then return end
    vim.api.nvim_buf_set_lines(bufnr, existing, existing + 1, false, { refs_text })
  else
    vim.api.nvim_buf_set_lines(bufnr, title_line + 1, title_line + 1, false, { refs_text })
  end
end

local function remove_refs_line(bufnr, title_line)
  local existing = find_refs_line(bufnr, title_line)
  if existing then
    vim.api.nvim_buf_set_lines(bufnr, existing, existing + 1, false, {})
  end
end

local function fetch_backlinks(bufnr)
  local title_line = find_first_heading(bufnr)
  if not title_line then return end

  vim.lsp.buf_request(bufnr, 'textDocument/references', {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = { line = title_line, character = 0 },
    context = { includeDeclaration = true }
  }, function(err, result)
    if err or not result or #result == 0 then
      remove_refs_line(bufnr, title_line)
      return
    end

    local current_filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
    local filenames = {}
    local seen = {}
    for _, loc in ipairs(result) do
      local fname = vim.fn.fnamemodify(loc.uri:gsub("^file://", ""), ":t:r")
      if fname ~= vim.fn.fnamemodify(current_filename, ":r") and not seen[fname] then
        table.insert(filenames, fname)
        seen[fname] = true
      end
    end

    if #filenames == 0 then
      remove_refs_line(bufnr, title_line)
      return
    end

    write_backlinks(bufnr, title_line, filenames)
  end)
end

local notes_dir_value = os.getenv("NOTES_DIR")
if notes_dir_value then
  notes_dir_value = notes_dir_value:gsub("/$", "")
  local notes_dir = vim.fn.expand(notes_dir_value)

  local function is_note(bufnr)
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    return filepath:match("%.md$") and string.find(filepath, notes_dir, 1, true)
  end

  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.md",
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      if is_note(bufnr) then
        fetch_backlinks(bufnr)
      end
    end,
  })
end
