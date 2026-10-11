-- agent-send.lua — send text to the nearest codex/pi/claude tmux pane or clipboard
--
-- Priority for finding the pane:
--   1. Marked pane (if running codex/pi/claude)
--   2. Agent pane in the current window
--   3. Agent pane with the same cwd
--   4. No match → nil
--
-- Unmarked panes are searched only within the same tmux session.
-- A marked pane may be in another session; the popup title labels that session.
-- Never targets the calling pane. Outside tmux, use the clipboard option.

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
  -- Anchor queries to Neovim's pane, not whichever tmux client is active.
  if vim.env.TMUX_PANE then
    return tmux("display-message", "-p", "-t", vim.env.TMUX_PANE, fmt)
  end
  return tmux("display-message", "-p", fmt)
end

--- Find the best codex/pi/claude pane. Returns pane_id or nil.
function M.find_pane()
  -- Outside tmux there is no reliable calling session; copying still works.
  if not vim.env.TMUX or not vim.env.TMUX_PANE then return nil end
  if vim.fn.executable("tmux") == 0 then return nil end
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

--- Detect the agent name running in a pane.
local function agent_name_for_pane(pane)
  local info = tmux("display-message", "-p", "-t", pane, "#{pane_current_command}\t#{pane_pid}")
  if not info then return "agent" end
  local cmd, pid = info:match("^([^\t]+)\t(%d+)$")
  return detect_agent_name(cmd) or (pid and find_agent_in_process_tree(pid)) or "agent"
end

--- Label targets outside Neovim's tmux window; session differences take priority.
local function pane_location_label(pane)
  if not pane or not vim.env.TMUX or not vim.env.TMUX_PANE then return nil end
  local fmt = "#{session_id}\t#{window_id}\t#{window_index}"
  local source = tmux_var(fmt)
  local target = tmux("display-message", "-p", "-t", pane, fmt)
  local source_session, source_window = (source or ""):match("^([^\t]+)\t([^\t]+)\t%d+$")
  local target_session, target_window, target_index = (target or ""):match("^([^\t]+)\t([^\t]+)\t(%d+)$")
  if not source_session or not target_session then return nil end

  if source_session ~= target_session then
    -- Keep the normal title colors, adding only an underline to the label.
    vim.api.nvim_set_hl(0, "AgentSendSessionWarning", { underline = true, default = true })
    return "!s:" .. target_session:gsub("^%$", ""), { "FloatTitle", "AgentSendSessionWarning" }
  elseif source_window ~= target_window then
    -- Compare stable IDs, but display the number used in tmux's status bar.
    return "w:" .. target_index, "FloatTitle"
  end
end

-- Shared popup for adding context while previewing the text being sent/copied.
local function prompt_and_send(text, filetype)
  local reference_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":~:.")
  if reference_name == "" then reference_name = "[No Name]" end
  local pane = M.find_pane()
  local target = "no agent found"
  if pane then
    local name = agent_name_for_pane(pane)
    local path = tmux("display-message", "-p", "-t", pane, "#{pane_current_path}") or ""
    local folder = vim.fn.fnamemodify(path, ":t")
    local session_name = name == "pi"
        and tmux("display-message", "-p", "-t", pane, "#{@pi_session_name}")
        or nil
    target = name
    if session_name and session_name ~= "" then target = target .. " · " .. session_name end
    if folder ~= "" then target = target .. " · " .. folder end
  end
  local title = { { " " .. target .. " ", "FloatTitle" } }
  local location, location_hl = pane_location_label(pane)
  if location then
    title = { { " " .. target .. " · ", "FloatTitle" }, { location, location_hl }, { " ", "FloatTitle" } }
    target = target .. " · " .. location
  end
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
    title = title,
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

  local function choose_action()
    local ctx = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    local payload = ctx ~= "" and (ctx .. "\n\n" .. text) or text
    close()

    -- Let insert mode finish before opening a selector (e.g. Telescope).
    vim.schedule(function()
      vim.ui.select({
        "Send to Agent",
        "Send to Agent and Execute",
        "Copy to Clipboard",
      }, { prompt = "Action -> " .. target }, function(choice)
        if choice == "Send to Agent" then
          M.send(payload, false, pane)
        elseif choice == "Send to Agent and Execute" then
          M.send(payload, true, pane)
        elseif choice == "Copy to Clipboard" then
          copy_to_clipboard(payload)
        end
      end)
    end)
  end

  -- Enter: choose paste only, paste + execute, or clipboard copy.
  vim.keymap.set({ "i", "n" }, "<CR>", choose_action, { buffer = buf })
  for _, scratch in ipairs({ buf, preview_buf }) do
    vim.keymap.set({ "i", "n" }, "<C-j>", "<Down>", { buffer = scratch, desc = "Move down" })
    vim.keymap.set({ "i", "n" }, "<C-k>", "<Up>", { buffer = scratch, desc = "Move up" })
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
