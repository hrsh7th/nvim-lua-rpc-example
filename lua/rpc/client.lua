local uv = require('luv')
local mpack = require('mpack')

local client = {}

client.new = function(name, pipe)
  local self = setmetatable({}, { __index = client })
  self.name = name
  self.pipe = pipe
  self.request_id = 1
  self.pending_requests = {}
  self.buffer = ''
  self.consumer = uv.new_timer()
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
    self.consumer:stop()
    self.consumer:start(1, 0, function()
      self:consume()
    end)
  end)
end

client.consume = function(self)
  if self.buffer == '' then
    return
  end

  local unpacker = mpack.Unpacker()
  local res, off = unpacker(self.buffer)
  if not res then
    return -- wait for more payload
  end
  self.buffer = string.sub(self.buffer, off)

  if res[1] == 0 then
    if self.on_request[res[3]] then
      local ok, err = pcall(function()
        self.on_request[res[3]](res[4], function(result)
          self:write({ 1, res[2], nil, result })
        end)
      end)
      if not ok then
        self:write({ 1, res[2], err, nil })
      end
    end
  elseif res[1] == 2 then
    if self.on_notification[res[3]] then
      pcall(function()
        self.on_notification[res[3]](res[4])
      end)
    end
  elseif res[1] == 1 then
    if self.pending_requests[res[2]] then
      self.pending_requests[res[2]](res[3], res[4])
      self.pending_requests[res[2]] = nil
    end
  end
  self.consumer:stop()
  self.consumer:start(1, 0, function()
    self:consume()
  end)
end

client.request = function(self, method, params)
  self.request_id = self.request_id + 1
  self:write({ 0, self.request_id, method, params })
  local request = setmetatable({
    status = 'waiting',
    err = nil,
    res = nil,
    callbacks = {},
  }, {
    __call = function(s, callback)
      if callback then
        if s.status == 'waiting' then
          table.insert(s.callbacks, callback)
        else
          callback(s.err, s.res)
        end
      else
        while s.status == 'waiting' do
          if vim.defer_fn then
            vim.wait(100 * 1000, function()
              return s.status ~= 'waiting'
            end, 1, false)
          else
            uv.run('once')
          end
        end
        if s.err then
          error(s.err)
        end
        return s.res
      end
    end
  })
  self.pending_requests[self.request_id] = function(err, res)
    request.err = err
    request.res = res
    request.status = 'completed'
    for _, callback in ipairs(request.callbacks) do
      callback(request.err, request.res)
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

