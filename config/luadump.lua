--
-- luadump.lua
--

-- ToDo: initex 時の dofile(), loadfile() の hack
--       restore 時の require(), dofile(), loadfile() の hack
--       読み込み済みファイルリストの作成．

module('luadump', package.seeall)

local require = _G.require

function require_and_register(modname)
   local ret = require(modname)

   local modfilename = string.gsub(modname, '[.]', '/') .. '.lua'
   local modfilepath = kpse.find_file(modfilename)
   if modfilepath then
      lua.bytecode[bytecode_index] = loadfile(modfilepath)
      bytecode_index = bytecode_index + 1
   end

   return ret
end

function init()
   bytecode_index = 1
   _G.require = require_and_register
end

function finalize()
   _G.require = require
end

function restore()
   local write_nl = texio.write_nl
   texio.write_nl = function() end
   local i = 1
   while lua.bytecode[i] do
      print(i)
      lua.bytecode[i]()
      lua.bytecode[i] = nil
      i = i + 1
   end
   texio.write_nl = write_nl
end