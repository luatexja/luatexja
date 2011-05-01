local node_new = node.new
local has_attr = node.has_attribute
local floor = math.floor
local round = tex.round

local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local id_glyph = node.id('glyph')
local id_kern = node.id('kern')

------------------------------------------------------------------------
-- LOADING JFM (prefix: ljfm)
------------------------------------------------------------------------

ltj.metrics={} -- this table stores all metric informations
ltj.font_metric_table={} -- [font number] -> jfm_name, jfm_var, size

jfm={}; jfm.char_type={}; jfm.glue={}; jfm.kern={}; jfm.chars = {}

local ljfm_jfm_cons
local jfm_file_name, jfm_var

function jfm.define_char_type(t,lt) 
   if not jfm.char_type[t] then jfm.char_type[t]={} end
   jfm.char_type[t].chars=lt 
   for i,v in pairs(lt) do
      if v == 'linebdd' then
	 if #lt ~= 1 then ljfm_jfm_cons = false; return end
      elseif not jfm.chars[v] then 
	 jfm.chars[v] = t 
      else 
	 ljfm_jfm_cons = false ; return
      end
   end
end
function jfm.define_type_dim(t,l,x,w,h,d,i)
   if not jfm.char_type[t] then jfm.char_type[t]={} end
   jfm.char_type[t].width=w; jfm.char_type[t].height=h;
   jfm.char_type[t].depth=d; jfm.char_type[t].italic=i; 
   jfm.char_type[t].left=l; jfm.char_type[t].down=x
end
function jfm.define_glue(b,a,w,st,sh)
   local j=b*0x800+a
   if not jfm.glue[j] then jfm.glue[j]={} end
   jfm.glue[j][0]=w; jfm.glue[j][1]=st; 
   jfm.glue[j][2]=sh
end
function jfm.define_kern(b,a,w)
   local j=b*0x800+a
   if not jfm.kern[j] then jfm.kern[j]=w end
end

-- return nil iff ltj.metrics[ind] is a bad metric
local function ljfm_consistency_check(ind)
   local t = ltj.metrics[ind]
   local r = nil
   if ljfm_jfm_cons then r = ind end
   if t.dir~='yoko' then -- TODO: tate?
      r=nil
   elseif type(t.zw)~='number' or type(t.zh)~='number' then 
      r=nil -- .zw, .zh must be present
   end
   if not r then ltj.metrics[ind] = nil end
   return r
end

local function ljfm_find_char_class(c,m)
-- c: character code, m
   if not ltj.metrics[m] then return 0 end
   return ltj.metrics[m].chars[c] or 0
end
ltj.int_find_char_class = ljfm_find_char_class

local function ljfm_load_jfont_metric()
   if jfm_file_name=='' then 
      ltj.error('no JFM specified', 
		{[1]='To load and define a Japanese font, the name of JFM must be specified.',
		 [2]="The JFM 'ujis' will be  used for now."})
      jfm_file_name='ujis'
   end
   local name=jfm_file_name .. ':' .. jfm_var
   local i = nil
   for j,v in ipairs(ltj.metrics) do 
      if v.name==name then i=j; break end
   end
   local t = {}
   if i then  return i end
   jfm.char_type={}; jfm.glue={}; jfm.kern={}; jfm.chars = {}
   ljfm_jfm_cons = true
   ltj.loadlua('jfm-' .. jfm_file_name .. '.lua')
   t.name=name
   t.dir=jfm.dir; t.zw=jfm.zw; t.zh=jfm.zh
   t.char_type=jfm.char_type; t.chars=jfm.chars
   t.glue=jfm.glue; t.kern=jfm.kern
   table.insert(ltj.metrics,t)
   return ljfm_consistency_check(#ltj.metrics)
end


------------------------------------------------------------------------
-- LOADING JAPANESE FONTS (prefix: ljft)
------------------------------------------------------------------------
local cstemp

-- EXT
function ltj.ext_jfontdefX(g)
  local t = token.get_next()
  cstemp=token.csname_name(t)
  if g then ltj.is_global = '\\global' else ltj.is_global = '' end
  tex.sprint('\\expandafter\\font\\csname ' .. cstemp .. '\\endcsname')
end

-- EXT
function ltj.ext_jfontdefY() -- for horizontal font
   local j = ljfm_load_jfont_metric()
   local fn = font.id(cstemp)
   local f = font.fonts[fn]
   if not j then 
     ltj.error("bad JFM '" .. jfm_file_name .. "'",
               {[1]='The JFM file you specified is not valid JFM file.',
                [2]='Defining Japanese font is cancelled.'})
     tex.sprint(ltj.is_global .. '\\expandafter\\let\\csname '
		.. cstemp .. '\\endcsname=\\relax')
     return 
   end
   ltj.font_metric_table[fn]={}
   ltj.font_metric_table[fn].jfm=j; ltj.font_metric_table[fn].size=f.size
   tex.sprint(ltj.is_global .. '\\protected\\expandafter\\def\\csname '
              .. cstemp .. '\\endcsname'
              .. '{\\csname ltj@curjfnt\\endcsname=' .. fn
              .. ' \\zw=' .. tex.round(f.size*ltj.metrics[j].zw) .. 'sp'
              .. '\\zh=' .. tex.round(f.size*ltj.metrics[j].zh) .. 'sp\\relax}')
end

-- extract jfm_file_name and jfm_var
local function ljft_extract_metric(name)
   local basename=name
   local tmp = utf.sub(basename, 1, 5)
   jfm_file_name = ''; jfm_var = ''
   if tmp == 'file:' or tmp == 'name:' or tmp == 'psft:' then
      basename = utf.sub(basename, 6)
   end
   local p = utf.find(basename, ":")
   if p then 
      basename = utf.sub(basename, p+1)
   else return 
   end
   -- now basename contains 'features' only.
   p=1
   while p do
      local q = utf.find(basename, ";", p+1) or utf.len(basename)+1
      if utf.sub(basename, p, p+3)=='jfm=' and q>p+4 then
	 jfm_file_name = utf.sub(basename, p+4, q-1)
      elseif utf.sub(basename, p, p+6)=='jfmvar=' and q>p+6 then
	 jfm_var = utf.sub(basename, p+7, q-1)
      end
      if utf.len(basename)+1==q then p = nil else p = q + 1 end
   end
   return
end

-- replace fonts.define.read()
local ljft_dr_orig = fonts.define.read
function fonts.define.read(name, size, id)
   ljft_extract_metric(name)
   -- In the present imple., we don't remove "jfm=..." from name.
   return ljft_dr_orig(name, size, id)
end

------------------------------------------------------------------------
-- MANAGING THE RANGE OF JAPANESE CHARACTERS (prefix: rgjc)
------------------------------------------------------------------------
-- jcr_table_main[chr_code] = index
-- index : internal 0, 1, 2, ..., 216               0: 'other'
--         external    1  2       216, (out of range): 'other'

-- initialize 
local jcr_table_main = {}
local jcr_cjk = 0; local jcr_noncjk = 1; local ucs_out = 0x110000

for i=0x80 ,0xFF      do jcr_table_main[i]=1 end
for i=0x100,ucs_out-1 do jcr_table_main[i]=0 end

-- EXT: add characters to a range
function ltj.ext_add_char_range(b,e,ind) -- ind: external range number
   if ind<0 or ind>216 then 
      ltj.error('Invalid range number (' .. ind ..
		'), should be in the range 1..216.',
	     {}); return
   end
   for i=math.max(0x80,b),math.min(ucs_out-1,e) do
      jcr_table_main[i]=ind
   end
end

local function rgjc_char_to_range(c) -- return the (external) range number
   if c<0x80 or c>=ucs_out then return -1
   else 
      local i = jcr_table_main[c] or 0
      if i==0 then return 217 else return i end
   end
end

local function rgjc_get_range_setting(i) -- i: internal range number
   return floor(tex.getattribute(
			luatexbase.attributes['ltj@kcat'..floor(i/31)])
		     /math.pow(2, i%31))%2
end
ltj.int_get_range_setting = rgjc_get_range_setting
ltj.int_char_to_range = rgjc_char_to_range

--  glyph_node p は和文文字か？
local function rgjc_is_ucs_in_japanese_char(p)
   local c = p.char
   if c<0x80 then return false 
   else 
      local i=jcr_table_main[c] 
      return (floor(
		 has_attr(p, luatexbase.attributes['ltj@kcat'..floor(i/31)])
		 /math.pow(2, i%31))%2 ~= jcr_noncjk) 
   end
end
ltj.int_is_ucs_in_japanese_char = rgjc_is_ucs_in_japanese_char

-- EXT
function ltj.ext_toggle_char_range(g, i) -- i: external range number
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

------------------------------------------------------------------------
-- MISC
------------------------------------------------------------------------

-- EXT: italic correction
function ltj.ext_append_italic()
   local p = tex.nest[tex.nest.ptr].tail
   if p and p.id==id_glyph then
      local f = p.font
      local g = node_new(id_kern)
      g.subtype = 1; node.set_attribute(g, attr_icflag, 1)
      if rgjc_is_ucs_in_japanese_char(p) then
	 f = has_attr(p, attr_curjfnt)
	 print(f, p.char)
	 local j = ltj.font_metric_table[f]
	 local c = ljfm_find_char_class(p.char, j.jfm)
	 g.kern = round(j.size * ltj.metrics[j.jfm].char_type[c].italic)
      else
	 g.kern = font.fonts[f].characters[p.char].italic
      end
      node.write(g)
   end
end