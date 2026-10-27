local timestamps = require("notes-timestamps")
timestamps.setup()

local function get_notes_dir()
  local value = os.getenv("NOTES_DIR")
  if not value then return nil end
  value = value:gsub("/$", "")
  return vim.fn.expand(value)
end

local function is_in_notes(filepath, notes_dir)
  return timestamps.is_note(filepath, notes_dir)
end

local function yaml_string(value)
  return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function yaml_item(value)
  return value:match("^[%w._/-]+$") and value or yaml_string(value)
end

-- Working-context tags from Neovim's cwd (not the note's destination), per AGENTS.md:
-- repo/<name> always inside Git; worktree/<dir> only in a linked worktree.
local function context_tags(cwd)
  local out = vim.system({
    "git", "-C", cwd, "rev-parse", "--path-format=absolute",
    "--show-toplevel", "--git-dir", "--git-common-dir",
  }, { text = true }):wait()
  if out.code ~= 0 then return {} end
  local toplevel, git_dir, common_dir = unpack(vim.split(vim.trim(out.stdout), "\n"))
  if not (toplevel and git_dir and common_dir) then return {} end
  common_dir = vim.fs.normalize(common_dir)
  local repo = vim.fs.basename(common_dir)
  if repo == ".git" then
    repo = vim.fs.basename(vim.fs.dirname(common_dir))
  else
    repo = repo:gsub("%.git$", "")
  end
  local tags = { "repo/" .. repo }
  if vim.fs.normalize(git_dir) ~= common_dir then
    table.insert(tags, "worktree/" .. vim.fs.basename(toplevel))
  end
  return tags
end

-- Contract: notes-meta/notes-tags.md and AGENTS.md in NOTES_DIR.
local function template(title, timestamp, cwd, meta)
  local lines = {
    "---",
    'createdTime: "' .. timestamp .. '"',
    'updatedTime: "' .. timestamp .. '"',
    "type: " .. meta.type,
    "upstreamLinks: []",
    "contextLinks: []",
    "downstreamLinks: []",
    "pwd: " .. yaml_string(cwd),
  }
  if meta.deadline then
    table.insert(lines, 5, "deadline: " .. yaml_string(meta.deadline))
  end
  local tags = context_tags(cwd)
  if #tags == 0 then
    table.insert(lines, "tags: []")
  else
    table.insert(lines, "tags:")
    for _, tag in ipairs(tags) do
      table.insert(lines, "  - " .. yaml_item(tag))
    end
  end
  vim.list_extend(lines, { "---", "# " .. title, "" })
  return lines
end

local function slugify(title)
  return title:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
end

-- Pulls `--hub`, `--leaf` and `--deadline=YYYY-MM-DD` out of the args;
-- whatever is left is the title.
local function parse_args(args)
  local meta = {}
  local words = {}
  for word in args:gmatch("%S+") do
    local deadline = word:match("^%-%-deadline=(.+)$")
    if word == "--hub" then
      meta.type = "hub"
    elseif word == "--leaf" then
      meta.type = "leaf"
    elseif deadline then
      meta.deadline = deadline
    else
      table.insert(words, word)
    end
  end
  return table.concat(words, " "), meta
end

local function finish_create(title, notes_dir, region, meta)
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

    -- Exclusive creation: an existing note (and its timestamps) must never be truncated.
    local fd, err = vim.uv.fs_open(filepath, "wx", 420)
    if not fd then
      vim.notify("Failed to create " .. filepath .. ": " .. err, vim.log.levels.ERROR)
      return
    end
    if meta.destination_default then
      meta.type = timestamps.default_type(filepath, notes_dir)
    end
    local lines = template(title, timestamps.now(), vim.fn.getcwd(), meta)
    local content = table.concat(lines, "\n") .. "\n"
    local written, write_err = vim.uv.fs_write(fd, content, 0)
    vim.uv.fs_close(fd)
    if written ~= #content then
      vim.notify("Failed to write " .. filepath .. ": " .. (write_err or "short write"), vim.log.levels.ERROR)
      return
    end

    if in_note then
      local link_name = vim.fn.fnamemodify(filepath, ":t:r")
      local link = "[[" .. link_name .. "]]"
      if region then
        vim.api.nvim_buf_set_text(0, region[1], region[2], region[3], region[4], { link })
      else
        local row = vim.api.nvim_win_get_cursor(0)[1]
        -- never insert inside the YAML front matter
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        if lines[1] == "---" then
          for i = 2, #lines do
            if lines[i] == "---" then
              if row <= i then row = vim.api.nvim_buf_line_count(0) end
              break
            end
          end
        end
        vim.api.nvim_buf_set_lines(0, row, row, false, { link })
      end
      vim.cmd("silent write")
    end

    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
  end)
end

local function create_note(opts, default_type)
  local notes_dir = get_notes_dir()
  if not notes_dir then
    vim.notify("NOTES_DIR not set", vim.log.levels.ERROR)
    return
  end

  local args, meta = parse_args(opts.args)
  if opts.bang then meta.type = "hub" end
  meta.destination_default = not meta.type and default_type == "leaf"
  meta.type = meta.type or default_type
  local title = args ~= "" and args or nil
  local region = nil

  if not title and opts.range == 2 then
    if vim.fn.visualmode() == "v" then
      local srow, scol = unpack(vim.api.nvim_buf_get_mark(0, "<"))
      local erow, ecol = unpack(vim.api.nvim_buf_get_mark(0, ">"))
      local last_line = vim.api.nvim_buf_get_lines(0, erow - 1, erow, false)[1] or ""
      ecol = math.min(ecol + 1, #last_line)
      local text = vim.api.nvim_buf_get_text(0, srow - 1, scol, erow - 1, ecol, {})
      title = vim.trim(table.concat(text, " "))
      region = { srow - 1, scol, erow - 1, ecol }
    else
      local line = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
      title = vim.trim(table.concat(line, " "))
    end
  end

  if title then
    finish_create(title, notes_dir, region, meta)
  else
    vim.ui.input({ prompt = "Title: " }, function(t)
      if not t or t == "" then return end
      finish_create(t, notes_dir, nil, meta)
    end)
  end
end

vim.api.nvim_create_user_command("CreateNote", function(opts)
  create_note(opts, "leaf")
end, { nargs = "*", range = true, bang = true, desc = "Create a leaf note (! or --hub for a hub)" })
vim.api.nvim_create_user_command("CreateHub", function(opts)
  create_note(opts, "hub")
end, { nargs = "*", range = true, desc = "Create a small navigation hub" })
