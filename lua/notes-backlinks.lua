local ns_id = vim.api.nvim_create_namespace("backlinks")

local function find_first_heading(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:match("^#+%s") then
      return i - 1  -- 0-indexed
    end
  end
  return nil
end

local function show_backlinks()
  local bufnr = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local title_line = find_first_heading(bufnr)
  if not title_line then
    return
  end

  local position = {
    line = title_line,
    character = 0
  }

  vim.lsp.buf_request(bufnr, 'textDocument/references', {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = position,
    context = { includeDeclaration = true }
  }, function(err, result)
    if err or not result or #result == 0 then
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
      return
    end

    local virt_lines = {}
    local line_text = table.concat(filenames, ", ")
    table.insert(virt_lines, {
      { "Refs: ", "Keyword" },
      { line_text, "Comment" }
    })

    vim.api.nvim_buf_set_extmark(bufnr, ns_id, title_line, 0, {
      virt_lines = virt_lines,
      virt_lines_above = false,
    })
  end)
end

local notes_dir_value = os.getenv("NOTES_DIR")
if notes_dir_value then
  notes_dir_value = notes_dir_value:gsub("/$", "")
  local notes_dir = vim.fn.expand(notes_dir_value)

  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.md",
    callback = function()
      local filepath = vim.fn.expand("%:p")
      if string.find(filepath, notes_dir, 1, true) then
        show_backlinks()
      end
    end,
  })
end
