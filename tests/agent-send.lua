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
agent.list_agents = function()
  return {
    {
      id = "%2",
      name = "claude",
      place = "window",
      session_id = "$1",
      window_index = "1",
      window_name = "nvim",
      pane_index = "1",
      dir = "/tmp/nvim",
    },
  }
end
local sent, selected, choice
agent.send = function(text, submit, pane)
  sent = { text = text, submit = submit, pane = pane }
end

local ordered = agent.order_agents({
  { id = "%self", name = "pi", session_id = "$1", window_id = "@1", window_index = "1", window_name = "nvim", pane_index = "1", dir = "/work/nvim" },
  { id = "%mark", name = "pi", session_id = "$2", tmux_session = "ops", window_id = "@9", window_index = "4", window_name = "marked-repo", pane_index = "1", dir = "/work/marked-repo", pi_session_name = "marked-agent" },
  { id = "%winb", name = "claude", session_id = "$1", window_id = "@1", window_index = "1", window_name = "nvim", pane_index = "3", dir = "/work/nvim" },
  { id = "%wina", name = "codex", session_id = "$1", window_id = "@1", window_index = "1", window_name = "nvim", pane_index = "2", dir = "/work/else" },
  { id = "%cwd", name = "pi", session_id = "$1", window_id = "@2", window_index = "5", window_name = "same", pane_index = "1", dir = "/work/nvim", pi_session_name = "same-cwd" },
  { id = "%sess", name = "pi", session_id = "$1", window_id = "@3", window_index = "2", window_name = "notes", pane_index = "1", dir = "/work/notes", pi_session_name = "notes" },
  { id = "%far", name = "claude", session_id = "$8", tmux_session = "far", window_id = "@8", window_index = "1", window_name = "farwin", pane_index = "2", dir = "/work/far" },
  { id = "%farcwd", name = "pi", session_id = "$8", tmux_session = "far", window_id = "@7", window_index = "1", window_name = "nvim", pane_index = "1", dir = "/work/nvim", pi_session_name = "far-cwd" },
  { id = "%later", name = "codex", session_id = "$10", tmux_session = "later", window_id = "@10", window_index = "1", window_name = "later", pane_index = "1", dir = "/work/later" },
}, {
  session_id = "$1", window_id = "@1", pane_id = "%self", dir = "/work/nvim",
}, "%mark")
local ids = {}
for _, pane in ipairs(ordered) do ids[#ids + 1] = pane.id end
check(vim.deep_equal(ids, { "%wina", "%winb", "%mark", "%cwd", "%sess", "%farcwd", "%far", "%later" }),
  "picker order is this window, marked, same cwd, this session, then other sessions")
check(ordered[3].place == "marked" and ordered[3].foreign_session, "marked pane stays behind this window")
local marked_here = agent.order_agents({
  { id = "%m", name = "pi", session_id = "$1", tmux_session = "main", window_id = "@1", window_index = "1", window_name = "nvim", pane_index = "2", pi_session_name = "here" },
  { id = "%o", name = "claude", session_id = "$1", window_id = "@1", window_index = "1", pane_index = "1" },
}, { session_id = "$1", window_id = "@1", pane_id = "%self" }, "%m")
check(marked_here[1].id == "%o" and marked_here[1].place == "window" and marked_here[2].place == "window",
  "a marked pane in this window stays with this window")
local here_labels = {}
for _, item in ipairs(agent.action_items(marked_here)) do here_labels[#here_labels + 1] = item.label end
check(here_labels[3] == "here · Send *M P:2", "marked in this window omits S and W")
local marked_session = agent.order_agents({
  { id = "%s", name = "pi", session_id = "$1", tmux_session = "main", window_id = "@2", window_index = "5", window_name = "same", pane_index = "1", pi_session_name = "elsewhere" },
}, { session_id = "$1", window_id = "@1", pane_id = "%self", dir = "/other" }, "%s")
check(agent.action_items(marked_session)[1].label == "elsewhere · Send [*M W:5:same]",
  "marked in this session omits S")
local labels = {}
for _, item in ipairs(agent.action_items(ordered)) do labels[#labels + 1] = item.label end
check(labels[1] == "{noname} · Send P:2", "this window comes before the marked pane")
check(labels[5] == "marked-agent · Send [*M S:ops W:4:marked-repo]", "marked target uses the session name and window id")
check(labels[6] == "marked-agent · Send and Execute [*M S:ops W:4:marked-repo]", "marked execute follows send")
check(labels[3] == "{noname} · Send P:3", "multiple agents in this window keep an unbracketed pane index")
check(labels[7] == "same-cwd · Send [W:5:same]", "this session omits S and a lone pane omits P")
check(labels[11] == "Copy to Clipboard", "clipboard follows this session and precedes other sessions")
check(labels[12] == "far-cwd · Send [S:far W:1:nvim]", "other sessions use the session name")
check(labels[#labels] == "{noname} · Send and Execute [S:later W:1:later]", "later session stays last")
check(agent.action_items({})[1].label == "Copy to Clipboard" and #agent.action_items({}) == 1,
  "no agents still offers clipboard")
local snapshot = agent.parse_process_snapshot(
  "10 1 zsh\n11 10 pi\n12 11 node\n",
  "10 -zsh\n11 pi\n12 node /usr/local/bin/claude\n")
check(agent.agent_in_snapshot("10", snapshot) == "pi", "snapshot finds a child agent without per-process ps")
check(agent.agent_in_snapshot("12", snapshot) == "claude", "snapshot reads an agent path from the command line")
check(agent.detect_agent_name("node /Volumes/git/pi-orchestrator/dist/pi-orchestrator") == nil,
  "pi-orchestrator CLI is not a pi agent")
check(agent.detect_agent_name("node /Volumes/git/pi-orchestrator/dist/coding-host-main.js --session /Users/x/.local/state/pi/sessions/a.jsonl") == nil,
  "pi session path does not make pi-orchestrator a pi agent")
check(agent.detect_agent_name("node /opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js") == "pi",
  "pi-coding-agent wrapper is still pi")
check(agent.detect_agent_name("/opt/homebrew/bin/pi --foo") == "pi", "pi executable path is still pi")
check(agent.agent_in_snapshot("99", snapshot) == nil, "unknown pid is not an agent")
local cycle = agent.parse_process_snapshot("1 2 zsh\n2 1 zsh\n", "1 zsh\n2 zsh\n")
check(agent.agent_in_snapshot("1", cycle) == nil, "process cycles do not hang")
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
local function title_text(title)
  if type(title) == "string" then return title end
  if type(title) ~= "table" then return "" end
  local parts = {}
  for _, chunk in ipairs(title) do
    parts[#parts + 1] = type(chunk) == "table" and chunk[1] or tostring(chunk)
  end
  return table.concat(parts)
end
local message_title = title_text(vim.api.nvim_win_get_config(popup.win).title)
check(message_title == " Context ", "message title does not name a single target")
check(not message_title:find("!s:", 1, true) and not message_title:find("w:", 1, true),
  "message title has no session or window warning")
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
for _, case in ipairs({
  { popup.win, "n", { "<C-j>", "<C-k>" } },
  { popup.win, "i", { "<C-k>" } },
  { popup.preview_win, "n", { "<C-j>", "<C-k>" } },
}) do
  local win, mode, keys = case[1], case[2], case[3]
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
  for _, lhs in ipairs(keys) do
    local rhs = lhs == "<C-j>" and "<Down>" or "<Up>"
    local line = lhs == "<C-j>" and 2 or 1
    local map = vim.fn.maparg(lhs, mode, false, true)
    check(map.buffer == 1 and map.rhs == rhs, lhs .. " is a buffer-local arrow mapping in " .. mode)
    local sequence = mode == "i" and ("i" .. lhs .. "<Esc>") or lhs
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(sequence, true, false, true), "xt", false)
    check(vim.api.nvim_win_get_cursor(win)[1] == line, lhs .. " moves vertically in " .. mode .. " mode")
  end
end
vim.api.nvim_set_current_win(popup.win)
vim.cmd("stopinsert")
check(vim.fn.maparg("<C-j>", "i", false, true).rhs ~= "<Down>", "insert ctrl-j is not stolen for movement")
vim.api.nvim_buf_set_lines(popup.input, 0, -1, false, { "hello" })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A<C-j><Esc>", true, false, true), "xt", false)
check(vim.deep_equal(vim.api.nvim_buf_get_lines(popup.input, 0, -1, false), { "hello", "" }),
  "insert ctrl-j starts a new line")
check(selected == nil and sent == nil, "newline and arrow shortcuts do not submit")

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
choice = { action = "send", submit = false, pane = "%2" }
mapping("<CR>", "i")()
check_closed(popup)
check(vim.wait(500, function() return sent ~= nil end, 10), "action runs after popup closes")
check(sent.text == "Explain this\nand suggest improvements\n\n" .. table.concat(lines, "\n"), "message and reference sent exactly once")
check(sent.submit == false and sent.pane == "%2", "send does not execute and targets the chosen pane")
check(selected.prompt == "Send", "picker prompt does not warn about location")
check(vim.deep_equal(vim.tbl_map(function(item) return item.label end, selected.items), {
  "{noname} · Send",
  "{noname} · Send and Execute",
  "Copy to Clipboard",
}), "picker offers send, execute, and clipboard for the listed agent")

-- A second Enter is often still queued when the picker opens. It must not cancel the send.
popup = open("\\pb")
vim.api.nvim_buf_set_lines(popup.input, 0, -1, false, { "do not lose this" })
local real_getchar = vim.fn.getchar
vim.fn.getchar = function(expr)
  if expr == 1 then return 13 end
  if expr == 0 then
    vim.fn.getchar = real_getchar
    return 13
  end
  return real_getchar(expr)
end
sent, selected = nil, nil
choice = nil
mapping("<CR>", "i")()
check(vim.wait(500, function() return sent ~= nil end, 10), "queued enter still sends")
check(selected == nil, "queued enter does not open a picker that can discard the prompt")
check(sent.text:find("do not lose this", 1, true) and sent.pane == "%2" and sent.submit == false,
  "queued enter sends the prompt to the default agent")
vim.fn.getchar = real_getchar

-- Selection preview includes the exact file/line and fenced code being sent.
vim.api.nvim_buf_set_mark(source, "<", 1, 0, {})
vim.api.nvim_buf_set_mark(source, ">", 1, 0, {})
vim.cmd("normal! 2GVj")
popup = open("\\ps", "v")
local expected = vim.api.nvim_buf_get_name(source) .. ":2\n```lua\n" .. lines[2] .. "\n" .. lines[3] .. "\n\n```"
check(table.concat(vim.api.nvim_buf_get_lines(popup.preview, 0, -1, false), "\n") == expected,
  "selection preview has fresh line marks, code fences and only selected code")
check(vim.bo[popup.preview].filetype == "markdown", "fenced selection uses Markdown syntax")
choice = { action = "send", submit = true, pane = "%2" }
mapping("<CR>")()
check_closed(popup)
check(vim.wait(500, function() return sent ~= nil end, 10), "selection action completes")
check(sent.text == expected and sent.submit == true and sent.pane == "%2",
  "empty message sends selection unchanged and executes in the chosen pane")

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
