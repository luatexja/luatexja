--
-- luatexja/infomute.lua
--
luatexbase.provides_module({
  name = 'luatexja.infomute',
  date = '2011/04/01',
  version = '0.1',
  description = '',
})
module('luatexja.infomute', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

--------------------
--! luatexbase.module_info() で特定のモジュールの情報出力だけ
--! 抑止したい. 

local org_texio = texio
local patch_applied = false
local info_mute = {}

local function pick_module_name(line)
  local mod
  if line:sub(1, 7) == "Module " then
     local s, e = line:find(" ", 8, true)
     if s then mod = line:sub(8, s - 1) end
  elseif line:sub(1, 1) == "(" then
     local s, e = line:find(")", 2, true)
     if s then mod = line:sub(2, s - 1) end
  end
  return mod
end

local function patched_write_nl(line, ...)
  local mod = pick_module_name(line)
  if not (mod and info_mute[mod]) then
    org_texio.write_nl(line, ...)
  end
end

local new_texio = setmetatable({ write_nl = patched_write_nl },
  { __index = org_texio })
local org_fenv = getfenv(luatexbase.module_info)

local function apply_patch()
  setfenv(luatexbase.module_info,
    setmetatable({ texio = new_texio }, { __index = org_fenv }))
  patch_applied = true
end

--! モジュール mod の情報出力を抑止する.
function add_mute(mod)
  info_mute[mod] = true
  if not patch_applied then
    apply_patch()
  end
end

-------------------- all done
-- EOF
