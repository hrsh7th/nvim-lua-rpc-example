local rpc = require('rpc')

local c = rpc.create(
  string.format('/tmp/server-%s.sock', os.clock()),
  'rpc_server'
)

c:request('concat', {
  a = 'foo',
  b = 'bar',
}, function(result)
  print(result)
  c:request('concat', {
    a = 'foo1',
    b = 'bar2',
  }, function(result)
    print(result)
  end)
end)
