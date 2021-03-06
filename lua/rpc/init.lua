local uv = require('luv')
local client = require('rpc.client')
local proxy  = require('rpc.proxy')

--@see neovim/src/nvim/lua/vim.lua
local resolve = function(name)
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
  uv.new_thread(
    function(sock, client_path, proxy_path, module_path)
      local uv = require('luv')
      local proxy = loadfile(proxy_path)()
      local client = loadfile(client_path)()

      local server = uv.new_pipe(false)
      server:bind(sock)
      server:listen(128, function()
        local pipe = uv.new_pipe(false)
        server:accept(pipe)

        local c = client.new('server', pipe)
        c.on_request['$/connect'] = function(params, callback)
          table.insert(package.loaders, 1, function(module)
            local filename = c:request('$/resolve', {
              module = module,
            })()
            local f, e = loadfile(filename)
            return f or error(e)
          end)

          -- print
          _G.print = function(...)
            return c:request('$/execute', {
              path = { 'print' },
              args = { ... },
            })()
          end

          _G.vim = {
            -- vim.inspect
            inspect = function(...)
              return c:request('$/execute', {
                path = { 'vim', 'inspect' },
                args = { ... }
              })()
            end,
            -- vim.api.*
            api = proxy.new({ 'vim', 'api' }, function(path, ...)
              return c:request('$/execute', {
                path = path,
                args = { ... }
              })()
            end)
          }

          -- export methods.
          for k, v in pairs(loadfile(module_path)()) do
            c.on_request[k] = v
          end

          -- connected.
          callback()
        end
        c:start()
      end)
      uv.run('default')
    end,
    sock,
    resolve('rpc.client'),
    resolve('rpc.proxy'),
    resolve(module_name)
  )

  vim.wait(1000, function()
    return uv.fs_stat(sock)
  end)

  -- create client
  local pipe = uv.new_pipe(false)
  pipe:connect(sock)
  local c = client.new('client', pipe)
  c.on_request['$/resolve'] = function(params, callback)
    vim.schedule(function()
      callback(resolve(params.module))
    end)
  end
  c.on_request['$/execute'] = function(params, callback)
    local F = _G
    for _, key in ipairs(params.path) do
      F = F[key]
    end
    if vim.in_fast_event() then
      vim.schedule(function()
        callback(F(unpack(params.args)))
      end)
    else
      callback(F(unpack(params.args)))
    end
  end
  c:start()
  c:request('$/connect')()
  return c
end

return rpc

