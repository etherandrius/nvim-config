local ns_id = vim.api.nvim_create_namespace("notes_tags_hover")

local function get_notes_dir()
  local value = os.getenv("NOTES_DIR")
  if not value then
    return nil
  end
  value = value:gsub("/$", "")
  return vim.fn.expand(value)
end

local function relative_time(mtime)
  local now = os.time()
  local diff = now - mtime
  if diff < 0 then
    return "just now"
  end

  local minutes = math.floor(diff / 60)
  local hours = math.floor(diff / 3600)
  local days = math.floor(diff / 86400)
  local months = math.floor(diff / 2592000)
  local years = math.floor(diff / 31536000)

  if diff < 60 then
    return "just now"
  elseif minutes == 1 then
    return "1 minute ago"
  elseif minutes < 60 then
    return minutes .. " minutes ago"
  elseif hours == 1 then
    return "1 hour ago"
  elseif hours < 24 then
    return hours .. " hours ago"
  elseif days == 1 then
    return "1 day ago"
  elseif days < 30 then
    return days .. " days ago"
  elseif months == 1 then
    return "1 month ago"
  elseif months < 12 then
    return months .. " months ago"
  elseif years == 1 then
    return "1 year ago"
  else
    return years .. " years ago"
  end
end

local hover_seq = {}

local function resolve_link_async(bufnr, line_idx, col, seq)
  if hover_seq[bufnr] ~= seq then
    return
  end

  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = { line = line_idx, character = col },
  }

  vim.lsp.buf_request(bufnr, "textDocument/definition", params, function(err, result)
    if hover_seq[bufnr] ~= seq then
      return
    end
    if err or not result then
      return
    end

    -- result can be a single Location or a list of Locations/LocationLinks
    local items = vim.islist(result) and result or { result }
    if #items == 0 then
      return
    end

    local uri = items[1].uri or items[1].targetUri
    if not uri then
      return
    end

    local filepath = vim.uri_to_fname(uri)
    local stat = vim.uv.fs_stat(filepath)
    local display
    if stat then
      display = "· " .. relative_time(stat.mtime.sec)
    else
      display = "· not found"
    end

    -- Schedule UI update back on main loop
    vim.schedule(function()
      if hover_seq[bufnr] ~= seq then
        return
      end
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_idx, 0, {
        virt_text = { { display, "Comment" } },
        virt_text_pos = "eol",
      })
    end)
  end)
end

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
    local start, _, link_name = line:find("%[%[(.-)%]%]")
    if link_name and line:match("^%s*%[%[.-%]%]%s*$") then
      local line_idx = i - 1
      -- Place cursor inside the link text (after [[)
      local col = start + 1
      resolve_link_async(bufnr, line_idx, col, seq)
    end
  end
end

local notes_dir = get_notes_dir()
if notes_dir then
  vim.api.nvim_create_autocmd("LspAttach", {
    pattern = "*.md",
    callback = show_tags_hover,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*.md",
    callback = show_tags_hover,
  })
end
