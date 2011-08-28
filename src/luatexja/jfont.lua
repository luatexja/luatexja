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

require('luatexja.base');      local ltjb = luatexja.base
require('luatexja.charrange'); local ltjc = luatexja.charrange

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
	       elseif type(v.height)~='number' or type(v.depth)~='number' then
		  defjfm_res= nil; return
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
   defjfm_res= t
end

function find_char_class(c,m)
-- c: character code, m
   if not metrics[m] then return 0 end
   return metrics[m].chars[c] or 0
end

local function load_jfont_metric()
   if jfm_file_name=='' then 
      ltjb.package_error('luatexja',
			 'no JFM specified',
			 {'To load and define a Japanese font, a JFM must be specified.',
			  "The JFM 'ujis' will be  used for now."})
      jfm_file_name='ujis'
   end
   for j,v in ipairs(metrics) do 
      if v.name==jfm_file_name then return j end
   end
   ltj.loadlua('jfm-' .. jfm_file_name .. '.lua')
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
  if g then ltj.is_global = '\\global' else ltj.is_global = '' end
  tex.sprint(cat_lp, '\\expandafter\\font\\csname ' .. cstemp .. '\\endcsname')
end

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
      tex.sprint(cat_lp, ltj.is_global .. '\\expandafter\\let\\csname ' ..cstemp 
             .. '\\endcsname=\\relax')
     return 
   end
   font_metric_table[fn]={}
   font_metric_table[fn].jfm=j
   font_metric_table[fn].size=f.size
   font_metric_table[fn].var=jfm_var
   tex.sprint(cat_lp, ltj.is_global .. '\\protected\\expandafter\\def\\csname ' 
          .. cstemp  .. '\\endcsname{\\ltj@curjfnt=' .. fn .. '\\relax}')
end

-- zw, zh
function load_zw()
   local a = font_metric_table[tex.attribute[attr_curjfnt]]
   if a then
      tex.setdimen('ltj@zw', round(a.size*metrics[a.jfm].zw))
   else 
      tex.setdimen('ltj@zw',0)
   end
end

function load_zh()
   local a = font_metric_table[tex.attribute[attr_curjfnt]]
   if a then
      tex.setdimen('ltj@zh', round(a.size*metrics[a.jfm].zh))
   else 
      tex.setdimen('ltj@zh', round(a.size*metrics[a.jfm].zh))
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
	 local c = find_char_class(p.char, j.jfm)
	 g.kern = round(j.size * metrics[j.jfm].char_type[c].italic)
      else
	 g.kern = font.fonts[f].characters[p.char].italic
      end
      node.write(g)
   end
end
