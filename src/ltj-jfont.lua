--
-- luatexja/jfont.lua
--
luatexbase.provides_module({
  name = 'luatexja.jfont',
  date = '2011/06/27',
  version = '0.1',
  description = 'Loader for Japanese fonts',
})
module('luatexja.jfont', package.seeall)

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('charrange'); local ltjc = luatexja.charrange

local node_new = node.new
local has_attr = node.has_attribute
local round = tex.round

local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local id_glyph = node.id('glyph')
local id_kern = node.id('kern')
local cat_lp = luatexbase.catcodetables['latex-package']
local ITALIC = 1
------------------------------------------------------------------------
-- LOADING JFM
------------------------------------------------------------------------

metrics={} -- this table stores all metric informations
font_metric_table={} -- [font number] -> jfm_name, jfm_var, size

luatexbase.create_callback("luatexja.load_jfm", "data", function (ft, jn) return ft end)

local jfm_file_name, jfm_var
local defjfm_res

function define_jfm(t)
   local real_char -- Does current character class have the 'real' character?
   if t.dir~='yoko' then
      defjfm_res= nil; return
   elseif type(t.zw)~='number' or type(t.zh)~='number' then 
      defjfm_res= nil; return
   end
   t.char_type = {}; t.chars = {}
   for i,v in pairs(t) do
      if type(i) == 'number' then -- char_type
	 if not v.chars then
	    if i ~= 0 then defjfm_res= nil; return  end
	    real_char = true
	 else
	    real_char = false
	    for j,w in pairs(v.chars) do
	       if w == 'lineend' then
		  if #v.chars ~= 1 then defjfm_res= nil; return end
	       elseif type(w) == 'number' then
		  real_char = true;
	       elseif type(w) == 'string' and utf.len(w)==1 then
		  real_char = true; w = utf.byte(w)
	       end
	       if not t.chars[w] then
		  t.chars[w] = i
	       else 
		  defjfm_res= nil; return
	       end
	    end
	    if real_char then
	       if not (type(v.width)=='number' or v.width~='prop') then
		  defjfm_res= nil; return
	       else
		  if type(v.height)~='number' then
		     v.height = 0.0
		  end
		  if type(v.depth)~='number' then
		     v.depth = 0.0
		  end
		  if type(v.italic)~='number' then 
		     v.italic = 0.0
		  end
		  if type(v.left)~='number' then 
		     v.left = 0.0
		  end
		  if type(v.down)~='number' then 
		     v.down = 0.0
		  end
		  if type(v.align)=='nil' then
		     v.align = 'left'
		  end
	       end
	    end
	    v.chars = nil
	 end
	 if v.kern and v.glue then
	    for j,w in pairs(v.glue) do
	       if v.kern[j] then defjfm_res= nil; return end
	    end
	 end
	 t.char_type[i] = v
	 t[i] = nil
      end
   end
   t = luatexbase.call_callback("luatexja.load_jfm", t, jfm_file_name)
   t.size_cache = {}
   defjfm_res = t
end

local function mult_table(old,scale) -- modified from table.fastcopy
    if old then
       local new = { }
       for k,v in next, old do
	  if type(v) == "table" then
	     new[k] = mult_table(v,scale)
	  elseif type(v) == "number" then
	     new[k] = round(v*scale)
	  else
	     new[k] = v
	  end
       end
       return new
    else return nil end
end

local function update_jfm_cache(j,sz)
   if metrics[j].size_cache[sz] then return end
   metrics[j].size_cache[sz] = {}
   metrics[j].size_cache[sz].char_type = mult_table(metrics[j].char_type, sz)
   metrics[j].size_cache[sz].kanjijskip = mult_table(metrics[j].kanjiskip, sz)
   metrics[j].size_cache[sz].xkanjiskip = mult_table(metrics[j].xkanjiskip,sz)
   metrics[j].size_cache[sz].zw = round(metrics[j].zw*sz)
   metrics[j].size_cache[sz].zh = round(metrics[j].zh*sz)
end

luatexbase.create_callback("luatexja.find_char_class", "data", 
			   function (arg, fmtable, char)
			      return 0
			   end)

function find_char_class(c,m)
-- c: character code, m: index in font_metric table
   if not metrics[m.jfm] then return 0 end
   return metrics[m.jfm].chars[c] or 
      luatexbase.call_callback("luatexja.find_char_class", 0, m, c)
end

local function load_jfont_metric()
   if jfm_file_name=='' then 
      ltjb.package_error('luatexja',
			 'no JFM specified',
			 'To load and define a Japanese font, a JFM must be specified.'..
			  "The JFM 'ujis' will be  used for now.")
      jfm_file_name='ujis'
   end
   for j,v in ipairs(metrics) do 
      if v.name==jfm_file_name then return j end
   end
   luatexja.load_lua('jfm-' .. jfm_file_name .. '.lua')
   if defjfm_res then
      defjfm_res.name = jfm_file_name
      table.insert(metrics, defjfm_res)
      return #metrics
   else 
      return nil
   end
end


------------------------------------------------------------------------
-- LOADING JAPANESE FONTS
------------------------------------------------------------------------
local cstemp

-- EXT
function jfontdefX(g)
  local t = token.get_next()
  cstemp=token.csname_name(t)
  if g then luatexja.is_global = '\\global' else luatexja.is_global = '' end
  tex.sprint(cat_lp, '\\expandafter\\font\\csname ' .. cstemp .. '\\endcsname')
end

luatexbase.create_callback("luatexja.define_jfont", "data", function (ft, fn) return ft end)

-- EXT
function jfontdefY() -- for horizontal font
   local j = load_jfont_metric()
   local fn = font.id(cstemp)
   local f = font.fonts[fn]
   if not j then 
      ltjb.package_error('luatexja',
			 "bad JFM `" .. jfm_file_name .. "'",
			 'The JFM file you specified is not valid JFM file.\n'..
			    'So defining Japanese font is cancelled.')
      tex.sprint(cat_lp, luatexja.is_global .. '\\expandafter\\let\\csname ' ..cstemp 
             .. '\\endcsname=\\relax')
     return 
   end
   update_jfm_cache(j, f.size)
   local fmtable = { jfm = j, size = f.size, var = jfm_var }
   fmtable = luatexbase.call_callback("luatexja.define_jfont", fmtable, fn)
   font_metric_table[fn]=fmtable
   tex.sprint(cat_lp, luatexja.is_global .. '\\protected\\expandafter\\def\\csname ' 
          .. cstemp  .. '\\endcsname{\\ltj@curjfnt=' .. fn .. '\\relax}')
end

-- zw, zh
function load_zw()
   local a = font_metric_table[tex.attribute[attr_curjfnt]]
   if a then
      tex.setdimen('ltj@zw', metrics[a.jfm].size_cache[a.size].zw)
   else 
      tex.setdimen('ltj@zw',0)
   end
end

function load_zh()
   local a = font_metric_table[tex.attribute[attr_curjfnt]]
   if a then
      tex.setdimen('ltj@zh', metrics[a.jfm].size_cache[a.size].zh)
   else 
      tex.setdimen('ltj@zh',0)
   end
end

-- extract jfm_file_name and jfm_var
local function extract_metric(name)
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
   extract_metric(name)
   -- In the present imple., we don't remove "jfm=..." from name.
   return ljft_dr_orig(name, size, id)
end

------------------------------------------------------------------------
-- MISC
------------------------------------------------------------------------

-- EXT: italic correction
function append_italic()
   local p = tex.nest[tex.nest.ptr].tail
   if p and p.id==id_glyph then
      local f = p.font
      local g = node_new(id_kern)
      g.subtype = 1; node.set_attribute(g, attr_icflag, ITALIC)
      if ltjc.is_ucs_in_japanese_char(p) then
	 f = has_attr(p, attr_curjfnt)
	 local j = font_metric_table[f]
	 local c = find_char_class(p.char, j)
	 g.kern = metrics[j.jfm].size_cache[j.size].char_type[c].italic
      else
	 g.kern = font.fonts[f].characters[p.char].italic
      end
      node.write(g)
      tex.attribute[attr_icflag] = -(0x7FFFFFFF)
   end
end
