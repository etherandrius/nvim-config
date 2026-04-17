-- pi-send.lua — find nearest pi/claude tmux pane and send text to it
--
-- Priority for finding the pane:
--   1. Marked pane (if running pi/claude)
--   2. Agent pane in the current window
--   3. Agent pane with the same cwd
--   4. No match → nil
--
-- Always within the same tmux session. Never targets the calling pane.

local M = {}

local pi_commands = { pi = true, claude = true }

--- Check if a pane is running pi/claude.
--- On macOS both appear as "node" in pane_current_command because the
--- actual binary is node. The pane_pid is the shell, so we check its
--- direct children via pgrep.
local function is_agent_cmd(cmd, pid)
  if pi_commands[cmd] then return true end
  if cmd ~= "node" or not pid then return false end
  local children = vim.fn.system({ "pgrep", "-P", pid })
  if vim.v.shell_error ~= 0 then return false end
  for cpid in children:gmatch("%d+") do
    local comm = vim.trim(vim.fn.system({ "ps", "-o", "comm=", "-p", cpid }))
    if vim.v.shell_error == 0 then
      local base = comm:match("[^/]+$")
      if base and pi_commands[base] then return true end
    end
  end
  return false
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

--- Find the best pi/claude pane. Returns pane_id or nil.
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

--- Send text to the nearest pi pane. If submit is true, press Enter after.
function M.send(text, submit)
  local pane = M.find_pane()
  if not pane then
    vim.notify("No Agent pane found", vim.log.levels.WARN)
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

-- Keymaps
vim.keymap.set("v", "<leader>ps", function()
  local text = get_visual()
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.6)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor(vim.o.lines * 0.3),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
    title = " Context ",
    title_pos = "center",
  })
  vim.bo[buf].buftype = "nofile"
  vim.cmd("startinsert")

  local function submit()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local ctx = table.concat(lines, "\n")
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })
    if ctx ~= "" then
      text = ctx .. "\n\n" .. text
    end
    M.send(text, false)
  end

  local function cancel()
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })
  end

  vim.keymap.set("i", "<CR>", submit, { buffer = buf })
  vim.keymap.set("n", "<CR>", submit, { buffer = buf })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = buf })
  vim.keymap.set("n", "q", cancel, { buffer = buf })
end, { desc = "Send selection to agent with context" })
vim.keymap.set("v", "<leader>pr", function() M.send(get_visual(), true) end,
  { desc = "Send selection to pi and submit" })
vim.keymap.set("n", "<leader>pb", function() M.send(get_buffer(), false) end,
  { desc = "Send buffer to pi" })

return M
