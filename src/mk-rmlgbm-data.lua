#!texlua

kpse.set_program_name('kpsewhich')
require('lualibs-table')

fontdata = require('temp-kozminpr6n-regular')
fontdata.subfonts = nil
fontdata.metadata = {}
fontdata.pfminfo = {}
fontdata.luatex.filename = 'dummy.otf'
fontdata.size = nil
fontdata.time = nil

-- for luaotfload
fontdata.pfminfo.os2_capheight = 0

for k1, v2 in pairs(fontdata.glyphs) do
   for k2, v2 in pairs(fontdata.glyphs[k1]) do
      if k2 ~= 'name' and k2 ~= 'slookups' and k2 ~= 'vwidth' and k2 ~= 'width' then
         fontdata.glyphs[k1][k2] = nil
      end
      if k2 == 'slookups' then
         for k3, v3 in pairs(fontdata.glyphs[k1][k2]) do
            if string.sub(k3, 1, 2) == 'sp' then
               fontdata.glyphs[k1][k2][k3] = nil
            end
         end
      end
   end
end

table.tofile('luatexja-rmlgbm-data.lua', fontdata, 'return', false, true, false)
