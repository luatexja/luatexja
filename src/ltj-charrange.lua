--
-- ltj-charrange.lua
--
luatexbase.provides_module({
  name = 'luatexja.charrange',
  date = '2022-08-19',
  description = 'Handling the range of Japanese characters',
})
luatexja.charrange = {}
luatexja.load_module 'base';      local ltjb = luatexja.base

local getchar = node.direct.getchar
local get_attr = node.direct.get_attribute
local get_attr_node = node.get_attribute
local tex_getattr = tex.getattribute

local UNSET = -0x7FFFFFFF
local ATTR_RANGE = 7
luatexja.charrange.ATTR_RANGE = ATTR_RANGE
local jcr_cjk, jcr_noncjk = 0, 1
local floor = math.floor
local kcat_attr_table = {}
local pow_table = {}
local fn_table = {} -- used in is_ucs_in_japanese_char_direct
local nfn_table = {} -- used in is_ucs_in_japanese_char_node
do
   local ka = luatexbase.attributes['ltj@kcat0']
   for i = 0, 30 do
      local pw = 2^i; kcat_attr_table[i], pow_table[i] = ka, pw
      fn_table[i] = function(p) return get_attr(p, ka)&pw==0 end
      nfn_table[i] = function(p) return get_attr_node(p, ka)&pw==0 end
   end
end
for i = 31, 31*ATTR_RANGE-1 do
   local ka, pw = luatexbase.attributes['ltj@kcat'..floor(i/31)], 2^(i%31)
   kcat_attr_table[i], pow_table[i] = ka, pw
   fn_table[i] = function(p) return (get_attr(p, ka) or 0)&pw==0 end
   nfn_table[i] = function(p) return (get_attr_node(p, ka) or 0)&pw==0 end
end
fn_table[-1] = function() return false end -- for char --U+007F
nfn_table[-1] = function() return false end -- for char --U+007F

-- jcr_table_main[chr_code] = index
-- index : internal 0,   1, 2, ..., 216               0: 'other'
--         external 217, 1  2       216, 217 and (out of range): 'other'

-- initialize
local jcr_table_main = {}
local ucs_out = 0x110000

for i=0x0 ,0x7F       do jcr_table_main[i]=-1 end
for i=0x80 ,0xFF      do jcr_table_main[i]=1 end
for i=0x100,ucs_out-1 do jcr_table_main[i]=0 end

-- EXT: add characters to a range
function luatexja.charrange.add_char_range(b,e,ind) -- ind: external range number
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
   elseif b>e then b, e = e, b end
   if ind == 31*ATTR_RANGE then ind=0 end
   for i=math.max(0x80,b),math.min(ucs_out-1,e) do
      jcr_table_main[i]=ind
   end
end

function luatexja.charrange.char_to_range(c) -- return the external range number
   local r = jcr_table_main[ltjb.in_unicode(c, false)] or 217
   return (r~=0) and r or 217
end

local function get_range_setting(i) -- i: internal range number
   local a = tex_getattr(kcat_attr_table[i])
   return (a==UNSET and 0 or a)&pow_table[i]
end

--  glyph_node p は和文文字か？
function luatexja.charrange.is_ucs_in_japanese_char(p)
   return nfn_table[jcr_table_main[c or p.char]](p)
end

function luatexja.charrange.is_ucs_in_japanese_char_direct(p ,c)
   return fn_table[jcr_table_main[c or getchar(p)]](p)
end

function luatexja.charrange.is_japanese_char_curlist(c) -- assume that c>=0x80
   return get_range_setting(jcr_table_main[c])==0
end

-- EXT
function luatexja.charrange.toggle_char_range(g, i) -- i: external range number
   if type(i)~='number' then
      ltjb.package_error('luatexja',
                         "invalid character range number (" .. tostring(i).. ")",
                         "A character range number must be a number, ignored.")
   elseif i==0 then return
   else
      local kc
      if i>0 then kc=0 else kc=1; i=-i end; if i>=31*ATTR_RANGE then i=0 end
      local attr, p = kcat_attr_table[i], pow_table[i]
      local a = tex_getattr(attr); if a==UNSET then a=0 end
      a = (a&~p)+kc*p; if a==0 and i>30 then a=UNSET end
      tex.setattribute(g, attr, a)
   end
end

luatexja.charrange.get_range_setting=get_range_setting

-- EOF
