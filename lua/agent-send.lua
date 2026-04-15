-- pi-send.lua — find nearest pi/claude tmux pane and send text to it
--
-- Priority for finding the pane:
--   1. Marked pane (if running pi/claude)
--   2. Panes in the current window
--   3. Panes in other windows — same cwd first, then rest
--
-- Always within the same tmux session. Never targets the calling pane.

local M = {}

local pi_commands = { pi = true, claude = true }

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
  local marked = tmux("display-message", "-p", "-t", "{marked}", "#{pane_id}\t#{pane_current_command}")
  if marked then
    local id, cmd = marked:match("^(%%[^\t]+)\t(.+)$")
    if id and pi_commands[cmd] and id ~= cur_pane then
      return id
    end
  end

  -- 2. Current window panes
  local panes = tmux("list-panes", "-t", session .. ":" .. cur_window,
    "-F", "#{pane_id}\t#{pane_current_command}")
  if panes then
    for line in panes:gmatch("[^\n]+") do
      local id, cmd = line:match("^(%%[^\t]+)\t(.+)$")
      if id and pi_commands[cmd] and id ~= cur_pane then
        return id
      end
    end
  end

  -- 3. Other windows — prefer same cwd
  local all = tmux("list-panes", "-s", "-t", session,
    "-F", "#{pane_id}\t#{pane_current_command}\t#{window_id}\t#{pane_current_path}")
  if not all then return nil end

  for line in all:gmatch("[^\n]+") do
    local id, cmd, win, dir = line:match("^(%%[^\t]+)\t([^\t]+)\t([^\t]+)\t(.+)$")
    if id and pi_commands[cmd] and id ~= cur_pane and win ~= cur_window and dir == cur_dir then
      return id
    end
  end

  return nil
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

--- Get visual selection text.
local function get_visual()
  vim.cmd('normal! "zy')
  return vim.fn.getreg("z")
end

--- Get entire buffer text.
local function get_buffer()
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

-- Keymaps
vim.keymap.set("v", "<leader>ps", function() M.send(get_visual(), false) end,
  { desc = "Send selection to pi" })
vim.keymap.set("v", "<leader>pr", function() M.send(get_visual(), true) end,
  { desc = "Send selection to pi and submit" })
vim.keymap.set("n", "<leader>pb", function() M.send(get_buffer(), false) end,
  { desc = "Send buffer to pi" })

return M
