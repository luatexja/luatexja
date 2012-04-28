--
-- luatexja/tangle.lua
--
luatexbase.provides_module({
  name = 'luatexja.tangle',
  date = '2011/04/01',
  version = '0.1',
  description = '',
})
module('luatexja.tangle', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

--! ixbase0 からの移植

local _DONE, _TEX, _STOP = 0, 1, 2
local _current_co, _interrupted
local _resume, _check

local resume_code =
  "\\directlua{".._NAME..".resume()}\\relax"

function execute(func, ...)
  if _current_co then
    err("tangle is going now")
  end
  local args = { ... }
  local co = coroutine.create(function()
    return _DONE, { func(unpack(args)) }
  end)
  _current_co = co
  _interrupted = false
  return _check(coroutine.resume(co, ...))
end

function resume()
  return _resume(false)
end

function interrupt()
  return _resume(true)
end

function run_tex()
  coroutine.yield(_TEX, {})
end

function suspend(...)
  local intr = coroutine.yield(_STOP, { ... })
  if intr then
    _interrupted = true
    error("*INTR*") -- this error is caught later
  end
end

function _resume(intr)
  if not _current_co then
    err("tangle is not going")
  end
  local co = _current_co
  return _check(coroutine.resume(co, intr))
end

function _check(costat, tstat, extra)
  if not costat then  -- error in coroutine
    _current_co = nil
    if _interrupted then return end
    err(tstat)
  elseif tstat == _DONE then
    _current_co = nil
  elseif tstat == _TEX then
    tex.print(resume_code)
  end
  return unpack(extra)
end

-- EOF

