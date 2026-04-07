local ns_id = vim.api.nvim_create_namespace("notes_tags_hover")

local function get_notes_dir()
  local value = os.getenv("NOTES_DIR")
  if not value then
    return nil
  end
  value = value:gsub("/$", "")
  return vim.fn.expand(value)
end

local function read_tags_from_file(filepath)
  local f = io.open(filepath, "r")
  if not f then
    return nil
  end
  local tags = {}
  for line in f:lines() do
    if line:match("^Tags:") then
      for tag in line:gmatch("%[%[(.-)%]%]") do
        table.insert(tags, tag)
      end
      f:close()
      return tags
    end
  end
  f:close()
  return nil
end

local hover_seq = {}

local function show_tags_hover()
  local bufnr = vim.api.nvim_get_current_buf()
  local notes_dir = get_notes_dir()
  if not notes_dir then
    return
  end

  local filepath = vim.fn.expand("%:p")
  if not string.find(filepath, notes_dir, 1, true) then
    return
  end

  local seq = (hover_seq[bufnr] or 0) + 1
  hover_seq[bufnr] = seq

  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for i, line in ipairs(lines) do
    local link_name = line:match("^%s*%[%[(.-)%]%]%s*$")
    if link_name then
      local line_idx = i - 1
      -- Find the position of the link text for LSP go-to-definition
      local col = line:find("%[%[")
      if col then
        col = col + 1 -- place cursor inside the [[

        vim.lsp.buf_request(bufnr, "textDocument/definition", {
          textDocument = vim.lsp.util.make_text_document_params(bufnr),
          position = { line = line_idx, character = col },
        }, function(err, result)
          if hover_seq[bufnr] ~= seq then return end

          local display = "()"

          if not err and result then
            -- result can be a single Location or a list
            local loc = result
            if vim.islist(result) and #result > 0 then
              loc = result[1]
            end

            local uri = loc and (loc.uri or loc.targetUri)
            if uri then
              local target_path = vim.uri_to_fname(uri)
              local tags = read_tags_from_file(target_path)
              if tags and #tags > 0 then
                display = table.concat(tags, ", ")
              end
            end
          end

          vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 0, {
            virt_text = { { display, "Comment" } },
            virt_text_pos = "eol",
          })
        end)
      end
    end
  end
end

local notes_dir = get_notes_dir()
if notes_dir then
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    pattern = "*.md",
    callback = show_tags_hover,
  })
end
