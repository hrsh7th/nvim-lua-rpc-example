local uv = require('luv')
local mpack = require('mpack')

local client = {}

client.new = function(pipe)
  local self = setmetatable({}, { __index = client })
  self.pipe = pipe
  self.request_id = 1
  self.pending_requests = {}
  self.buffer = ''
  self.pack = mpack.Packer()
  self.unpack =mpack.Unpacker()
  self.on_request = {}
  self.on_notification = {}
  return self
end

client.start = function(self)
  self.pipe:read_start(function(_, chunk)
    if not chunk then
      return
    end

    self.buffer = self.buffer .. chunk
    while self.buffer ~= '' do
      local res, off = self.unpack(self.buffer)
      if not res then
        return
      end
      self.buffer = string.sub(self.buffer, off)

      if res[1] == 0 then
        if self.on_request[res[3]] then
          self.on_request[res[3]](res[4], function(result)
            self.pipe:write(self.pack({ 1, res[2], nil, result }))
          end)
        end
      elseif res[1] == 2 then
        if self.on_notification[res[3]] then
          self.on_notification[res[3]](res[4])
        end
      elseif res[1] == 1 then
        if self.pending_requests[res[2]] then
          self.pending_requests[res[2]](res[4])
          self.pending_requests[res[2]] = nil
        end
      end
    end
  end)
end

client.request = function(self, method, params)
  self.request_id = self.request_id + 1
  self.pipe:write(self.pack({ 0, self.request_id, method, params }))
  local request = setmetatable({
    status = 'waiting',
    result = nil,
    callbacks = {},
  }, {
    __call = function(s, callback)
      if callback then
        if s.status == 'waiting' then
          table.insert(s.callbacks, callback)
        else
          callback(s.result)
        end
      else
        while s.status == 'waiting' do
          uv.run('once')
        end
        return s.result
      end
    end
  })
  self.pending_requests[self.request_id] = function(result)
    request.result = result
    request.status = 'completed'
    for _, callback in ipairs(request.callbacks) do
      callback(result)
    end
  end
  return request
end

client.notify = function(self, method, params)
  self.pipe:write(self.pack({ 2, method, params }))
end

return client

