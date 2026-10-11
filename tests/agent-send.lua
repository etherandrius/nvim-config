-- Run: nvim --headless -u NONE -i NONE -l ~/.config/nvim/tests/agent-send.lua
local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.rtp:prepend(config)
local agent = require("agent-send")
local checks = 0
local function check(ok, label)
  assert(ok, label)
  checks = checks + 1
end

-- Never touch the real tmux session, agent, or clipboard.
agent.find_pane = function() return nil end
local sent, selected, choice
agent.send = function(text, submit, pane)
  sent = { text = text, submit = submit, pane = pane }
end
vim.ui.select = function(items, opts, callback)
  selected = { items = items, prompt = opts.prompt }
  callback(choice)
end

vim.o.columns = 120
vim.o.lines = 40
local source = vim.api.nvim_get_current_buf()
local source_win = vim.api.nvim_get_current_win()
vim.api.nvim_buf_set_name(source, vim.fn.tempname() .. ".lua")
vim.bo[source].filetype = "lua"
local lines = {}
for i = 1, 100 do lines[i] = "local value" .. i .. " = " .. i end
vim.api.nvim_buf_set_lines(source, 0, -1, false, lines)
local tick = vim.api.nvim_buf_get_changedtick(source)

local function mapping(lhs, mode)
  return vim.fn.maparg(lhs, mode or "n", false, true).callback
end
local function open(lhs, mode)
  selected, sent = nil, nil
  mapping(lhs, mode)()
  local input_win = vim.api.nvim_get_current_win()
  local input = vim.api.nvim_get_current_buf()
  local preview_win
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= input_win and vim.api.nvim_win_get_config(win).relative == "editor" then
      check(preview_win == nil, "only one reference preview")
      preview_win = win
    end
  end
  check(preview_win ~= nil, "reference visible alongside message")
  check(input_win ~= source_win, "message has focus")
  check(vim.api.nvim_buf_get_lines(input, 0, -1, false)[1] == "", "message starts empty")
  return { input = input, win = input_win, preview_win = preview_win,
    preview = vim.api.nvim_win_get_buf(preview_win) }
end
local function check_closed(popup)
  check(not vim.api.nvim_win_is_valid(popup.win), "message window closed")
  check(not vim.api.nvim_win_is_valid(popup.preview_win), "reference window closed")
  check(not vim.api.nvim_buf_is_valid(popup.input), "message buffer deleted")
  check(not vim.api.nvim_buf_is_valid(popup.preview), "reference buffer deleted")
  check(vim.api.nvim_get_current_buf() == source, "source restored")
end
local function check_geometry(popup)
  local ref = vim.api.nvim_win_get_config(popup.preview_win)
  local msg = vim.api.nvim_win_get_config(popup.win)
  check(ref.row + ref.height + 2 <= msg.row, "reference and message do not overlap")
  check(msg.row + msg.height + 2 <= vim.o.lines - vim.o.cmdheight, "message fits vertically")
  check(msg.col >= 0 and msg.col + msg.width + 2 <= vim.o.columns, "message fits horizontally")
end

local popup = open("\\pb")
check(vim.deep_equal(vim.api.nvim_buf_get_lines(popup.preview, 0, -1, false), lines), "full buffer preview is exact")
check(vim.bo[popup.preview].filetype == "lua", "buffer preview retains syntax filetype")
check(not vim.bo[popup.preview].modifiable and vim.bo[popup.preview].readonly, "preview is read-only")
check(not pcall(vim.api.nvim_buf_set_lines, popup.preview, 0, 1, false, { "oops" }), "preview rejects edits")
check_geometry(popup)

local input_cursor = vim.api.nvim_win_get_cursor(popup.win)
local first_line = vim.api.nvim_win_call(popup.preview_win, function() return vim.fn.line("w0") end)
mapping("<C-d>", "i")()
local scrolled_line = vim.api.nvim_win_call(popup.preview_win, function() return vim.fn.line("w0") end)
check(scrolled_line > first_line, "scroll reference down from message")
mapping("<C-u>", "i")()
check(vim.api.nvim_win_call(popup.preview_win, function() return vim.fn.line("w0") end) < scrolled_line,
  "scroll reference up from message")
check(vim.api.nvim_get_current_win() == popup.win, "scrolling retains message focus")
check(vim.deep_equal(vim.api.nvim_win_get_cursor(popup.win), input_cursor), "scrolling retains message cursor")

-- Exercise the actual insert-mode mappings, not only their Lua callbacks.
vim.cmd("stopinsert")
local keys = vim.api.nvim_replace_termcodes("iInspect<C-d> this<C-u> please<Esc>", true, false, true)
vim.api.nvim_feedkeys(keys, "xt", false)
check(vim.api.nvim_buf_get_lines(popup.input, 0, -1, false)[1] == "Inspect this please",
  "typing continues in the message across reference scrolling")

vim.api.nvim_buf_set_lines(popup.input, 0, -1, false, { "first line", "second line" })
for _, case in ipairs({ { popup.win, "n" }, { popup.win, "i" }, { popup.preview_win, "n" } }) do
  local win, mode = case[1], case[2]
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
  for _, move in ipairs({ { "<C-j>", "<Down>", 2 }, { "<C-k>", "<Up>", 1 } }) do
    local map = vim.fn.maparg(move[1], mode, false, true)
    check(map.buffer == 1 and map.rhs == move[2], move[1] .. " is a buffer-local arrow mapping")
    local sequence = mode == "i" and ("i" .. move[1] .. "<Esc>") or move[1]
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(sequence, true, false, true), "xt", false)
    check(vim.api.nvim_win_get_cursor(win)[1] == move[3], move[1] .. " moves vertically in " .. mode .. " mode")
  end
end
vim.api.nvim_set_current_win(popup.win)
check(vim.deep_equal(vim.api.nvim_buf_get_lines(popup.input, 0, -1, false), { "first line", "second line" }),
  "arrow shortcuts do not insert newlines or change the message")
check(selected == nil and sent == nil, "arrow shortcuts do not submit")

vim.api.nvim_buf_set_lines(popup.input, 0, -1, false, { string.rep("message ", 40) })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = popup.input })
check(vim.api.nvim_win_get_height(popup.win) > 1, "message grows for wrapped text")
check_geometry(popup)
vim.o.columns = 32
vim.o.lines = 12
vim.api.nvim_exec_autocmds("VimResized", {})
check_geometry(popup)
vim.o.columns = 120
vim.o.lines = 40
vim.api.nvim_exec_autocmds("VimResized", {})
check_geometry(popup)

vim.api.nvim_buf_set_lines(popup.input, 0, -1, false, { "Explain this", "and suggest improvements" })
choice = "Send to Agent"
mapping("<CR>", "i")()
check_closed(popup)
check(vim.wait(500, function() return sent ~= nil end, 10), "action runs after popup closes")
check(sent.text == "Explain this\nand suggest improvements\n\n" .. table.concat(lines, "\n"), "message and reference sent exactly once")
check(sent.submit == false, "send does not execute")
check(#selected.items == 3, "send, execute and clipboard choices retained")

-- Selection preview includes the exact file/line and fenced code being sent.
vim.api.nvim_buf_set_mark(source, "<", 1, 0, {})
vim.api.nvim_buf_set_mark(source, ">", 1, 0, {})
vim.cmd("normal! 2GVj")
popup = open("\\ps", "v")
local expected = vim.api.nvim_buf_get_name(source) .. ":2\n```lua\n" .. lines[2] .. "\n" .. lines[3] .. "\n\n```"
check(table.concat(vim.api.nvim_buf_get_lines(popup.preview, 0, -1, false), "\n") == expected,
  "selection preview has fresh line marks, code fences and only selected code")
check(vim.bo[popup.preview].filetype == "markdown", "fenced selection uses Markdown syntax")
choice = "Send to Agent and Execute"
mapping("<CR>")()
check_closed(popup)
check(vim.wait(500, function() return sent ~= nil end, 10), "selection action completes")
check(sent.text == expected and sent.submit == true, "empty message sends selection unchanged and executes")

for _, key in ipairs({ "q", "<Esc>" }) do
  popup = open("\\pb")
  mapping(key)()
  check_closed(popup)
  check(selected == nil and sent == nil, "cancel does not open actions or send")
end
popup = open("\\pb")
vim.api.nvim_set_current_win(popup.preview_win)
mapping("q")()
check_closed(popup)

for _, field in ipairs({ "win", "preview_win" }) do
  popup = open("\\pb")
  vim.api.nvim_win_close(popup[field], true)
  check(vim.wait(500, function()
    return not vim.api.nvim_buf_is_valid(popup.input) and not vim.api.nvim_buf_is_valid(popup.preview)
  end, 10), "external window close cleans up both popups")
  check_closed(popup)
end
check(vim.deep_equal(vim.api.nvim_buf_get_lines(source, 0, -1, false), lines), "source code unchanged")
check(vim.api.nvim_buf_get_changedtick(source) == tick, "source undo state unchanged")
print(string.format("%d checks passed", checks))
vim.cmd("qa!")
