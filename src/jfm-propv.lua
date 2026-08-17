local t = {
   dir = 'tate',
   zw = 1.0, zh = 1.0,

   [0] = {
      align = 'left', left = 0.0, down = 0.0,
      width = 'prop', height = 0.50, depth = 0.50, italic=0.0,
   }
}
local jf = luatexja.jfont.jfm_feature
if jf then
  t[0].down = tonumber(jf.down) or 0.0
  t[0].left = tonumber(jf.left) or 0.0
end

luatexja.jfont.define_jfm(t)

