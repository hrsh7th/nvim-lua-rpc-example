local uv = require('luv')
local mpack = require('mpack')

local client = {}

client.new = function(pipe)
  local self = setmetatable({}, { __index = client })
  self.pipe = pipe
  self.pipe:set_blocking(true)
  self.request_id = 1
  self.pending_requests = {}
  self.buffer = ''
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

    local unpacker = mpack.Unpacker()
    local res
    local off = 1
    while off <= #self.buffer do
      res, off = unpacker(self.buffer, off)
      if not res then
        return -- wait for more payload
      end

      if res[1] == 0 then
        if self.on_request[res[3]] then
          self.on_request[res[3]](res[4], function(result)
            self:write({ 1, res[2], nil, result })
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
    self.buffer = string.sub(self.buffer, off)
  end)
end

client.request = function(self, method, params)
  self.request_id = self.request_id + 1
  self:write({ 0, self.request_id, method, params })
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
          uv.sleep(100)
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
  self:write({ 2, method, params })
end

client.write = function(self, msg)
  local packer = mpack.Packer()
  self.pipe:write(packer(msg))
end

return client

