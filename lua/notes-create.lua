local function get_notes_dir()
  local value = os.getenv("NOTES_DIR")
  if not value then return nil end
  value = value:gsub("/$", "")
  return vim.fn.expand(value)
end

local function is_in_notes(filepath, notes_dir)
  return filepath:match("%.md$") and string.find(filepath, notes_dir, 1, true)
end

local function slugify(title)
  return title:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
end

local function finish_create(title, notes_dir)
  local current_file = vim.fn.expand("%:p")
  local current_dir = vim.fn.expand("%:p:h")
  local in_note = is_in_notes(current_file, notes_dir)
  local base_dir = (in_note and current_dir or notes_dir) .. "/"

  local default_path = base_dir .. slugify(title) .. ".md"

  vim.ui.input({ prompt = "File: ", default = default_path }, function(filepath)
    if not filepath or filepath == "" then return end

    if not filepath:match("%.md$") then
      filepath = filepath .. ".md"
    end

    vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")

    local f = io.open(filepath, "w")
    if not f then
      vim.notify("Failed to create " .. filepath, vim.log.levels.ERROR)
      return
    end
    f:write("# " .. title .. "\n")
    f:write("\n")
    f:write("Tags: [[todo]]\n")
    f:write("type: \n")
    f:write("\n")
    f:write("---\n")
    f:write("\n")
    f:close()

    if in_note then
      local link_name = vim.fn.fnamemodify(filepath, ":t:r")
      local row = vim.api.nvim_win_get_cursor(0)[1]
      vim.api.nvim_buf_set_lines(0, row, row, false, { "[[" .. link_name .. "]]" })
    end

    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
  end)
end

local function create_note(opts)
  local notes_dir = get_notes_dir()
  if not notes_dir then
    vim.notify("NOTES_DIR not set", vim.log.levels.ERROR)
    return
  end

  local title = opts.args ~= "" and opts.args or nil

  if title then
    finish_create(title, notes_dir)
  else
    vim.ui.input({ prompt = "Title: " }, function(t)
      if not t or t == "" then return end
      finish_create(t, notes_dir)
    end)
  end
end

vim.api.nvim_create_user_command("CreateNote", create_note, { nargs = "*" })
