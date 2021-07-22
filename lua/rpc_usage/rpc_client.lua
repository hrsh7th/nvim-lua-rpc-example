local rpc = require('rpc')

local c = rpc.create(
  string.format('/tmp/server-%s.sock', os.clock()),
  'rpc_usage.rpc_server'
)

-- Avoid sequential call
local req1 = c:request('concat', {
  a = 'foo',
  b = 'bar',
})
local req2 = c:request('concat', {
  a = 'foo1',
  b = 'bar1',
})
local req3 = c:request('fib', {
  n = 44
})

-- Retrieve
print(req1())
print(req2())

-- Retrieve async
req3(function(result)
  print(result)
end)

