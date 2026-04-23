local REFS_PATTERN = "^Refs:"

local function find_first_heading(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:match("^#+%s") then
      return i - 1  -- 0-indexed
    end
  end
  return nil
end

local function find_refs_lines(bufnr, after_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, after_line + 1, -1, false)
  local found = {}
  for i, line in ipairs(lines) do
    if line:match(REFS_PATTERN) then
      table.insert(found, after_line + i)  -- 0-indexed
    elseif line:match("^#+%s") then
      break
    end
  end
  return found
end

local function remove_refs_lines(bufnr, title_line)
  local found = find_refs_lines(bufnr, title_line)
  for i = #found, 1, -1 do
    vim.api.nvim_buf_set_lines(bufnr, found[i], found[i] + 1, false, {})
  end
end

local function get_existing_refs(bufnr, title_line)
  local found = find_refs_lines(bufnr, title_line)
  local texts = {}
  for _, line_nr in ipairs(found) do
    table.insert(texts, vim.api.nvim_buf_get_lines(bufnr, line_nr, line_nr + 1, false)[1])
  end
  return texts
end

local function write_backlinks(bufnr, title_line, filenames)
  local refs_text = "Refs: " .. table.concat(filenames, ", ")
  local existing = get_existing_refs(bufnr, title_line)
  if #existing == 1 and existing[1] == refs_text then return end
  remove_refs_lines(bufnr, title_line)
  vim.api.nvim_buf_set_lines(bufnr, title_line + 1, title_line + 1, false, { refs_text })
end

local notes_dir_value = os.getenv("NOTES_DIR")
if notes_dir_value then
  notes_dir_value = notes_dir_value:gsub("/$", "")
  local notes_dir = vim.fn.expand(notes_dir_value)

  local function fetch_backlinks(bufnr)
    local title_line = find_first_heading(bufnr)
    if not title_line then return end

    local current_path = vim.api.nvim_buf_get_name(bufnr)
    local current_name = current_path:match("([^/]+)%.md$")
    if not current_name then return end

    local pattern = "%[%[" .. vim.pesc(current_name) .. "%]%]"

    -- grep notes dir in background to avoid blocking
    vim.system(
      { "grep", "-rl", "--include=*.md", "\\[\\[" .. current_name .. "\\]\\]", notes_dir },
      {},
      vim.schedule_wrap(function(result)
        -- buffer may have been closed
        if not vim.api.nvim_buf_is_valid(bufnr) then return end

        local current_title = find_first_heading(bufnr)
        if not current_title then return end

        if result.code ~= 0 or not result.stdout or result.stdout == "" then
          if #find_refs_lines(bufnr, current_title) > 0 then
            remove_refs_lines(bufnr, current_title)
          end
          return
        end

        local filenames = {}
        local seen = {}
        for abs in result.stdout:gmatch("[^\n]+") do
          if abs ~= current_path then
            local rel = abs:gsub("^" .. vim.pesc(notes_dir) .. "/", ""):gsub("%.md$", "")
            if not seen[rel] then
              table.insert(filenames, rel)
              seen[rel] = true
            end
          end
        end

        if #filenames == 0 then
          if #find_refs_lines(bufnr, current_title) > 0 then
            remove_refs_lines(bufnr, current_title)
          end
          return
        end

        write_backlinks(bufnr, current_title, filenames)
      end)
    )
  end

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
