local ns_id = vim.api.nvim_create_namespace("backlinks")
local cache = {} -- bufnr -> { title_line, filenames }

local function find_first_heading(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:match("^#+%s") then
      return i - 1  -- 0-indexed
    end
  end
  return nil
end

local function render_backlinks(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local cached = cache[bufnr]
  if not cached then return end

  local title_line = cached.title_line
  local filenames = cached.filenames
  local prefix = "Refs: "
  local max_width = vim.api.nvim_win_get_width(0) - #prefix
  local virt_lines = {}
  local current = {}
  local current_len = 0

  for i, fname in ipairs(filenames) do
    local sep = i < #filenames and ", " or ""
    local token = fname .. sep
    if current_len + #token > max_width and #current > 0 then
      local indent = #virt_lines == 0 and { prefix, "Keyword" } or { string.rep(" ", #prefix), "Normal" }
      table.insert(virt_lines, { indent, { table.concat(current), "Comment" } })
      current, current_len = {}, 0
    end
    table.insert(current, token)
    current_len = current_len + #token
  end

  if #current > 0 then
    local indent = #virt_lines == 0 and { prefix, "Keyword" } or { string.rep(" ", #prefix), "Normal" }
    table.insert(virt_lines, { indent, { table.concat(current), "Comment" } })
  end

  vim.api.nvim_buf_set_extmark(bufnr, ns_id, title_line, 0, {
    virt_lines = virt_lines,
    virt_lines_above = false,
  })
end

local function fetch_backlinks(bufnr)
  local title_line = find_first_heading(bufnr)
  if not title_line then
    cache[bufnr] = nil
    return
  end

  vim.lsp.buf_request(bufnr, 'textDocument/references', {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = { line = title_line, character = 0 },
    context = { includeDeclaration = true }
  }, function(err, result)
    if err or not result or #result == 0 then
      cache[bufnr] = nil
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
      cache[bufnr] = nil
      return
    end

    cache[bufnr] = { title_line = title_line, filenames = filenames }
    render_backlinks(bufnr)
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

  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      if is_note(bufnr) then
        render_backlinks(bufnr)
      end
    end,
  })
end
