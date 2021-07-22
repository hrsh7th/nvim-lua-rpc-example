local rpc = require('rpc')

local c = rpc.create(
  string.format('/tmp/server-%s.sock', os.clock()),
  'rpc_usage.rpc_server'
)

local result
result = c:request('concat', {
  a = 'foo',
  b = 'bar',
})
print(result)
result = c:request('concat', {
  a = 'foo1',
  b = 'bar1',
})
print(result)

