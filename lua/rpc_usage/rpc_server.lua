local M = {}

M.concat = function(params, callback)
  callback(params.a .. params.b)
end

M.get_buffer_option = function(params, callback)
  callback(vim.api.nvim_buf_get_option(0, params.option))
end

return M

