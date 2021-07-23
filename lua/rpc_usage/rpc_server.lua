local char = require'cmp.utils.char'

local M = {}

M.concat = function(params, callback)
  callback(params.a .. params.b)
end

M.get_buffer_option = function(params, callback)
  local option = vim.api.nvim_buf_get_option(0, params.option)
  local firstline = vim.api.nvim_buf_get_lines(0, 0, 1, false)
  callback({ option, char.is_symbol(string.byte('[')), firstline[1] })
end

return M

