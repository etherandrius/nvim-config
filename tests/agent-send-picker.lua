-- Run: nvim --headless -u NONE -i NONE -l ~/.config/nvim/tests/agent-send-picker.lua
local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.rtp:prepend(config)
for _, plugin in ipairs({ "plenary.nvim", "telescope.nvim", "telescope-ui-select.nvim" }) do
  vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end
local checks = 0
local function check(ok, label)
  assert(ok, label)
  checks = checks + 1
end

-- Use the actual dropdown configuration without loading unrelated init.lua plugins.
local init = table.concat(vim.fn.readfile(config .. "/init.lua"), "\n")
local dropdown = assert(init:match('%["ui%-select"%]%s*=%s*{%s*require%("telescope%.themes"%)%.get_dropdown%s*(%b{})'))
local opts = assert(loadstring('return require("telescope.themes").get_dropdown ' .. dropdown))()
require("telescope").setup({ extensions = { ["ui-select"] = { opts } } })
require("telescope").load_extension("ui-select")

local agent = require("agent-send")
agent.find_pane = function() return nil end
agent.list_agents = function()
  return {
    {
      id = "%7",
      name = "pi",
      place = "window",
      session_id = "$1",
      window_index = "1",
      window_name = "nvim",
      pane_index = "1",
      pi_session_name = "notes",
      dir = "/tmp/nvim",
    },
  }
end
local sent
agent.send = function(text, submit, pane) sent = { text = text, submit = submit, pane = pane } end
local send_label = "notes · Send"
local execute_label = "notes · Send and Execute"
local source = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(source, 0, -1, false, { "local example = true" })
vim.bo[source].filetype = "lua"
vim.fn.maparg("\\pb", "n", false, true).callback()
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Explain this" })
vim.fn.maparg("<CR>", "i", false, true).callback()
check(vim.wait(3000, function() return vim.bo.filetype == "TelescopePrompt" end, 10), "real action picker opens")
local prompt = vim.api.nvim_get_current_buf()
local picker = require("telescope.actions.state").get_current_picker(prompt)
check(vim.wait(3000, function() return picker.manager:num_results() == 3 end, 10), "all three actions available")
local state = require("telescope.actions.state")
local function selected() return state.get_selected_entry().value.text.label end
check(selected() == send_label, "first action selected initially")

-- Flush Telescope's queued insert-mode entry before driving keys ourselves.
vim.api.nvim_feedkeys("", "x", false)
vim.cmd("stopinsert")
-- Real keystrokes verify both insert-mode and normal-mode picker mappings.
for _, mode in ipairs({ "i", "n" }) do
  for _, move in ipairs({
    { "<C-j>", execute_label },
    { "<C-j>", "Copy to Clipboard" },
    { "<C-k>", execute_label },
    { "<C-k>", send_label },
  }) do
    local sequence = mode == "i" and ("i" .. move[1] .. "<Esc>") or move[1]
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(sequence, true, false, true), "xt", false)
    check(selected() == move[2], move[1] .. " selects " .. move[2] .. " in " .. mode .. " mode")
    check(sent == nil, "navigation does not submit")
    check(picker:_get_prompt() == "", "navigation does not edit the filter")
  end
end
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<C-j><CR>", true, false, true), "xt", false)
check(vim.wait(1000, function() return sent ~= nil end, 10), "Enter activates the selected action")
check(sent.submit == true and sent.pane == "%7" and sent.text == "Explain this\n\nlocal example = true",
  "execute receives the original payload and chosen pane")
check(vim.api.nvim_get_current_buf() == source, "picker closes back to source")
print(string.format("%d checks passed", checks))
vim.cmd("qa!")
