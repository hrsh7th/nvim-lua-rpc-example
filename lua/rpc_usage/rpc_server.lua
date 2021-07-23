local M = {}

M.concat = function(params, callback)
  callback(params.a .. params.b)
end

M.get_buffer_option = function(params, callback)
  local option = vim.api.nvim_buf_get_option(0, params.option)
  local fib
  fib = function(n)
    if n < 3 then
      return n
    end
    return fib(n - 1) + fib(n - 2)
  end
  local firstline = vim.api.nvim_buf_get_lines(0, 0, 1, false)
  callback({ option, fib(44), firstline[1] })
end

return M

