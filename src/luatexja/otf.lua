--
-- luatexja/otf.lua
--
luatexbase.provides_module({
  name = 'luatexja.otf',
  date = '2011/09/09',
  version = '0.1',
  description = 'The OTF Lua module for LuaTeX-ja',
})
module('luatexja.otf', package.seeall)

require('luatexja.base');      local ltjb = luatexja.base

local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']

function cid(key)
   local curjfnt = fonts.ids[tex.attribute[attr_curjfnt]]
   if curjfnt.cidinfo.ordering ~= "Japan1" then
      ltjb.package_error('luatexja-otf',
                         'Current Japanese font "'..curjfnt.psname..'" is not a CID-Keyed font (Adobe-Japan1)', 
                         'Select a CID-Keyed font using \jfont.')
      return
   end
   local char = curjfnt.unicodes['Japan1.'..tostring(key)]
   if not char then
      ltjb.package_error('luatexja-otf',
                         'Current Japanese font "'..curjfnt.psname..'" does not include the specified CID character ('..tostring(key)..')', 
                         'Use a font including the specified CID character.')
      return
   end
   tex.print(char)
end

-------------------- all done
-- EOF
