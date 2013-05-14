--
-- luatexja/charrange.lua
--
luatexbase.provides_module({
  name = 'luatexja.charrange',
  date = '2012/10/21',
  description = 'Handling the range of Japanese characters',
})
module('luatexja.charrange', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

luatexja.load_module('base');      local ltjb = luatexja.base

ATTR_RANGE = 7
local floor = math.floor
local pow = math.pow
local has_attr = node.has_attribute
local kcat_attr_table = {}
local pow_table = {}
for i = 0, 31*ATTR_RANGE-1 do
   kcat_attr_table[i] = luatexbase.attributes['ltj@kcat'..floor(i/31)]
   pow_table[i] =  pow(2, i%31)
end
pow_table[31*ATTR_RANGE] = pow(2, 31)

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
   if not ind or ind<0 or ind>=7*ATTR_RANGE then -- 0 は error にしない（隠し）
      ltjb.package_error('luatexja',
			 "invalid character range number (" .. ind .. ")",
			 "A character range number should be in the range 1.."
                          .. 7+ATTR_RANGE-1 .. ",\n" ..
			  "ignored.")
      return
   elseif b<0x80 or e>=ucs_out then
      ltjb.package_warning('luatexja',
			 'bad character range ([' .. b .. ',' .. e .. ']). ' ..
			   'I take the intersection with [0x80, 0x10ffff].')
   elseif b>e then
      local j=b; e=b; b=j
   end
   for i=math.max(0x80,b),math.min(ucs_out-1,e) do
      jcr_table_main[i]=ind
   end
end

function char_to_range(c) -- return the (external) range number
   if not c or c<0 or c>0x10FFFF then
	 ltjb.package_error('luatexja',
			    'bad character code (' .. tostring(c) .. ')',
			    'A character number must be between 0 and 0x10ffff.\n' ..
			     'So I changed this one to zero.')
	 c=0
   elseif c<0x80 then return -1
   else return  jcr_table_main[c] or 0 end
end

function get_range_setting(i) -- i: internal range number
   return floor(tex.getattribute(kcat_attr_table[i])/pow_table[i])%2
end

--  glyph_node p は和文文字か？
function is_ucs_in_japanese_char(p)
   local c = p.char
   if c<0x80 then
      return false
   else
      local i=jcr_table_main[c]
      return (floor(
		 has_attr(p, kcat_attr_table[i])/pow_table[i])%2 ~= jcr_noncjk)
   end
end

-- EXT
function toggle_char_range(g, i) -- i: external range number
   if type(i)~='number' then
	      ltjb.package_error('luatexja',
				 "invalid character range number (" .. tostring(i).. ")",
				 "A character range number must be a number, ignored.")
   elseif i==0 then return
   else
      local kc
      if i>0 then kc=0 else kc=1; i=-i end
      if i>=7*ATTR_RANGE then i=0 end
      local attr = kcat_attr_table[i]
      local a = tex.getattribute(attr)
      tex.setattribute(g,attr,(floor(a/pow_table[i+1])*2+kc)*pow_table[i]+a%pow_table[i])
   end
end

-- EOF
