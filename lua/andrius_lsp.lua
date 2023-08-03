local log = require('vim.lsp.log')
local util = require('vim.lsp.util')
local api = vim.api

local M = {}

---@private
--- Jumps to a location. Used as a handler for multiple LSP methods.
---@param _ (not used)
---@param result (table) result of LSP method; a location or a list of locations.
---@param ctx (table) table containing the context of the request, including the method
---(`textDocument/definition` can return `Location` or `Location[]`
function M.custom_location_handler(unk, result, ctx, config)
  print("unknonw: ", unk)
  print("result: ", vim.inspect(result))
  print("ctx: ", vim.inspect(ctx))
  print("config: ", config)
  if result == nil or vim.tbl_isempty(result) then
    local _ = log.info() and log.info(ctx.method, 'No location found')
    return nil
  end
  local client = vim.lsp.get_client_by_id(ctx.client_id)

  config = config or {}

  -- textDocument/definition can return Location or Location[]
  -- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_definition

  if vim.tbl_islist(result) then
    local title = 'LSP locations'
    local items = util.locations_to_items(result, client.offset_encoding)

    if config.on_list then
      assert(type(config.on_list) == 'function', 'on_list is not a function')
      config.on_list({ title = title, items = items })
    else
      if #result == 1 then
        util.jump_to_location(result[1], client.offset_encoding, config.reuse_win)
        return
      end
      vim.fn.setqflist({}, ' ', { title = title, items = items })
      api.nvim_command('botright copen')
    end
  else
    util.jump_to_location(result, client.offset_encoding, config.reuse_win)
  end
end

return M
