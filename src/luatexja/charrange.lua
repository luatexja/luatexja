--
-- luatexja/charrange.lua
--
luatexbase.provides_module({
  name = 'luatexja.charrange',
  date = '2011/04/01',
  version = '0.1',
  description = 'Handling the range of Japanese characters',
})
module('luatexja.charrange', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

local floor = math.floor
local has_attr = node.has_attribute

-- jcr_table_main[chr_code] = index
-- index : internal 0, 1, 2, ..., 216               0: 'other'
--         external    1  2       216, (out of range): 'other'

-- initialize 
local jcr_table_main = {}
local jcr_cjk = 0; local jcr_noncjk = 1; local ucs_out = 0x110000

for i=0x80 ,0xFF      do jcr_table_main[i]=1 end
for i=0x100,ucs_out-1 do jcr_table_main[i]=0 end

-- EXT: add characters to a range
function add_char_range(b,e,ind) -- ind: external range number
   if not ind or ind<0 or ind>216 then 
      tex.print(luatexbase.catcodetables['latex-atletter'], "\\ltj@PackageError{luatexja}{invalid character range number (" .. ind ..
		")}{A character range number should be in the range 1..216, " ..
                "ignored.}{}"); return
   elseif b<0x80 or e>=ucs_out or b>e then
      tex.print(luatexbase.catcodetables['latex-atletter'], "\\ltj@PackageError{luatexja}{bad character range ("
		.. b .. ".." .. e .. ")}" .. 
		"{A character range must be a subset of [0x80, 0x10ffff].}{}")
   end 
   for i=math.max(0x80,b),math.min(ucs_out-1,e) do
      jcr_table_main[i]=ind
   end
end

function char_to_range(c) -- return the (external) range number
   if c<0x80 then return -1
   else 
      local i = jcr_table_main[c] or 0
      if i==0 then return 217 else return i end
   end
end

function get_range_setting(i) -- i: internal range number
   return floor(tex.getattribute(
			luatexbase.attributes['ltj@kcat'..floor(i/31)])
		     /math.pow(2, i%31))%2
end

--  glyph_node p は和文文字か？
function is_ucs_in_japanese_char(p)
   local c = p.char
   if c<0x80 then return false 
   else 
      local i=jcr_table_main[c] 
      return (floor(
		 has_attr(p, luatexbase.attributes['ltj@kcat'..floor(i/31)])
		 /math.pow(2, i%31))%2 ~= jcr_noncjk) 
   end
end

-- EXT
function toggle_char_range(g, i) -- i: external range number
   if i==0 then return 
   else
      local kc
      if i>0 then kc=0 else kc=1; i=-i end
      if i>216 then i=0 end
      local attr = luatexbase.attributes['ltj@kcat'..floor(i/31)]
      local a = tex.getattribute(attr)
      local k = math.pow(2, i%31)
      tex.setattribute(g,attr,(floor(a/k/2)*2+kc)*k+a%k)
   end
end

-- EOF