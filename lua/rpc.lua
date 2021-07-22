local uv = require('luv')
local client = require('rpc.client')

---@see neovim/src/nvim/lua/vim.lua [vim._load_package(name)]
local resolve_module = function(name)
  local basename = name:gsub('%.', '/')
  local paths = {"lua/"..basename..".lua", "lua/"..basename.."/init.lua"}
  for _,path in ipairs(paths) do
    local found = vim.api.nvim_get_runtime_file(path, false)
    if #found > 0 then
      return found[1]
    end
  end
  return nil
end

local rpc = {}

rpc.create = function(sock, module_name)

  uv.new_thread(function(sock, client_path, module_path)
    local uv = require('luv')
    local server = uv.new_pipe(false)
    local client = loadfile(client_path)()
    local module = loadfile(module_path)()
    server:bind(sock)
    server:listen(128, function()
      local pipe = uv.new_pipe(false)
      server:accept(pipe)
      local c = client.new(pipe)
      for k, v in pairs(module) do
        c.on_request[k] = v
      end
      c:start()
    end)
    uv.run('default')
  end, sock, resolve_module('rpc.client'), resolve_module(module_name))

  vim.wait(1000, function()
    return uv.fs_stat(sock)
  end)

  local pipe = uv.new_pipe(false)
  pipe:connect(sock)
  local c = client.new(pipe)
  c:start()
  return c
end

return rpc

