local M = {}

M.concat = function(params, callback)
  callback(params.a .. params.b)
end

return M

