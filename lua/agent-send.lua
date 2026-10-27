-- agent-send.lua — send text to a codex/pi/claude tmux pane, or copy it
--
-- Picker order:
--   1. Agent panes in the current window, by pane index
--   2. Marked pane, if it is running codex/pi/claude and is not in this window
--   3. Agent panes in this session with the same cwd
--   4. Other agent panes in this session
--   5. Copy to clipboard
--   6. Agent panes in other sessions
--
-- Never targets the calling pane. Outside tmux, only clipboard is offered.

local M = {}

local agent_commands = { codex = true, pi = true, claude = true }
-- Package paths, not a bare `/pi/` segment. That also matches pi-orchestrator
-- and `~/.local/state/pi/sessions`, which are not the Pi CLI.
local agent_package_markers = {
  { "pi%-coding%-agent", "pi" },
  { "@openai/codex", "codex" },
  { "claude%-code", "claude" },
}

local function detect_agent_name(text)
  if not text or text == "" then return nil end

  for token in text:gmatch("%S+") do
    local base = token:match("[^/]+$") or token
    if agent_commands[base] then return base end
  end
  for _, marker in ipairs(agent_package_markers) do
    if text:find(marker[1]) then return marker[2] end
  end
end

M.detect_agent_name = detect_agent_name

--- Walk one process tree with a fresh ps/pgrep per node. Slow; only a fallback
--- when the single-snapshot lookup below cannot run.
local function find_agent_in_process_tree(pid, seen)
  if not pid then return nil end
  pid = tostring(pid)
  seen = seen or {}
  if seen[pid] then return nil end
  seen[pid] = true

  local comm = vim.trim(vim.fn.system({ "ps", "-o", "comm=", "-p", pid }))
  if vim.v.shell_error == 0 then
    local name = detect_agent_name(comm)
    if name then return name end
  end

  local args = vim.trim(vim.fn.system({ "ps", "-o", "command=", "-p", pid }))
  if vim.v.shell_error == 0 then
    local name = detect_agent_name(args)
    if name then return name end
  end

  local children = vim.fn.system({ "pgrep", "-P", pid })
  if vim.v.shell_error ~= 0 then return nil end

  for cpid in children:gmatch("%d+") do
    local name = find_agent_in_process_tree(cpid, seen)
    if name then return name end
  end

  return nil
end

--- Parse `ps -o pid=,ppid=,comm=` and `ps -o pid=,command=` output.
--- One snapshot replaces a ps/pgrep pair per process in every pane tree.
function M.parse_process_snapshot(tree_out, command_out)
  local by_pid, children = {}, {}
  for line in (tree_out or ""):gmatch("[^\n]+") do
    local pid, ppid, comm = line:match("^%s*(%d+)%s+(%d+)%s+(.*)$")
    if pid then
      by_pid[pid] = { comm = vim.trim(comm), command = "" }
      local kids = children[ppid]
      if not kids then
        kids = {}
        children[ppid] = kids
      end
      kids[#kids + 1] = pid
    end
  end
  for line in (command_out or ""):gmatch("[^\n]+") do
    local pid, command = line:match("^%s*(%d+)%s*(.*)$")
    if pid and by_pid[pid] then
      by_pid[pid].command = vim.trim(command or "")
    end
  end
  return { by_pid = by_pid, children = children }
end

--- Name the agent at pid or among its descendants. Checks the process itself
--- before children, matching the old per-pid walk.
function M.agent_in_snapshot(pid, snapshot)
  if not pid or not snapshot or not snapshot.by_pid then return nil end
  local seen = {}
  local stack = { tostring(pid) }
  while #stack > 0 do
    local current = table.remove(stack)
    if not seen[current] then
      seen[current] = true
      local proc = snapshot.by_pid[current]
      if proc then
        local name = detect_agent_name(proc.comm) or detect_agent_name(proc.command)
        if name then return name end
        local kids = snapshot.children[current]
        if kids then
          for i = #kids, 1, -1 do
            stack[#stack + 1] = kids[i]
          end
        end
      end
    end
  end
end

local function process_snapshot()
  -- ps -x is this user's processes, including other tmux ttys. Two formats in
  -- one spawn: comm and command are not safely separable in a single ps line.
  local out = vim.fn.system({
    "sh", "-c",
    "ps -x -o 'pid=,ppid=,comm='; echo; echo AGENT_SEND_SPLIT; ps -x -o 'pid=,command='",
  })
  if vim.v.shell_error ~= 0 or not out or out == "" then return nil end
  local tree, commands = out:match("^(.-)\nAGENT_SEND_SPLIT\n(.*)$")
  if not tree then return nil end
  return M.parse_process_snapshot(tree, commands)
end

--- Run a tmux command and return trimmed stdout, or nil on failure.
local function tmux(...)
  local args = { "tmux", ... }
  local out = vim.fn.system(args)
  if vim.v.shell_error ~= 0 then return nil end
  return vim.trim(out)
end

--- Get a tmux format variable for the current pane.
local function tmux_var(fmt)
  -- Anchor queries to Neovim's pane, not whichever tmux client is active.
  if vim.env.TMUX_PANE then
    return tmux("display-message", "-p", "-t", vim.env.TMUX_PANE, fmt)
  end
  return tmux("display-message", "-p", fmt)
end

local pane_format = table.concat({
  "#{pane_id}",
  "#{pane_current_command}",
  "#{pane_pid}",
  "#{session_id}",
  "#{session_name}",
  "#{window_id}",
  "#{window_index}",
  "#{window_name}",
  "#{pane_index}",
  "#{pane_current_path}",
  "#{@pi_session_name}",
  "#{pane_marked}",
}, "\t")

local function split_fields(line, count)
  local fields = {}
  local rest = line
  for i = 1, count - 1 do
    local field, tail = rest:match("^([^\t]*)\t(.*)$")
    if not field then return nil end
    fields[i] = field
    rest = tail
  end
  fields[count] = rest
  return fields
end

local function parse_pane(line)
  local fields = split_fields(line, 12)
  if not fields or not fields[1]:match("^%%") or fields[3] == "" then return nil end
  return {
    id = fields[1],
    cmd = fields[2],
    pid = fields[3],
    session_id = fields[4],
    tmux_session = fields[5],
    window_id = fields[6],
    window_index = fields[7],
    window_name = fields[8],
    pane_index = fields[9],
    dir = fields[10],
    pi_session_name = fields[11],
    marked = fields[12] == "1",
  }
end

local function current_context()
  local line = tmux_var("#{session_id}\t#{window_id}\t#{pane_id}\t#{pane_current_path}")
  if not line then return nil end
  local session_id, window_id, pane_id, dir = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t(.*)$")
  if not session_id then return nil end
  return { session_id = session_id, window_id = window_id, pane_id = pane_id, dir = dir }
end

--- Prefer the current session when a linked pane is listed more than once.
local function dedupe_panes(panes, ctx)
  local by_id, order = {}, {}
  for _, pane in ipairs(panes) do
    local existing = by_id[pane.id]
    if not existing then
      by_id[pane.id] = pane
      table.insert(order, pane)
    elseif pane.session_id == ctx.session_id and existing.session_id ~= ctx.session_id then
      pane.marked = pane.marked or existing.marked
      by_id[pane.id] = pane
      for i, item in ipairs(order) do
        if item.id == pane.id then
          order[i] = pane
          break
        end
      end
    elseif pane.marked then
      existing.marked = true
    end
  end
  return order
end

local function index_value(value)
  return tonumber(value) or 0
end

local function by_location(a, b)
  local window_delta = index_value(a.window_index) - index_value(b.window_index)
  if window_delta ~= 0 then return window_delta < 0 end
  local pane_delta = index_value(a.pane_index) - index_value(b.pane_index)
  if pane_delta ~= 0 then return pane_delta < 0 end
  return a.id < b.id
end

local function session_number(session_id)
  return tonumber((session_id or ""):match("%d+")) or 0
end

--- Order agent panes for the picker. The current window beats a marked pane.
--- The calling pane is omitted. `place` is window, marked, cwd, session, or other.
function M.order_agents(panes, ctx, marked_id)
  ctx = ctx or {}
  local groups = { marked = {}, window = {}, cwd = {}, session = {}, other = {} }
  for _, pane in ipairs(panes or {}) do
    if pane.id and pane.id ~= ctx.pane_id and pane.name then
      local entry = vim.tbl_extend("force", {}, pane)
      entry.foreign_session = pane.session_id ~= ctx.session_id
      entry.marked = pane.id == marked_id
      if not entry.foreign_session and pane.window_id == ctx.window_id then
        entry.place = "window"
      elseif entry.marked then
        entry.place = "marked"
      elseif not entry.foreign_session and ctx.dir and ctx.dir ~= "" and pane.dir == ctx.dir then
        entry.place = "cwd"
      elseif not entry.foreign_session then
        entry.place = "session"
      else
        entry.place = "other"
        entry.same_cwd = ctx.dir ~= nil and ctx.dir ~= "" and pane.dir == ctx.dir
      end
      table.insert(groups[entry.place], entry)
    end
  end

  for _, place in ipairs({ "window", "cwd", "session" }) do
    table.sort(groups[place], by_location)
  end
  table.sort(groups.other, function(a, b)
    if a.same_cwd ~= b.same_cwd then return a.same_cwd end
    local session_delta = session_number(a.session_id) - session_number(b.session_id)
    if session_delta ~= 0 then return session_delta < 0 end
    return by_location(a, b)
  end)

  local ordered = {}
  for _, place in ipairs({ "window", "marked", "cwd", "session", "other" }) do
    for _, entry in ipairs(groups[place]) do
      table.insert(ordered, entry)
    end
  end
  return ordered
end

local function context_from_panes(panes)
  local current = vim.env.TMUX_PANE
  if not current then return nil end
  for _, pane in ipairs(panes) do
    if pane.id == current then
      return {
        session_id = pane.session_id,
        window_id = pane.window_id,
        pane_id = pane.id,
        dir = pane.dir,
      }
    end
  end
end

--- Every codex/pi/claude pane except Neovim's, in picker order.
function M.list_agents()
  if not vim.env.TMUX or not vim.env.TMUX_PANE then return {} end
  if vim.fn.executable("tmux") == 0 then return {} end

  local panes = {}
  local all = tmux("list-panes", "-a", "-F", pane_format)
  if all and all ~= "" then
    for line in all:gmatch("[^\n]+") do
      local pane = parse_pane(line)
      if pane then table.insert(panes, pane) end
    end
  end
  local ctx = context_from_panes(panes) or current_context()
  if not ctx then return {} end
  panes = dedupe_panes(panes, ctx)

  local marked_id
  for _, pane in ipairs(panes) do
    if pane.marked and pane.id ~= ctx.pane_id then
      marked_id = pane.id
      break
    end
  end

  -- pane_current_command is often `node` or a rewritten title. One process
  -- snapshot identifies those panes; a ps/pgrep walk per process does not.
  local needs_snapshot = false
  for _, pane in ipairs(panes) do
    if pane.id ~= ctx.pane_id and not detect_agent_name(pane.cmd) then
      needs_snapshot = true
      break
    end
  end
  local snapshot = needs_snapshot and process_snapshot() or nil
  local agents = {}
  for _, pane in ipairs(panes) do
    if pane.id ~= ctx.pane_id then
      local name = detect_agent_name(pane.cmd)
        or M.agent_in_snapshot(pane.pid, snapshot)
        or (needs_snapshot and not snapshot and find_agent_in_process_tree(pane.pid))
      if name then
        pane.name = name
        -- A previous Pi in this pane can leave a stale option behind.
        if name ~= "pi" then pane.pi_session_name = nil end
        table.insert(agents, pane)
      end
    end
  end
  return M.order_agents(agents, ctx, marked_id)
end

--- Best single target: this window, then marked, then same cwd. Nil otherwise.
function M.find_pane()
  for _, agent in ipairs(M.list_agents()) do
    if agent.place == "marked" or agent.place == "window" or agent.place == "cwd" then
      return agent.id
    end
  end
end

local function display_name(agent)
  local session = agent.pi_session_name and vim.trim(agent.pi_session_name) or ""
  if session == "" then return "{noname}" end
  return session
end

local function window_key(agent)
  return agent.window_id or ((agent.session_id or "") .. "\t" .. (agent.window_index or ""))
end

local function window_counts(agents)
  local counts = {}
  for _, agent in ipairs(agents or {}) do
    local key = window_key(agent)
    counts[key] = (counts[key] or 0) + 1
  end
  return counts
end

--- Pane index only disambiguates multiple agents in the same window.
local function pane_token(agent, counts)
  if (counts[window_key(agent)] or 0) < 2 then return "" end
  if not agent.pane_index or agent.pane_index == "" then return "" end
  return "P:" .. agent.pane_index
end

--- Session names are easier to recognize than tmux's numeric session ids.
local function session_token(agent)
  local name = agent.tmux_session and vim.trim(agent.tmux_session) or ""
  if name ~= "" then return "S:" .. name end
  return "S:" .. (agent.session_id or "?"):gsub("^%$", "")
end

local function window_token(agent)
  local index = agent.window_index or "?"
  local name = agent.window_name and vim.trim(agent.window_name) or ""
  if name ~= "" then return "W:" .. index .. ":" .. name end
  return "W:" .. index
end

local function join_tokens(tokens)
  local parts = {}
  for _, token in ipairs(tokens) do
    if token and token ~= "" then table.insert(parts, token) end
  end
  return table.concat(parts, " ")
end

local function location_prefix(agent, counts)
  local pane = pane_token(agent, counts)
  -- Missing S means this session. Missing W means this window. Brackets mean elsewhere.
  if agent.place == "marked" then
    -- Same-session marks omit S:; the session name only matters across sessions.
    local session = agent.foreign_session and session_token(agent) or ""
    return "[" .. join_tokens({ "*M", session, window_token(agent), pane }) .. "]"
  elseif agent.place == "window" then
    -- A marked pane here shows *M, but not S: or W:.
    if agent.marked then return join_tokens({ "*M", pane }) end
    return pane
  elseif agent.place == "other" then
    return "[" .. join_tokens({ session_token(agent), window_token(agent), pane }) .. "]"
  end
  return "[" .. join_tokens({ window_token(agent), pane }) .. "]"
end

--- Flat picker rows. Clipboard splits this session from other sessions.
function M.action_items(agents)
  local items = {}
  local copied = false
  local function add_copy()
    if copied then return end
    copied = true
    table.insert(items, { label = "Copy to Clipboard", action = "copy" })
  end
  local counts = window_counts(agents)
  local function add_agent(agent)
    local where = location_prefix(agent, counts)
    local who = display_name(agent)
    local function row(verb)
      local label = who .. " · " .. verb
      if where ~= "" then label = label .. " " .. where end
      return label
    end
    table.insert(items, {
      label = row("Send"),
      action = "send",
      submit = false,
      pane = agent.id,
    })
    table.insert(items, {
      label = row("Send and Execute"),
      action = "send",
      submit = true,
      pane = agent.id,
    })
  end

  for _, agent in ipairs(agents or {}) do
    if agent.place == "other" then add_copy() end
    add_agent(agent)
  end
  add_copy()
  return items
end

--- Send text to the given pane (or find one). If submit is true, press Enter after.
function M.send(text, submit, pane)
  pane = pane or M.find_pane()
  if not pane then
    vim.notify("No Agent pane found", vim.log.levels.ERROR)
    return
  end

  -- Write to temp file, load into tmux buffer, paste into target pane.
  -- This handles multi-line text and special characters cleanly.
  local tmp = vim.fn.tempname()
  vim.fn.writefile(vim.split(text, "\n"), tmp)
  tmux("load-buffer", tmp)
  tmux("paste-buffer", "-p", "-t", pane)
  vim.fn.delete(tmp)

  if submit then
    tmux("send-keys", "-t", pane, "Enter")
  end
end

--- Get visual selection wrapped in a fenced code block with file context.
local function get_visual()
  local path = vim.api.nvim_buf_get_name(0)
  local ext = vim.fn.fnamemodify(path, ":e")
  vim.cmd('normal! "zy')
  -- Read '< only after the yank exits visual mode; the marks are set when
  -- Visual mode stops, so reading earlier returns the previous selection.
  local start_line = vim.fn.line("'<")
  local text = vim.fn.getreg("z")
  return path .. ":" .. start_line .. "\n```" .. ext .. "\n" .. text .. "\n```", "markdown"
end

--- Get entire buffer text and its preview filetype.
local function get_buffer()
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"), vim.bo.filetype
end

--- Copy to both the system clipboard (+) and primary selection (*).
local function copy_to_clipboard(text)
  if vim.fn.has("clipboard") == 0 then
    vim.notify("No clipboard provider available (see :help clipboard)", vim.log.levels.ERROR)
    return
  end

  local ok, err = pcall(function()
    vim.fn.setreg("+", text, "v")
    vim.fn.setreg("*", text, "v")
  end)
  if not ok then
    vim.notify("Failed to copy to clipboard: " .. tostring(err), vim.log.levels.ERROR)
    return
  end
  vim.notify("Copied to clipboard", vim.log.levels.INFO)
end

-- Shared popup for adding context while previewing the text being sent/copied.
local function prompt_and_send(text, filetype)
  local reference_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":~:.")
  if reference_name == "" then reference_name = "[No Name]" end
  local preview_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
  vim.bo[preview_buf].filetype = filetype
  vim.bo[preview_buf].modifiable = false
  vim.bo[preview_buf].readonly = true
  local buf = vim.api.nvim_create_buf(false, true)

  local function dimensions()
    -- Reserve both borders and space for the message, even on a short screen.
    local available = math.max(6, vim.o.lines - vim.o.cmdheight - 2)
    local width = math.max(1, math.min(math.floor(vim.o.columns * 0.6), vim.o.columns - 2))
    local preview_height = math.min(vim.api.nvim_buf_line_count(preview_buf),
      math.max(1, math.floor((available - 4) * 0.6)))
    local max_height = math.max(1, math.min(math.floor(available * 0.25), available - preview_height - 4))
    local row = math.max(0, math.floor((available - preview_height - max_height - 4) / 2))
    local col = math.max(0, math.floor((vim.o.columns - width - 2) / 2))
    return width, preview_height, max_height, row, col
  end

  local width, preview_height, _, row, col = dimensions()
  local preview_win = vim.api.nvim_open_win(preview_buf, false, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = preview_height,
    style = "minimal",
    border = "rounded",
    title = " Reference · " .. reference_name .. " ",
    title_pos = "center",
    footer = " <C-u>/<C-d> scroll reference ",
    footer_pos = "center",
  })
  vim.wo[preview_win].wrap = false
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row + preview_height + 2,
    col = col,
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
    title = " Context ",
    title_pos = "center",
  })
  vim.wo[win].wrap = true
  local group = vim.api.nvim_create_augroup("AgentSend" .. buf, { clear = true })
  local closed = false

  local function close()
    if closed then return end
    closed = true
    vim.api.nvim_del_augroup_by_id(group)
    vim.cmd("stopinsert")
    for _, popup in ipairs({ win, preview_win }) do
      if vim.api.nvim_win_is_valid(popup) then vim.api.nvim_win_close(popup, true) end
    end
    for _, scratch in ipairs({ buf, preview_buf }) do
      if vim.api.nvim_buf_is_valid(scratch) then vim.api.nvim_buf_delete(scratch, { force = true }) end
    end
  end

  -- Keep the reference above the message as it grows or the terminal resizes.
  local function resize()
    if closed or not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_win_is_valid(preview_win) then return end
    local w, ph, max_height, r, c = dimensions()
    vim.api.nvim_win_set_config(preview_win, { relative = "editor", row = r, col = c, width = w, height = ph })
    vim.api.nvim_win_set_config(win, { relative = "editor", row = r + ph + 2, col = c, width = w })
    local height = vim.api.nvim_win_text_height(win, {}).all
    vim.api.nvim_win_set_height(win, math.max(1, math.min(height, max_height)))
  end
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    buffer = buf,
    callback = resize,
  })
  vim.api.nvim_create_autocmd("VimResized", { group = group, callback = resize })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = { tostring(win), tostring(preview_win) },
    callback = function() vim.schedule(close) end,
  })

  -- Scroll without leaving insert mode or changing the message/cursor.
  for key, command in pairs({ ["<C-d>"] = "\004", ["<C-u>"] = "\021" }) do
    vim.keymap.set({ "i", "n" }, key, function()
      if not vim.api.nvim_win_is_valid(preview_win) then return end
      vim.api.nvim_win_call(preview_win, function() vim.cmd.normal({ command, bang = true }) end)
    end, { buffer = buf, desc = "Scroll referenced code" })
  end
  vim.cmd("startinsert")

  local function apply_choice(payload, choice)
    if not choice then return end
    if choice.action == "copy" then
      copy_to_clipboard(payload)
    elseif choice.action == "send" then
      M.send(payload, choice.submit, choice.pane)
    end
  end

  -- A second Enter is often still queued when the picker opens. Telescope then
  -- confirms before it has a selection and drops the text. Consume that Enter
  -- and run the default action instead.
  local function consume_pending_cr()
    local saw = false
    while true do
      local peeked = vim.fn.getchar(1)
      if peeked ~= 13 then break end
      vim.fn.getchar(0)
      saw = true
    end
    return saw
  end

  local submitted = false
  local function choose_action()
    if submitted or closed or not vim.api.nvim_buf_is_valid(buf) then return end
    submitted = true
    local ctx = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    local payload = ctx ~= "" and (ctx .. "\n\n" .. text) or text
    close()

    -- Let insert mode finish before opening a selector (e.g. Telescope).
    vim.schedule(function()
      local items = M.action_items(M.list_agents())
      if consume_pending_cr() then
        apply_choice(payload, items[1])
        return
      end
      vim.ui.select(items, {
        prompt = "Send",
        format_item = function(item) return item.label end,
      }, function(choice)
        apply_choice(payload, choice)
      end)
    end)
  end

  -- Enter submits. Insert-mode <C-j> stays the default newline.
  vim.keymap.set({ "i", "n" }, "<CR>", choose_action, { buffer = buf })
  vim.keymap.set({ "i", "n" }, "<C-k>", "<Up>", { buffer = buf, desc = "Move up" })
  vim.keymap.set("n", "<C-j>", "<Down>", { buffer = buf, desc = "Move down" })
  vim.keymap.set({ "i", "n" }, "<C-j>", "<Down>", { buffer = preview_buf, desc = "Move down" })
  vim.keymap.set({ "i", "n" }, "<C-k>", "<Up>", { buffer = preview_buf, desc = "Move up" })
  for _, scratch in ipairs({ buf, preview_buf }) do
    vim.keymap.set("n", "<Esc>", close, { buffer = scratch })
    vim.keymap.set("n", "q", close, { buffer = scratch })
  end
end

-- Keymaps
vim.keymap.set("v", "<leader>ps", function() prompt_and_send(get_visual()) end,
  { desc = "Send/copy selection with context" })
vim.keymap.set("n", "<leader>pb", function() prompt_and_send(get_buffer()) end,
  { desc = "Send/copy buffer with context" })

return M
