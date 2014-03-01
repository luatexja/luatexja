--
-- luatexja/jfont.lua
--
luatexbase.provides_module({
  name = 'luatexja.jfont',
  date = '2014/02/01',
  description = 'Loader for Japanese fonts',
})
module('luatexja.jfont', package.seeall)

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('charrange'); local ltjc = luatexja.charrange

local mem_leak_glue, mem_leak_gs, mem_leak_kern = 0, 0, 0

local Dnode = node.direct or node

local setfield = (Dnode ~= node) and Dnode.setfield or function(n, i, c) n[i] = c end
local getid = (Dnode ~= node) and Dnode.getid or function(n) return n.id end
local getfont = (Dnode ~= node) and Dnode.getfont or function(n) return n.font end
local getchar = (Dnode ~= node) and Dnode.getchar or function(n) return n.char end

local nullfunc = function(n) return n end
local to_direct = (Dnode ~= node) and Dnode.todirect or nullfunc

local node_new = Dnode.new
local node_free = Dnode.free
local has_attr = Dnode.has_attribute
local set_attr = Dnode.set_attribute
local node_write = Dnode.write
local round = tex.round
local font_getfont = font.getfont

local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local id_glyph = node.id('glyph')
local id_kern = node.id('kern')
local id_glue_spec = node.id('glue_spec')
local id_glue = node.id('glue')
local cat_lp = luatexbase.catcodetables['latex-package']
local ITALIC       = luatexja.icflag_table.ITALIC
local FROM_JFM     = luatexja.icflag_table.FROM_JFM

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
	       if type(w) == 'number' then
		  real_char = true;
	       elseif type(w) == 'string' and utf.len(w)==1 then
		  real_char = true; w = utf.byte(w)
	       elseif type(w) == 'string' and utf.len(w)==2 and utf.sub(w,2) == '*' then
		  real_char = true; w = utf.byte(utf.sub(w,1,1))
                  if not t.chars[-w] then 
                     t.chars[-w] = i
                  else 
                     defjfm_res= nil; return
                  end
	       end
	       if not t.chars[w] then
		  t.chars[w] = i
	       else 
		  defjfm_res= nil; return
	       end
	    end
            if type(v.align)~='string' then 
               v.align = 'left' -- left
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
	       end
	    end
	    v.chars = nil
	 end
	 v.kern = v.kern or {}; v.glue = v.glue or {}
	 for j in pairs(v.glue) do
	    if v.kern[j] then defjfm_res= nil; return end
	 end
	 for j,x in pairs(v.kern) do
	    if type(x)=='number' then 
               v.kern[j] = {x, 0}
            elseif type(x)=='table' then 
               v.kern[j] = {x[1], x[2] or 0}
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

local update_jfm_cache
do
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
   
   update_jfm_cache = function (j,sz)
      if metrics[j].size_cache[sz] then return end
      local t = {}
      metrics[j].size_cache[sz] = t
      t.chars = metrics[j].chars
      t.char_type = mult_table(metrics[j].char_type, sz)
      for i,v in pairs(t.char_type) do
	 v.align = (v.align=='left') and 0 or 
	    ((v.align=='right') and 1 or 0.5)
	 if type(i) == 'number' then -- char_type
	    for k,w in pairs(v.glue) do
	       local h = node_new(id_glue_spec)
mem_leak_gs = mem_leak_gs+1
	       v[k] = {true, h, (w[5] and w[5]/sz or 0), FROM_JFM + (w[4] and w[4]/sz or 0)}
	       setfield(h, 'width', w[1])
	       setfield(h, 'stretch', w[2])
	       setfield(h, 'shrink', w[3])
	       setfield(h, 'stretch_order', 0)
	       setfield(h, 'shrink_order', 0)
	    end
	    for k,w in pairs(v.kern) do
	       local g = node_new(id_kern)
mem_leak_kern = mem_leak_kern +1
	       setfield(g, 'kern', w[1])
	       setfield(g, 'subtype', 1)
	       set_attr(g, attr_icflag, FROM_JFM)
	       v[k] = {false, g, w[2]/sz}
	    end
	 end
	 v.glue, v.kern = nil, nil
      end
      t.kanjiskip = mult_table(metrics[j].kanjiskip, sz)
      t.xkanjiskip = mult_table(metrics[j].xkanjiskip,sz)
      t.zw = round(metrics[j].zw*sz)
      t.zh = round(metrics[j].zh*sz)
   end
end

luatexbase.create_callback("luatexja.find_char_class", "data", 
			   function (arg, fmtable, char)
			      return 0
			   end)

function find_char_class(c,m)
-- c: character code, m: 
   if not m then return 0 end
   return m.chars[c] or 
      luatexbase.call_callback("luatexja.find_char_class", 0, m, c)
end


------------------------------------------------------------------------
-- LOADING JAPANESE FONTS
------------------------------------------------------------------------

do
   local cstemp
   local global_flag -- true if \globaljfont, false if \jfont
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

-- EXT
   function jfontdefX(g)
      local t = token.get_next()
      cstemp=token.csname_name(t)
      global_flag = g and '\\global' or ''
      tex.sprint(cat_lp, '\\expandafter\\font\\csname ' .. cstemp .. '\\endcsname')
   end
   
   luatexbase.create_callback("luatexja.define_jfont", "data", function (ft, fn) return ft end)

-- EXT
   function jfontdefY() -- for horizontal font
      local j = load_jfont_metric()
      local fn = font.id(cstemp)
      local f = font_getfont(fn)
      if not j then 
	 ltjb.package_error('luatexja',
			    "bad JFM `" .. jfm_file_name .. "'",
			    'The JFM file you specified is not valid JFM file.\n'..
			       'So defining Japanese font is cancelled.')
	 tex.sprint(cat_lp, global_flag .. '\\expandafter\\let\\csname ' ..cstemp 
		       .. '\\endcsname=\\relax')
	 return 
      end
      update_jfm_cache(j, f.size)
      --print('MEMORY LEAK (acc): ', mem_leak_glue, mem_leak_gs, mem_leak_kern)
      local sz = metrics[j].size_cache[f.size]
      local fmtable = { jfm = j, size = f.size, var = jfm_var, 
			zw = sz.zw, zh = sz.zh, 
			chars = sz.chars, char_type = sz.char_type,
			kanjiskip = sz.kanjiskip, xkanjiskip = sz.xkanjiskip, 
      }
      
      fmtable = luatexbase.call_callback("luatexja.define_jfont", fmtable, fn)
      font_metric_table[fn]=fmtable
      tex.sprint(cat_lp, global_flag .. '\\protected\\expandafter\\def\\csname ' 
		    .. cstemp  .. '\\endcsname{\\ltj@curjfnt=' .. fn .. '\\relax}')
   end
end

do
   -- PUBLIC function
   function get_zw() 
      local a = font_metric_table[tex.attribute[attr_curjfnt]]
      return a and a.zw or 0
   end
   function get_zh() 
      local a = font_metric_table[tex.attribute[attr_curjfnt]]
      return a and a.zw or 0
   end
end

do
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
   function font_callback(name, size, id, fallback)
      extract_metric(name)
      -- In the present imple., we don't remove "jfm=..." from name.
      return fallback(name, size, id)
   end
end

------------------------------------------------------------------------
-- LATEX INTERFACE
------------------------------------------------------------------------
do
   -- these function are called from ltj-latex.sty
   local kyenc_list, ktenc_list = {}, {}
   function add_kyenc_list(enc) kyenc_list[enc] = 'true ' end
   function add_ktenc_list(enc) ktenc_list[enc] = 'true ' end
   function is_kyenc(enc)
      tex.sprint(cat_lp, '\\let\\ifin@\\if' .. (kyenc_list[enc] or 'false '))
   end
   function is_kyenc(enc) 
      tex.sprint(cat_lp, '\\let\\ifin@\\if' .. (kyenc_list[enc] or 'false '))
   end
   function is_kenc(enc) 
      tex.sprint(cat_lp, '\\let\\ifin@\\if' 
		 .. (kyenc_list[enc] or ktenc_list[enc] or 'false '))
   end

   local kfam_list, Nkfam_list = {}, {}
   function add_kfam_list(enc, fam)
      if not kfam_list[enc] then kfam_list[enc] = {} end
      kfam_list[enc][fam] = 'true '
   end
   function add_Nkfam_list(enc, fam)
      if not Nkfam_list[enc] then Nkfam_list[enc] = {} end
      Nkfam_list[enc][fam] = 'true '
   end
   function is_kfam(enc, fam)
      tex.sprint(cat_lp, '\\let\\ifin@\\if' 
		 .. (kfam_list[enc] and kfam_list[enc][fam] or 'false ')) end
   function is_Nkfam(enc, fam)
      tex.sprint(cat_lp, '\\let\\ifin@\\if' 
		 .. (Nkfam_list[enc] and Nkfam_list[enc][fam] or 'false ')) end

   local ffam_list, Nffam_list = {}, {}
   function add_ffam_list(enc, fam)
      if not ffam_list[enc] then ffam_list[enc] = {} end
      ffam_list[enc][fam] = 'true '
   end
   function add_Nffam_list(enc, fam)
      if not Nffam_list[enc] then Nffam_list[enc] = {} end
      Nffam_list[enc][fam] = 'true '
   end
   function is_ffam(enc, fam)
      tex.sprint(cat_lp, '\\let\\ifin@\\if' 
		 .. (ffam_list[enc] and ffam_list[enc][fam] or 'false ')) end
   function is_Nffam(enc, fam)
      tex.sprint(cat_lp, '\\let\\ifin@\\if' 
		 .. (Nffam_list[enc] and Nffam_list[enc][fam] or 'false ')) end
end
------------------------------------------------------------------------
-- ALTERNATE FONTS
------------------------------------------------------------------------
alt_font_table = {}
local alt_font_table = alt_font_table
local attr_curaltfnt = {}
local ucs_out = 0x110000

------ for TeX interface
-- EXT
function set_alt_font(b,e,ind,bfnt)
   -- ind: 新フォント, bfnt: 基底フォント
   if b>e then b, e = e, b end
   if b*e<=0 then
      ltjb.package_error('luatexja',
			'bad character range ([' .. b .. ',' .. e .. ']). ' ..
			   'I take the intersection with [0x80, 0x10ffff].')
      b, e = math.max(0x80,b),math.min(ucs_out-1,e)
   elseif e<0 then -- b<e<0
      -- do nothing
   elseif b<0x80 or e>=ucs_out then
      ltjb.package_warning('luatexja',
			   'bad character range ([' .. b .. ',' .. e .. ']). ' ..
			      'I take the intersection with [0x80, 0x10ffff].')
      b, e = math.max(0x80,b), math.min(ucs_out-1,e)
   end
   if not alt_font_table[bfnt] then alt_font_table[bfnt]={} end
   local t = alt_font_table[bfnt]
   local ac = font_getfont(ind).characters
   if bfnt==ind then ind = nil end -- ind == bfnt の場合はテーブルから削除
   if e>=0 then -- character range
      for i=b, e do
	 if ac[i]then  t[i]=ind end
      end
   else
      b, e = -e, -b
      local tx = font_metric_table[bfnt].chars
      for i,v in pairs(tx) do
	 if b<=v and v<=e and ac[i] then t[i]=ind end
      end
   end
end

-- EXT
function clear_alt_font(bfnt)
   if alt_font_table[bfnt] then 
      local t = alt_font_table[bfnt]
      for i,_ in pairs(t) do t[i]=nil; end
   end
end

------ used in ltjp.suppress_hyphenate_ja callback
function replace_altfont(pf, pc)
   local a = alt_font_table[pf]
   return a and a[pc] or pf
end

------ for LaTeX interface

local alt_font_table_latex = {}

-- EXT
function clear_alt_font_latex(bbase)
   local t = alt_font_table_latex[bbase]
   if t then
      for j,v in pairs(t) do t[j] = nil end 
   end
end

-- EXT
function set_alt_font_latex(b,e,ind,bbase)
   -- ind: Alt font の enc/fam/ser/shape, bbase: 基底フォントの enc/fam/ser/shape
   if b>e then b, e = e, b end
   if b*e<=0 then
      ltjb.package_error('luatexja',
			'bad character range ([' .. b .. ',' .. e .. ']). ' ..
			   'I take the intersection with [0x80, 0x10ffff].')
      b, e = math.max(0x80,b),math.min(ucs_out-1,e)
   elseif e<0 then -- b<e<0
      -- do nothing
   elseif b<0x80 or e>=ucs_out then
      ltjb.package_warning('luatexja',
			   'bad character range ([' .. b .. ',' .. e .. ']). ' ..
			      'I take the intersection with [0x80, 0x10ffff].')
      b, e = math.max(0x80,b), math.min(ucs_out-1,e)
   end

   if not alt_font_table_latex[bbase] then alt_font_table_latex[bbase]={} end
   local t = alt_font_table_latex[bbase]
   if not t[ind] then t[ind] = {} end
   for i=b, e do
      for j,v in pairs(t) do
         if v[i] then -- remove old entry
            if j~=ind then v[i]=nil end; break
         end
      end
      t[ind][i]=true
   end
   -- remove the empty tables
   for j,v in pairs(t) do
      local flag_clear = true
      for k,_ in pairs(v) do flag_clear = false; break end
      if flag_clear then t[j]=nil end
   end
   if ind==bbase  then t[bbase] = nil end
end

-- ここから先は 新 \selectfont の内部でしか実行されない
do
   local alt_font_base, alt_font_base_num
   local aftl_base
   -- EXT
   function does_alt_set(bbase)
      aftl_base = alt_font_table_latex[bbase]
      tex.sprint(cat_lp, '\\if' .. (aftl_base and 'true' or 'false'))
   end
   -- EXT
   function print_aftl_address()
      tex.sprint(cat_lp, ';ltjaltfont' .. tostring(aftl_base):sub(8))
   end

-- EXT
   function output_alt_font_cmd(bbase)
      alt_font_base = bbase
      alt_font_base_num = tex.getattribute(attr_curjfnt)
      local t = alt_font_table[alt_font_base_num]
      if t then 
         for i,_ in pairs(t) do t[i]=nil end
      end
      t = alt_font_table_latex[bbase]
      if t then
         for i,_ in pairs(t) do
            tex.sprint(cat_lp, '\\ltj@pickup@altfont@aux{' .. i .. '}')
         end
      end
   end

-- EXT
   function pickup_alt_font_a(size_str)
      local t = alt_font_table_latex[alt_font_base]
      if t then
         for i,v in pairs(t) do
            tex.sprint(cat_lp, '\\expandafter\\ltj@pickup@altfont@copy'
                          .. '\\csname ' .. i .. '/' .. size_str .. '\\endcsname{' .. i .. '}')
         end
      end
   end 

   local function pickup_alt_font_class(class, afnt_num, afnt_chars)
      local t  = alt_font_table[alt_font_base_num] 
      local tx = font_metric_table[alt_font_base_num].chars
      for i,v in pairs(tx) do
         if v==class and afnt_chars[i] then t[i]=afnt_num end
      end
   end

-- EXT
   function pickup_alt_font_b(afnt_num, afnt_base)
      local t = alt_font_table[alt_font_base_num]
      local ac = font_getfont(afnt_num).characters
      if not t then t = {}; alt_font_table[alt_font_base_num] = t end
      for i,v in pairs(alt_font_table_latex[alt_font_base]) do
         if i == afnt_base then
            for j,_ in pairs(v) do
               if j>=0 then 
                  if ac[j] then t[j]=afnt_num end
               else  -- -n (n>=1) means that the character class n,
                     -- which is defined in the JFM 
                  pickup_alt_font_class(-j, afnt_num, ac) 
               end
            end
            return
         end
      end
   end

end


------------------------------------------------------------------------
-- MISC
------------------------------------------------------------------------

local is_ucs_in_japanese_char = ltjc.is_ucs_in_japanese_char_direct
-- EXT: italic correction
function append_italic()
   local p = to_direct(tex.nest[tex.nest.ptr].tail)
   if p and getid(p)==id_glyph then
      local f = getfont(p)
      local g = node_new(id_kern)
      setfield(g, 'subtype', 1)
      set_attr(g, attr_icflag, ITALIC)
      if is_ucs_in_japanese_char(p) then
	 f = has_attr(p, attr_curjfnt)
	 local j = font_metric_table[f]
	 setfield(g, 'kern', j.char_type[find_char_class(getchar(p), j)].italic)
      else
	 local h = font_getfont(f)
	 if h then
	    setfield(g, 'kern', h.characters[getchar(p)].italic)
	 else
	    tex.attribute[attr_icflag] = 0
	    return node_free(g)
	 end
      end
      node_write(g)
      tex.attribute[attr_icflag] = 0
   end
end
