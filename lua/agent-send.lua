-- agent-send.lua — find nearest codex/pi/claude tmux pane and send text to it
--
-- Priority for finding the pane:
--   1. Marked pane (if running codex/pi/claude)
--   2. Agent pane in the current window
--   3. Agent pane with the same cwd
--   4. No match → nil
--
-- Always within the same tmux session. Never targets the calling pane.

local M = {}

local agent_commands = { codex = true, pi = true, claude = true }
local agent_command_patterns = {
  codex = {
    "/codex[%s%-/%.]",
    "/codex$",
    "@openai/codex",
  },
  pi = {
    "/pi[%s%-/%.]",
    "/pi$",
  },
  claude = {
    "/claude[%s%-/%.]",
    "/claude$",
    "claude%-code",
  },
}

local function detect_agent_name(text)
  if not text or text == "" then return nil end

  local base = text:match("[^/]+$") or text
  if agent_commands[base] then return base end

  for name, patterns in pairs(agent_command_patterns) do
    for _, pattern in ipairs(patterns) do
      if text:match(pattern) then
        return name
      end
    end
  end

  return nil
end

--- Walk a process tree and detect which agent (if any) is running.
--- Returns the agent name ("codex", "pi", "claude") or nil.
--- Wrapper CLIs often show up as `node`, so scan both the process name and
--- the full command line, then recurse into descendants.
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

--- Check if a pane is running codex/pi/claude.
-- pane_current_command reads ucomm/proc title, which agents may rewrite —
-- e.g. claude sets it to its version ("2.1.121"). So if the direct match
-- fails, walk the pane's process tree instead of gating on one wrapper name.
local function is_agent_cmd(cmd, pid)
  return detect_agent_name(cmd) ~= nil or find_agent_in_process_tree(pid) ~= nil
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
  return tmux("display-message", "-p", fmt)
end

--- Find the best codex/pi/claude pane. Returns pane_id or nil.
function M.find_pane()
  local session = tmux_var("#{session_name}")
  local cur_window = tmux_var("#{window_id}")
  local cur_pane = tmux_var("#{pane_id}")
  local cur_dir = tmux_var("#{pane_current_path}")
  if not session then return nil end

  -- 1. Marked pane
  local marked = tmux("display-message", "-p", "-t", "{marked}", "#{pane_id}\t#{pane_current_command}\t#{pane_pid}")
  if marked then
    local id, cmd, pid = marked:match("^(%%[^\t]+)\t([^\t]+)\t(%d+)$")
    if id and is_agent_cmd(cmd, pid) and id ~= cur_pane then
      return id
    end
  end

  -- 2 & 3. Scan all panes in the session
  local all = tmux("list-panes", "-s", "-t", session,
    "-F", "#{pane_id}\t#{pane_current_command}\t#{pane_pid}\t#{window_id}\t#{pane_current_path}")
  if not all then return nil end

  local cur_win_match, same_cwd_match
  for line in all:gmatch("[^\n]+") do
    local id, cmd, pid, win_id, dir = line:match("^(%%[^\t]+)\t([^\t]+)\t(%d+)\t([^\t]+)\t(.+)$")
    if id and is_agent_cmd(cmd, pid) and id ~= cur_pane then
      if win_id == cur_window and not cur_win_match then
        cur_win_match = id          -- priority 2: current window
      elseif dir == cur_dir and not same_cwd_match then
        same_cwd_match = id         -- priority 3: same cwd
      end
    end
  end

  return cur_win_match or same_cwd_match
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
  local start_line = vim.fn.line("'<")
  local path = vim.api.nvim_buf_get_name(0)
  local ext = vim.fn.fnamemodify(path, ":e")
  vim.cmd('normal! "zy')
  local text = vim.fn.getreg("z")
  return path .. ":" .. start_line .. "\n```" .. ext .. "\n" .. text .. "\n```"
end

--- Get entire buffer text.
local function get_buffer()
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

-- Shared popup for adding context before sending
--- Detect the agent name running in a pane.
local function agent_name_for_pane(pane)
  local info = tmux("display-message", "-p", "-t", pane, "#{pane_current_command}\t#{pane_pid}")
  if not info then return "agent" end
  local cmd, pid = info:match("^([^\t]+)\t(%d+)$")
  return detect_agent_name(cmd) or (pid and find_agent_in_process_tree(pid)) or "agent"
end

local function prompt_and_send(text)
  local pane = M.find_pane()
  if not pane then
    vim.notify("No Agent pane found", vim.log.levels.WARN)
    return
  end
  local name = agent_name_for_pane(pane)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.6)
  local min_height = 1
  local max_height = math.floor(vim.o.lines * 0.4)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor(vim.o.lines * 0.3),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = min_height,
    style = "minimal",
    border = "rounded",
    title = " Send to -> " .. name .. " ",
    title_pos = "center",
  })
  vim.bo[buf].buftype = "nofile"
  vim.cmd("startinsert")

  -- Auto-resize as text grows
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = buf,
    callback = function()
      if not vim.api.nvim_win_is_valid(win) then return end
      local line_count = vim.api.nvim_buf_line_count(buf)
      local new_height = math.max(min_height, math.min(line_count, max_height))
      vim.api.nvim_win_set_height(win, new_height)
    end,
  })

  local function do_send(submit_flag)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local ctx = table.concat(lines, "\n")
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.cmd("stopinsert")
    if ctx ~= "" then
      text = ctx .. "\n\n" .. text
    end
    M.send(text, submit_flag, pane)
  end

  local function cancel()
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.cmd("stopinsert")
  end

  -- Enter: send and submit
  vim.keymap.set("i", "<CR>", function() do_send(false) end, { buffer = buf })
  vim.keymap.set("n", "<CR>", function() do_send(false) end, { buffer = buf })
  -- -- Ctrl+Enter / Ctrl+s: send without submitting (paste only)
  -- vim.keymap.set("i", "<C-s>", function() do_send(false) end, { buffer = buf })
  -- vim.keymap.set("n", "<C-s>", function() do_send(false) end, { buffer = buf })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = buf })
  vim.keymap.set("n", "q", cancel, { buffer = buf })
end

-- Keymaps
vim.keymap.set("v", "<leader>ps", function() prompt_and_send(get_visual()) end,
  { desc = "Send selection to agent with context" })
vim.keymap.set("n", "<leader>pb", function() prompt_and_send(get_buffer()) end,
  { desc = "Send buffer to agent" })

return M
