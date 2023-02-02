local M = {}

M.selectVisual = function (
  startLine,
  startCol,
  endLine,
  endCol
  )
  vim.fn.execute("normal! "
  .. startLine .. "G" .. startCol .. "|" -- start position
  .. "v" -- enter visual mode
  .. endLine .. "G" .. endCol .. "|") -- end position
end

M.shrinkVisual = function ()
  local startLine = vim.fn.line("'<")
  local startCol = vim.fn.col("'<")
  local endLine = vim.fn.line("'>")
  local endCol = vim.fn.col("'>")

  local startLineLen= vim.fn.getline(startLine):len()
  local endLineLen= vim.fn.getline(endLine):len()

  --  visual selection is weird $ corresponds to a collumn value longer than the text
  startCol = math.min(startCol, startLineLen)
  endCol = math.min(endCol, endLineLen)

  if startCol == startLineLen then
    startCol = 1
    startLine = startLine + 1
  else
    startCol = startCol + 1
  end

  if endCol == 1 then
    endCol = vim.fn.getline(endLine -1):len()
    endLine = endLine - 1
  else
    endCol = endCol - 1
  end

  M.selectVisual(startLine, startCol, endLine, endCol)
end

return M
