local node_new = node.new
local has_attr = node.has_attribute
local round = tex.round

local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local id_glyph = node.id('glyph')
local id_kern = node.id('kern')

local ITALIC = 1
------------------------------------------------------------------------
-- LOADING JFM (prefix: ljfm)
------------------------------------------------------------------------

ltj.metrics={} -- this table stores all metric informations
ltj.font_metric_table={} -- [font number] -> jfm_name, jfm_var, size

local jfm_file_name, jfm_var
local defjfm_res

function ltj.define_jfm(t)
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
   for j,v in ipairs(ltj.metrics) do 
      if v.name==jfm_file_name then return j end
   end
   ltj.loadlua('jfm-' .. jfm_file_name .. '.lua')
   if defjfm_res then
      defjfm_res.name = jfm_file_name
      table.insert(ltj.metrics,defjfm_res)
      return #ltj.metrics
   else 
      return nil
   end
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
   ltj.font_metric_table[fn].jfm=j
   ltj.font_metric_table[fn].size=f.size
   ltj.font_metric_table[fn].var=jfm_var
   tex.sprint(ltj.is_global .. '\\protected\\expandafter\\def\\csname '
              .. cstemp .. '\\endcsname'
              .. '{\\csname ltj@curjfnt\\endcsname=' .. fn
              .. ' \\zw=' .. round(f.size*ltj.metrics[j].zw) .. 'sp'
              .. '\\zh=' .. round(f.size*ltj.metrics[j].zh) .. 'sp\\relax}')
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
-- MISC
------------------------------------------------------------------------

-- EXT: italic correction
function ltj.ext_append_italic()
   local p = tex.nest[tex.nest.ptr].tail
   if p and p.id==id_glyph then
      local f = p.font
      local g = node_new(id_kern)
      g.subtype = 1; node.set_attribute(g, attr_icflag, ITALIC)
      if luatexja.charrange.is_ucs_in_japanese_char(p) then
	 f = has_attr(p, attr_curjfnt)
	 local j = ltj.font_metric_table[f]
	 local c = ljfm_find_char_class(p.char, j.jfm)
	 g.kern = round(j.size * ltj.metrics[j.jfm].char_type[c].italic)
      else
	 g.kern = font.fonts[f].characters[p.char].italic
      end
      node.write(g)
   end
end
