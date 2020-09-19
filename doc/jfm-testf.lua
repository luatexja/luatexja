local t = luatexja.jfont.jfm_feature
myjfm = t
local k = (type(t and t.kern)=='string') and tonumber(t.kern) or 0.0
local d = (type(t and t.down)=='string') and tonumber(t.down) or 0.0
local t2= {
   dir = 'yoko',
   zw = 1.0, zh = 1.0,
   [0] = {
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      kern = { [1] = k }
   },
   [1] = {
      chars = { '漢', '字', },
      align = 'left', left = 0.0, down = d,
      width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
      kern = { [0] = 0.5, [2] = 0.5, [1000] = 0.5 }
   },
   [2] = {
      chars = { 'イ' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      kern = { [1] = k }
   },
   [1000] = {
      chars = { 'boxbdd' },
   },
}
if t and t.hira then
    for i=0x3040,0x309F do 
        table.insert(t2[1].chars, i)
    end
end
luatexja.jfont.define_jfm   (t2)
