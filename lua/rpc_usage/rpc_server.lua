local M = {}

local fib
fib = function(n)
  if n < 3 then
    return n
  end
  return fib(n - 1) + fib(n - 2)
end

M.concat = function(params, callback)
  callback(params.a .. params.b)
end

M.fib = function(params, callback)
  callback(fib(params.n))
end

return M

