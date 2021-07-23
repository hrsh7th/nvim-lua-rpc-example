local proxy = {}

proxy.new = function(path, call)
  return setmetatable({
    path = path,
    call = call,
  }, {
    __index = function(self, new_key)
      local new_path = {}
      for _, key in ipairs(self.path) do
        table.insert(new_path, key)
      end
      table.insert(new_path, new_key)
      return proxy.new(new_path, self.call)
    end,
    __call = function(self, ...)
      return self.call(self.path, ...)
    end
  })
end

return proxy

