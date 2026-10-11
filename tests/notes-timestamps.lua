-- Run: nvim --headless -u NONE -l ~/.config/nvim/tests/notes-timestamps.lua
local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
package.path = config .. "/lua/?.lua;" .. package.path
local timestamps = require("notes-timestamps")
local first = "2026-09-30T14:00:00Z"
local second = "2026-09-30T14:01:00Z"
local passed = 0
local function check(condition, message)
  assert(condition, message)
  passed = passed + 1
end
local function field(lines, key)
  local value, count
  count = 0
  for _, line in ipairs(lines) do
    if line:match("^" .. key .. ":") then
      value = line:match('^' .. key .. ': "(.*)"$')
      count = count + 1
    end
  end
  assert(count <= 1, "Duplicate " .. key)
  return value
end
local function read(path)
  return vim.fn.readfile(path)
end
local root = vim.fn.resolve(vim.fn.tempname())
local notes = root .. "/notes"
vim.fn.mkdir(notes, "p")
local original_env = vim.env.NOTES_DIR
local original_now = timestamps.now
local original_input, original_notify = vim.ui.input, vim.notify
local ok, err = xpcall(function()
  check(timestamps.now():match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$") ~= nil, "UTC format")
  local lines = timestamps.update({ "# New note", "", "Body" }, first, true)
  check(lines[1] == "---", "Frontmatter is first")
  check(field(lines, "createdTime") == first and field(lines, "updatedTime") == first, "Equal initial timestamps")
  check(vim.tbl_contains(lines, "# New note") and lines[#lines] == "Body", "Body preserved")
  local ordered = timestamps.update({ "---", "upstreamLinks: []", "---", "# T" }, first, true)
  check(ordered[2]:match("^createdTime:") and ordered[3]:match("^updatedTime:") and ordered[4] == "type: leaf" and ordered[5] == "upstreamLinks: []", "Timestamps then type precede links")
  local hub = timestamps.update({ "---", "type: hub", "---", "# Hub" }, first, true)
  check(vim.tbl_contains(hub, "type: hub") and not vim.tbl_contains(hub, "type: leaf"), "Explicit hub preserved on new save")
  check(vim.tbl_contains(timestamps.update(hub, second, false), "type: hub"), "Hub preserved on later edits")
  local edited = timestamps.update(lines, second, false)
  check(field(edited, "createdTime") == first and field(edited, "updatedTime") == second, "Immutable creation")
  local legacy = timestamps.update({ "---", 'title: "Legacy"', "---", "# Legacy" }, second, false)
  check(field(legacy, "createdTime") == nil and field(legacy, "updatedTime") == second, "No invented legacy creation")
  check(legacy[2] == 'updatedTime: "' .. second .. '"' and legacy[3] == 'title: "Legacy"', "Timestamp first; other metadata preserved")
  check(not vim.tbl_contains(legacy, "type: leaf"), "Do not infer missing legacy type")
  local old_plain = timestamps.update({ "# Old plain", "Body" }, second, false)
  check(field(old_plain, "createdTime") == nil and old_plain[#old_plain] == "Body", "Plain legacy remains intact")
  check(timestamps.update({ "---", "title: broken" }, first, true) == nil, "Malformed frontmatter rejected")
  check(timestamps.update({ "---", "updatedTime: a", "updatedTime: b", "---" }, first, false) == nil, "Duplicates rejected")
  check(timestamps.update({ "---", "type: hub", "type: leaf", "---" }, first, false) == nil, "Duplicate types rejected")
  local body_fields = timestamps.update({ "---", "---", "# Body", "createdTime: body-example" }, first, true)
  check(body_fields[#body_fields] == "createdTime: body-example", "Only frontmatter touched")
  check(timestamps.is_note(notes .. "/nested/a.md", notes .. "/"), "Nested notes included")
  check(not timestamps.is_note(notes .. "-other/a.md", notes), "Sibling prefix excluded")
  vim.uv.fs_symlink(notes, root .. "/alias")
  check(timestamps.is_note(notes .. "/a.md", root .. "/alias"), "Symlinked notes root works")
  check(not timestamps.is_note(notes .. "/todo.md", notes), "Human todo excluded")
  check(not timestamps.is_note(notes .. "/AGENTS.md", notes), "Instruction file excluded")
  check(not timestamps.is_note(notes .. "/file.lua", notes), "Non-markdown excluded")

  vim.env.NOTES_DIR = notes
  timestamps.now = function() return first end
  dofile(config .. "/lua/notes-create.lua")
  timestamps.setup()
  check(#vim.api.nvim_get_autocmds({ group = "NotesTimestamps" }) == 1, "Reload is idempotent")
  local manual = notes .. "/manual.md"
  vim.cmd.edit(vim.fn.fnameescape(manual))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Manual", "", "Body" })
  vim.cmd("silent write")
  check(field(read(manual), "createdTime") == first and field(read(manual), "updatedTime") == first, "Manual new file stamped")
  check(vim.tbl_contains(read(manual), "type: leaf"), "New manual note defaults to leaf")
  timestamps.now = function() return second end
  vim.cmd("silent write")
  check(field(read(manual), "updatedTime") == first, "Unchanged save does not advance time")
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "Changed" })
  vim.cmd("silent write")
  check(field(read(manual), "createdTime") == first and field(read(manual), "updatedTime") == second, "Edited save updates only updatedTime")
  local outside = root .. "/outside.md"
  vim.cmd.edit(vim.fn.fnameescape(outside))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Outside" })
  vim.cmd("silent write")
  check(vim.deep_equal(read(outside), { "# Outside" }), "Files outside NOTES_DIR untouched")
  local legacy_path = notes .. "/legacy.md"
  vim.fn.writefile({ "# Legacy" }, legacy_path)
  vim.cmd.edit(vim.fn.fnameescape(legacy_path))
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "Changed" })
  vim.cmd("silent write")
  check(field(read(legacy_path), "createdTime") == nil and field(read(legacy_path), "updatedTime") == second, "Legacy save adds only update time")
  for _, name in ipairs({ "todo.md", "AGENTS.md", "CLAUDE.md" }) do
    local path = notes .. "/" .. name
    vim.cmd.edit(vim.fn.fnameescape(path))
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Excluded" })
    vim.cmd("silent write")
    check(vim.deep_equal(read(path), { "# Excluded" }), name .. " not auto-stamped")
  end

  local malformed = notes .. "/malformed.md"
  local original = { "---", "title: broken" }
  vim.fn.writefile(original, malformed)
  vim.cmd.edit(vim.fn.fnameescape(malformed))
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "Do not write malformed metadata" })
  check(not pcall(vim.cmd, "silent write"), "Malformed metadata blocks save")
  check(vim.deep_equal(read(malformed), original), "Failed save preserves file")
  vim.cmd("edit! " .. vim.fn.fnameescape(outside))
  local function git(args)
    local out = vim.system(vim.list_extend({ "git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null" }, args), { text = true }):wait()
    assert(out.code == 0, out.stderr)
  end
  local repo_dir = root .. "/work-repo"
  git({ "init", "-q", repo_dir })
  git({ "-C", repo_dir, "commit", "-q", "--allow-empty", "-m", "init" })
  git({ "-C", repo_dir, "worktree", "add", "-q", root .. "/wt-dir", "-b", "some-branch" })
  local original_cwd = vim.fn.getcwd()
  vim.fn.mkdir(root .. "/plain", "p")
  local function create_in(cwd, name, command)
    vim.cmd.cd(vim.fn.fnameescape(cwd))
    local path = notes .. "/" .. name .. ".md"
    vim.ui.input = function(_, callback) callback(path) end
    vim.cmd((command or "CreateNote") .. " " .. name)
    vim.cmd("edit! " .. vim.fn.fnameescape(outside))
    return read(path)
  end
  local in_repo = create_in(repo_dir, "in-repo")
  check(vim.deep_equal(in_repo, {
    "---",
    'createdTime: "' .. second .. '"',
    'updatedTime: "' .. second .. '"',
    "type: leaf",
    "upstreamLinks: []",
    "contextLinks: []",
    "downstreamLinks: []",
    'pwd: "' .. repo_dir .. '"',
    "tags:",
    "  - repo/work-repo",
    "---",
    "# in-repo",
    "",
  }), "Main-checkout template: " .. vim.inspect(in_repo))
  local in_wt = create_in(root .. "/wt-dir", "in-worktree")
  check(vim.tbl_contains(in_wt, "  - repo/work-repo") and vim.tbl_contains(in_wt, "  - worktree/wt-dir"), "Linked worktree tags")
  local in_plain = create_in(root .. "/plain", "in-plain")
  check(vim.tbl_contains(in_plain, "tags: []") and vim.tbl_contains(in_plain, 'pwd: "' .. root .. '/plain"'), "Outside Git: pwd only")
  local in_hub = create_in(repo_dir, "topic-hub", "CreateHub")
  check(vim.tbl_contains(in_hub, "type: hub") and not vim.tbl_contains(in_hub, "type: leaf"), "CreateHub writes hub type")
  check(vim.tbl_contains(in_hub, "  - repo/work-repo"), "CreateHub preserves source tags")
  for _, note in ipairs({ in_repo, in_wt, in_plain, in_hub }) do
    local in_frontmatter = true
    for i, line in ipairs(note) do
      if i > 1 and line == "---" then in_frontmatter = false end
      check(not line:match("^Tags:") and (in_frontmatter or not line:match("^type:")), "No deprecated body Tags:/type:")
    end
  end
  vim.cmd.cd(vim.fn.fnameescape(original_cwd))
  local target = notes .. "/command.md"
  local notifications = {}
  vim.notify = function(message) table.insert(notifications, message) end
  vim.ui.input = function(_, callback) callback(target) end
  vim.cmd("CreateNote Command note")
  local created = read(target)
  check(field(created, "createdTime") == second and field(created, "updatedTime") == second, "CreateNote stamps disk immediately")
  check(created[1] == "---" and vim.tbl_contains(created, "# Command note"), "CreateNote valid template")
  check(vim.api.nvim_buf_get_name(0) == target, "CreateNote opens result")
  vim.cmd("CreateNote Must not overwrite")
  check(vim.deep_equal(read(target), created), "Existing file never overwritten")
  check(#notifications == 1 and notifications[1]:match("EEXIST"), "Existing file error reported")

  -- Creating from a note still inserts the link and refreshes its update time.
  vim.cmd.edit(vim.fn.fnameescape(manual))
  target = notes .. "/linked.md"
  vim.cmd("CreateNote Linked note")
  check(vim.tbl_contains(read(manual), "[[linked]]"), "Source link inserted")
  check(field(read(manual), "createdTime") == first, "Source creation time preserved")
  check(field(read(target), "createdTime") == second, "Linked new note stamped")
  local source = target
  target = notes .. "/linked-hub.md"
  vim.cmd("CreateHub Linked hub")
  check(vim.tbl_contains(read(source), "[[linked-hub]]"), "CreateHub links from source")
  check(vim.tbl_contains(read(target), "type: hub"), "Linked hub keeps explicit type")
  vim.ui.input = function(_, callback) callback(nil) end
  vim.cmd("CreateNote Cancelled")
  check(vim.api.nvim_buf_get_name(0) == target, "Cancelled prompt makes no changes")
end, debug.traceback)
vim.ui.input, vim.notify = original_input, original_notify
vim.env.NOTES_DIR = original_env
timestamps.now = original_now
vim.cmd("silent! %bwipeout!")
vim.fn.delete(root, "rf")
if not ok then error(err) end
print(string.format("PASS: %d note timestamp checks", passed))
