--
-- luatexja/charrange.lua
--
luatexbase.provides_module({
  name = 'luatexja.charrange',
  date = '2017/05/05',
  description = 'Handling the range of Japanese characters',
})
module('luatexja.charrange', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

luatexja.load_module('base');      local ltjb = luatexja.base

local getchar = node.direct.getchar
local has_attr = node.direct.has_attribute
local has_attr_node = node.has_attribute
local tex_getattr = tex.getattribute

ATTR_RANGE = 7
local jcr_cjk, jcr_noncjk = 0, 1
local floor = math.floor
local pow = math.pow
local kcat_attr_table = {}
local pow_table = {}
local fn_table = {} -- used in is_ucs_in_japanese_char_direct
local nfn_table = {} -- used in is_ucs_in_japanese_char_node
for i = 0, 31*ATTR_RANGE-1 do
   local ka, pw = luatexbase.attributes['ltj@kcat'..floor(i/31)], 1/pow(2, i%31)
   local jcr_noncjk = jcr_noncjk
   kcat_attr_table[i], pow_table[i] = ka, pow(2, i%31)
   fn_table[i] = function(p) return floor(has_attr(p, ka)*pw)%2 ~= jcr_noncjk end
   nfn_table[i] = function(p) return floor(has_attr_node(p, ka)*pw)%2 ~= jcr_noncjk end
end
fn_table[-1] = function() return false end -- for char --U+007F
nfn_table[-1] = function() return false end -- for char --U+007F
pow_table[31*ATTR_RANGE] = pow(2, 31)

-- jcr_table_main[chr_code] = index
-- index : internal 0,   1, 2, ..., 216               0: 'other'
--         external 217, 1  2       216, 217 and (out of range): 'other'

-- initialize
jcr_table_main = {}
local jcr_table_main = jcr_table_main
local ucs_out = 0x110000

for i=0x0 ,0x7F       do jcr_table_main[i]=-1 end
for i=0x80 ,0xFF      do jcr_table_main[i]=1 end
for i=0x100,ucs_out-1 do jcr_table_main[i]=0 end

-- EXT: add characters to a range
function add_char_range(b,e,ind) -- ind: external range number
   if not ind or ind<0 or ind>31*ATTR_RANGE then -- 0 はエラーにしない（隠し）
      ltjb.package_error('luatexja',
			 "invalid character range number (" .. ind .. ")",
			 "A character range number should be in the range 1.."
                          .. 31*ATTR_RANGE .. ",\n" ..
			  "ignored.")
      return
   elseif b<0x80 or e>=ucs_out then
      ltjb.package_warning('luatexja',
			 'bad character range ([' .. b .. ',' .. e .. ']). ' ..
			   'I take the intersection with [0x80, 0x10ffff].')
   elseif b>e then
      local j=b; e=b; b=j
   end
   if ind == 31*ATTR_RANGE then ind=0 end
   for i=math.max(0x80,b),math.min(ucs_out-1,e) do
      jcr_table_main[i]=ind
   end
end

function char_to_range(c) -- return the external range number
   local r = jcr_table_main[ltjb.in_unicode(c, false)] or 217
   return (r~=0) and r or 217
end

function get_range_setting(i) -- i: internal range number
   return floor(tex_getattr(kcat_attr_table[i])/pow_table[i])%2
end

--  glyph_node p は和文文字か？
function is_ucs_in_japanese_char_node(p)
   return nfn_table[jcr_table_main[c or p.char]](p)
end
is_ucs_in_japanese_char = is_ucs_in_japanese_char_node
-- only ltj-otf.lua uses this version

function is_ucs_in_japanese_char_direct(p ,c)
   return fn_table[jcr_table_main[c or getchar(p)]](p)
end

function is_japanese_char_curlist(c) -- assume that c>=0x80
   return get_range_setting(jcr_table_main[c])~= jcr_noncjk
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
      local a = tex_getattr(attr)
      tex.setattribute(g, attr,
		       (floor(a/pow_table[i+1])*2+kc)*pow_table[i]+a%pow_table[i])
   end
end

-- EOF
