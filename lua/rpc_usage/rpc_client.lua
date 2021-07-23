local rpc = require('rpc')

local c = rpc.create(
  string.format('/tmp/server-%s.sock', os.clock()),
  'rpc_usage.rpc_server'
)

-- Get buffer option via server
local req = c:request('get_buffer_option', {
  option = 'filetype'
})

req(function(err, res)
  print(err, vim.inspect(res))
end)

