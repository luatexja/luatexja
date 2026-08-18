local t = {
   dir = 'yoko',
   zw = 1.0, zh = 1.0,

   [0] = {
      align = 'left', left = 0.0, down = 0.0,
      width = 'prop', height = 'prop', depth = 'prop', italic=0.0,
   }
 }
local jf = luatexja.jfont.jfm_feature
if jf then
  t[0].down = tonumber(jf.down)
end

luatexja.jfont.define_jfm(t)

