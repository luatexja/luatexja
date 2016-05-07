--
-- luatexja/jfont.lua
--
luatexbase.provides_module({
  name = 'luatexja.jfont',
  date = '2016/04/03',
  description = 'Loader for Japanese fonts',
})
module('luatexja.jfont', package.seeall)

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('charrange'); local ltjc = luatexja.charrange
luatexja.load_module('rmlgbm');    local ltjr = luatexja.rmlgbm
luatexja.load_module('direction'); local ltjd = luatexja.direction

local setfield = node.direct.setfield
local getid = node.direct.getid
local to_direct = node.direct.todirect

local node_new = node.direct.new
local node_free = node.direct.free
local has_attr = node.direct.has_attribute
local set_attr = node.direct.set_attribute
local round = tex.round
local font_getfont = font.getfont

local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_curtfnt = luatexbase.attributes['ltj@curtfnt']
local id_glyph = node.id('glyph')
local id_kern = node.id('kern')
local cat_lp = luatexbase.catcodetables['latex-package']
local FROM_JFM     = luatexja.icflag_table.FROM_JFM
------------------------------------------------------------------------
-- LOADING JFM
------------------------------------------------------------------------

metrics={} -- this table stores all metric informations
font_metric_table={} -- [font number] -> jfm_name, jfm_var, size

luatexbase.create_callback("luatexja.load_jfm", "data", function (ft, jn) return ft end)

local jfm_file_name, jfm_var, jfm_ksp
local defjfm_res
local jfm_dir, is_def_jfont, is_vert_enabled

local function norm_val(a)
   if (not a) or (a==0.) then
      return nil
   elseif a==true then
      return 1
   else
      return a
   end
end

function define_jfm(t)
   local real_char -- Does current character class have the 'real' character?
   if t.dir~=jfm_dir then
      defjfm_res= nil; return
   elseif type(t.zw)~='number' or type(t.zh)~='number' then
      defjfm_res= nil; return
   end
   t.char_type = {}; t.chars = {}
   for i,v in pairs(t) do
      if type(i) == 'number' then -- char_type
	 if not v.chars then
	    if i ~= 0 then defjfm_res= nil; return  end
	 else
	    for j,w in pairs(v.chars) do
	       if type(w) == 'number' and w~=-1 then
	       elseif type(w) == 'string' and utf.len(w)==1 then
		  w = utf.byte(w)
	       elseif type(w) == 'string' and utf.len(w)==2 and utf.sub(w,2) == '*' then
		  w = utf.byte(utf.sub(w,1,1))
	       end
	       if not t.chars[w] then
		  t.chars[w] = i
	       else
		  defjfm_res= nil; return
	       end
	    end
	    v.chars = nil
	 end
	 if type(v.align)~='string' then
	    v.align = 'left' -- left
	 end
	 if type(v.width)~='number' then
	    v.width = (jfm_dir=='tate') and  1.0
	 end
	 if type(v.height)~='number' then
	    v.height = (jfm_dir=='tate') and  0.0
	 end
	 if type(v.depth)~='number' then
	    v.depth =  (jfm_dir=='tate') and  0.0
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
	 v.kern = v.kern or {}; v.glue = v.glue or {}
	 for j,x in pairs(v.glue) do
	    if v.kern[j] then defjfm_res= nil; return end
	    x.ratio, x[5] = (x.ratio or (x[5] and 0.5*(1+x[5]) or 0.5)), nil
	    x.priority, x[4] = (x.priority or x[4] or 0), nil
	    x.kanjiskip_natural = norm_val(x.kanjiskip_natural)
	    x.kanjiskip_stretch = norm_val(x.kanjiskip_stretch)
	    x.kanjiskip_shrink = norm_val(x.kanjiskip_shrink)
	 end
	 for j,x in pairs(v.kern) do
	    if type(x)=='number' then
               v.kern[j] = {x, 0.5}
            elseif type(x)=='table' then
               v.kern[j] = { x[1], ratio=x.ratio or (x[2] and 0.5*(1+x[2]) or 0.5) }
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
      --local TEMP = node_new(id_kern)
      local t = {}
      metrics[j].size_cache[sz] = t
      t.chars = metrics[j].chars
      t.char_type = mult_table(metrics[j].char_type, sz)
      for i,v in pairs(t.char_type) do
	 v.align = (v.align=='left') and 0 or
	    ((v.align=='right') and 1 or 0.5)
	 if type(i) == 'number' then -- char_type
	    for k,w in pairs(v.glue) do
	       v[k] = {
		  nil,
		  ratio=w.ratio/sz,
		  priority=FROM_JFM + w.priority/sz,
		  width = w[1], stretch = w[2], shrink = w[3],
		  kanjiskip_natural = w.kanjiskip_natural and w.kanjiskip_natural/sz,
		  kanjiskip_stretch = w.kanjiskip_stretch and w.kanjiskip_stretch/sz,
		  kanjiskip_shrink =  w.kanjiskip_shrink  and w.kanjiskip_shrink/sz,
	       }
	    end
	    for k,w in pairs(v.kern) do
	       local g = node_new(id_kern)
	       setfield(g, 'kern', w[1])
	       setfield(g, 'subtype', 1)
	       set_attr(g, attr_icflag, FROM_JFM)
	       v[k] = {g, ratio=w[2]/sz}
	    end
	 end
	 v.glue, v.kern = nil, nil
      end
      t.kanjiskip = mult_table(metrics[j].kanjiskip, sz)
      t.xkanjiskip = mult_table(metrics[j].xkanjiskip,sz)
      t.zw = round(metrics[j].zw*sz)
      t.zh = round(metrics[j].zh*sz)
      t.size = sz
      --node_free(TEMP)
   end
end

luatexbase.create_callback("luatexja.find_char_class", "data",
			   function (arg, fmtable, char)
			      return 0
			   end)
do
   local start_time_measure = ltjb.start_time_measure
   local stop_time_measure = ltjb.stop_time_measure
   local fcc_temp = { chars_cbcache = {} }
   setmetatable(
      fcc_temp.chars_cbcache,
      {
         __index = function () return 0 end,
      })
   function find_char_class(c,m)
      -- c: character code, m:
      local r = (m or fcc_temp).chars_cbcache[c]
      if not r then
         r = m.chars[c] or
            luatexbase.call_callback("luatexja.find_char_class", 0, m, c)
         m.chars_cbcache[c or 0] = r
      end
      return r
   end
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
   local utf8 = unicode.utf8
   function jfontdefX(g, dir, csname)
      jfm_dir, is_def_jfont = dir, true
      cstemp = csname:sub( (utf8.byte(csname,1,1) == tex.escapechar) and 2 or 1, -1)
      cstemp = cstemp:sub(1, ((cstemp:sub(-1,-1)==' ') and (cstemp:len()>=2)) and -2 or -1)
      global_flag = g and '\\global' or ''
      tex.sprint(cat_lp, '\\expandafter\\font\\csname ',
		 (cstemp==' ') and '\\space' or cstemp, '\\endcsname')
   end

   luatexbase.create_callback("luatexja.define_jfont", "data", function (ft, fn) return ft end)

-- EXT
   local identifiers = fonts.hashes.identifiers
   function jfontdefY()
      local j = load_jfont_metric(jfm_dir)
      local fn = font.id(cstemp)
      local f = font_getfont(fn)
      if not j then
	 ltjb.package_error('luatexja',
			    "bad JFM `" .. jfm_file_name .. "'",
			    'The JFM file you specified is not valid JFM file.\n'..
			       'So defining Japanese font is cancelled.')
	 tex.sprint(cat_lp, global_flag, '\\expandafter\\let\\csname ',
		    (cstemp==' ') and '\\space' or cstemp,
		       '\\endcsname=\\relax')
	 return
      end
      if not f then return end
      update_jfm_cache(j, f.size)
      local ad = identifiers[fn].parameters
      local sz = metrics[j].size_cache[f.size]
      local fmtable = { jfm = j, size = f.size, var = jfm_var,
			with_kanjiskip = jfm_ksp,
			zw = sz.zw, zh = sz.zh,
			ascent = ad.ascender,
			descent = ad.descender,
			chars = sz.chars, char_type = sz.char_type,
			kanjiskip = sz.kanjiskip, xkanjiskip = sz.xkanjiskip,
                        chars_cbcache = {},
			vert_activated = is_vert_enabled,
      }

      fmtable = luatexbase.call_callback("luatexja.define_jfont", fmtable, fn)
      font_metric_table[fn]=fmtable
      tex.sprint(cat_lp, global_flag, '\\protected\\expandafter\\def\\csname ',
		    (cstemp==' ') and '\\space' or cstemp, '\\endcsname{\\ltj@cur'..
		    (jfm_dir == 'yoko' and 'j' or 't') .. 'fnt', fn, '\\relax}')
   end
end

do
   local get_dir_count = ltjd.get_dir_count
   local dir_tate = luatexja.dir_table.dir_tate
   local tex_get_attr = tex.getattribute
   -- PUBLIC function
   function get_zw()
      local a = font_metric_table[
	 tex_get_attr((get_dir_count()==dir_tate) and attr_curtfnt or attr_curjfnt)]
      return a and a.zw or 0
   end
   function get_zh()
      local a = font_metric_table[
	 tex_get_attr((get_dir_count()==dir_tate) and attr_curtfnt or attr_curjfnt)]
      return a and a.zw or 0
   end
end

do
   -- extract jfm_file_name and jfm_var
   -- normalize position of 'jfm=' and 'jfmvar=' keys
   local function extract_metric(name)
      local is_braced = name:match('^{(.*)}$')
       name= is_braced or name
      jfm_file_name = ''; jfm_var = ''; jfm_ksp = true
      local tmp, index = name:sub(1, 5), 1
      if tmp == 'file:' or tmp == 'name:' or tmp == 'psft:' then
	 index = 6
      end
      local p = name:find(":", index); index = p and (p+1) or index
      while index do
	 local l = name:len()+1
	 local q = name:find(";", index+1) or l
	 if name:sub(index, index+3)=='jfm=' and q>index+4 then
	    jfm_file_name = name:sub(index+4, q-1)
	    if l~=q then
	       name = name:sub(1,index-1) .. name:sub(q+1)
	    else
	       name = name:sub(1,index-1)
	       index = nil
	    end
	 elseif name:sub(index, index+6)=='jfmvar=' and q>index+6 then
	    jfm_var = name:sub(index+7, q-1)
	    if l~=q then
	       name = name:sub(1,index-1) .. name:sub(q+1)
	    else
	       name = name:sub(1,index-1)
	       index = nil
	    end
	 else
	    index = (l~=q) and (q+1) or nil
	 end
      end
      if jfm_file_name~='' then
	 local l = name:sub(-1)
	 name = name
	    .. ((l==':' or l==';') and '' or ';')
	    .. 'jfm=' .. jfm_file_name
	 if jfm_var~='' then
	    name = name .. 'jfmvar=' .. jfm_var
	 end
      end
      for x in string.gmatch (name, "[:;]([+%%-]?)ltjks") do
	 jfm_ksp = not (x=='-')
      end
      if jfm_dir == 'tate' then
	 is_vert_enabled = (not name:match('[:;]%-vert')) and (not  name:match('[:;]%-vrt2'))
         if not name:match('vert') and not name:match('vrt2') then
            name = name .. ';+vert;+vrt2'
         end
      else
	 is_vert_enabled = nil
      end
      return is_braced and ('{' .. name .. '}') or name
   end

   -- define_font callback
   local otfl_fdr
   local ltjr_font_callback = ltjr.font_callback
   function luatexja.font_callback(name, size, id)
      local new_name = is_def_jfont and extract_metric(name) or name
      is_def_jfont = false
      local res =  ltjr_font_callback(new_name, size, id, otfl_fdr)
      luatexbase.call_callback('luatexja.define_font', res, new_name, size, id)
      -- this callback processes variation selector, so we execute it always
      return res
   end
   luatexbase.create_callback('luatexja.define_font', 'simple', function (n) return n end)
   otfl_fdr= luatexbase.remove_from_callback('define_font', 'luaotfload.define_font')
   luatexbase.add_to_callback('define_font',luatexja.font_callback,"luatexja.font_callback", 1)
end

------------------------------------------------------------------------
-- LATEX INTERFACE
------------------------------------------------------------------------
do
   -- these function are called from ltj-latex.sty
   local fenc_list, kyenc_list, ktenc_list = {}, {}, {}
   function add_fenc_list(enc) fenc_list[enc] = 'true ' end
   function add_kyenc_list(enc) kyenc_list[enc] = 'true ' end
   function add_ktenc_list(enc) ktenc_list[enc] = 'true ' end
   function is_kyenc(enc)
      tex.sprint(cat_lp, '\\let\\ifin@\\if' .. (kyenc_list[enc] or 'false '))
   end
   function is_ktenc(enc)
      tex.sprint(cat_lp, '\\let\\ifin@\\if' .. (ktenc_list[enc] or 'false '))
   end
   function is_kenc(enc)
      tex.sprint(cat_lp, '\\let\\ifin@\\if'
		 .. (kyenc_list[enc] or ktenc_list[enc] or 'false '))
   end

   local kfam_list, Nkfam_list = {}, {}
   function add_kfam(fam)
      kfam_list[fam]=true
   end
   function search_kfam(fam, use_fd)
      if kfam_list[fam] then
	 tex.sprint(cat_lp, '\\let\\ifin@\\iftrue '); return
      elseif Nkfam_list[fam] then
	 tex.sprint(cat_lp, '\\let\\ifin@\\iffalse '); return
      elseif use_fd then
	 for i,_ in pairs(kyenc_list) do
	    if kpse.find_file(string.lower(i)..fam..'.fd') then
	       tex.sprint(cat_lp, '\\let\\ifin@\\iftrue '); return
	    end
	 end
	 for i,_ in pairs(ktenc_list) do
	    if kpse.find_file(string.lower(i)..fam..'.fd') then
	       tex.sprint(cat_lp, '\\let\\ifin@\\iftrue '); return
	    end
	 end
	 Nkfam_list[fam]=true; tex.sprint(cat_lp, '\\let\\ifin@\\iffalse '); return
      else
	 tex.sprint(cat_lp, '\\let\\ifin@\\iffalse '); return
      end
   end
   local ffam_list, Nffam_list = {}, {}
   function is_ffam(fam)
      tex.sprint(cat_lp, '\\let\\ifin@\\if' .. (ffam_list[fam] or 'false '))
   end
   function add_ffam(fam)
      ffam_list[fam]='true '
   end
   function search_ffam_declared()
     local s = ''
     for i,_ in pairs(fenc_list) do
	s = s .. '\\cdp@elt{' .. i .. '}'
     end
     tex.sprint(cat_lp, s)
   end
   function search_ffam_fd(fam)
      if Nffam_list[fam] then
	 tex.sprint(cat_lp, '\\let\\ifin@\\iffalse '); return
      else
	 for i,_ in pairs(fenc_list) do
	    if kpse.find_file(string.lower(i)..fam..'.fd') then
	       tex.sprint(cat_lp, '\\let\\ifin@\\iftrue '); return
	    end
	 end
	 Nffam_list[fam]=true; tex.sprint(cat_lp, '\\let\\ifin@\\iffalse '); return
      end
   end

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
   function output_alt_font_cmd(dir, bbase)
      alt_font_base = bbase
      if dir == 't' then
	 alt_font_base_num = tex.getattribute(attr_curtfnt)
      else
	 alt_font_base_num = tex.getattribute(attr_curjfnt)
      end
      local t = alt_font_table[alt_font_base_num]
      if t then
         for i,_ in pairs(t) do t[i]=nil end
      end
      t = alt_font_table_latex[bbase]
      if t then
       for i,_ in pairs(t) do
            tex.sprint(cat_lp, '\\ltj@pickup@altfont@aux' .. dir .. '{' .. i .. '}')
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
-- 終了時に各種ノードを破棄
------------------------------------------------------------------------
do
   function cleanup_size_cache()
      --local gs, ke = 0, 0
      for _,n in pairs(metrics) do
	 for i,t in pairs(n.size_cache) do
	    for _,v in pairs(t.char_type) do
	       for k,w in pairs(v) do
		  if type(k)=='number' then
		     --if w[1] then gs = gs + 1 else ke = ke + 1 end
		     if w[1] then node_free(w[1]) end
		  end
	       end
	    end
	    n.size_cache[i]=nil
	 end
      end
   end
end

------------------------------------------------------------------------
-- VERT VARIANT TABLE
------------------------------------------------------------------------
local vert_form_table = {
   [0x2013]=0xFE32, [0x2014]=0xFE31, [0x2025]=0xFE30,
   [0xFF08]=0xFE35, [0xFF09]=0xFE36, [0xFF5B]=0xFE37, [0xFF5D]=0xFE38,
   [0x3014]=0xFE39, [0x3015]=0xFE3A, [0x3010]=0xFE3B, [0x3011]=0xFE3C,
   [0x300A]=0xFE3D, [0x300B]=0xFE3E, [0x3008]=0xFE3F, [0x3009]=0xFE40,
   [0x300C]=0xFE41, [0x300D]=0xFE42, [0x300E]=0xFE43, [0x300F]=0xFE44,
   [0xFF3B]=0xFE47, [0xFF3D]=0xFE48, [0xFF3F]=0xFE33,
}

------------------------------------------------------------------------
-- 追加のフォント情報
------------------------------------------------------------------------
font_extra_info = {}
local font_extra_info = font_extra_info -- key: fontnumber
local font_extra_basename = {} -- key: basename

-- IVS and vertical metrics
local prepare_fl_data
local supply_vkern_table
do
   local fields = fontloader.fields
   local function glyph_vmetric(glyph)
      local flds = fields(glyph)
      local vw, tsb, vk = nil, nil, nil
      for _,i in ipairs(flds) do
	 if i=='vwidth' then vw = glyph.vwidth end
	 if i=='tsidebearing' then tsb = glyph.tsidebearing end
	 if i=='vkerns' then vk = glyph.vkerns end
      end
      return vw, tsb, vk
   end

   local sort = table.sort
   local function add_fl_table(dest, glyphs, unitable, asc_des, units, id)
      local glyphmin, glyphmax = glyphs.glyphmin, glyphs.glyphmax
      if glyphmax < 0 then return dest end
      local tg = glyphs.glyphs
      for i = glyphmin, glyphmax do
	 local gv = tg[i]
	 if gv then
	    if gv.altuni then
	       for _,at in pairs(gv.altuni) do
		  local bu, vsel = at.unicode, at.variant
		  if vsel then
		     if vsel>=0xE0100 then vsel = vsel - 0xE0100 end
		     local uniq_flag = true
                     if dest and dest[bu] then
			for i,_ in pairs(dest[bu]) do
			   if i==vsel then uniq_flag = false; break end
		        end
                     end
		     if uniq_flag then
			dest = dest or {}; dest[bu] = dest[bu] or {}
			dest[bu][vsel] = unitable[gv.name]
		     end
		  end
	       end
	    end
	    -- vertical form
	    local gi = unitable[gv.name]
	    if gi then
	       if unitable[gv.name .. '.vert'] then
	          dest = dest or {}; dest[gi] = dest[gi] or {};
	          dest[gi].vform = unitable[gv.name .. '.vert']
	       elseif id.characters[gi] and vert_form_table[gi] then
	          dest = dest or {}; dest[gi] = dest[gi] or {};
	          dest[gi].vform = vert_form_table[gi]
	       end
	    end
	    -- vertical metric
	    local vw, tsb, vk = glyph_vmetric(gv)
	    local gi = unitable[gv.name]
	    if gi and vw and vw~=asc_des then
	       -- We do not use tsidebearing, since (1) fontloader does not read VORG table
	       -- and (2) 'tsidebearing' doea not appear in the returned table by fontloader.fields.
	       -- Hence, we assume that vertical origin == ascender
	       -- (see capsule_glyph_tate in ltj-setwidth.lua)
	       dest = dest or {}; dest[gi] = dest[gi] or {}
	       dest[gi].vwidth = vw/units
	    end
	    -- vertical kern
	    if gi and vk then
	       dest = dest or {};
	       local dest_vk = dest.vkerns or {}; dest.vkerns = dest_vk
	       for _,v in pairs(vk) do
		  if unitable[v.char] then
		     local vl = v.lookup
		     if type(vl)=='table' then
			for _,vlt in pairs(vl) do
			   dest_vk[vlt] = dest_vk[vlt] or {}
			   dest_vk[vlt][gi] = dest_vk[vlt][gi] or {}
			   dest_vk[vlt][gi][unitable[v.char]] = v.off
			end
		     else
			dest_vk[vl] = dest_vk[vl] or {}
			dest_vk[vl][gi] = dest_vk[vl][gi] or {}
			dest_vk[vl][gi][unitable[v.char]] = v.off
		     end
		  end
	       end
	    end
	 end
      end
      return dest
   end
   prepare_fl_data = function (dest, id)
      local fl = fontloader.open(id.filename)
      local ind_to_uni, unicodes = {}, {}
      for i,v in pairs(id.characters) do
	  ind_to_uni[v.index] = i
      end
      if fl.glyphs then
	 local tg, glyphmin, glyphmax = fl.glyphs, fl.glyphmin, fl.glyphmax
         if 0 <= glyphmax then
            for i = glyphmin, glyphmax do
               if tg[i] and tg[i].name then unicodes[tg[i].name] = ind_to_uni[i] end
	    end
	 end
	 dest = add_fl_table(dest, fl, unicodes,
			     fl.ascent + fl.descent, fl.units_per_em, id)
      end
      if fl.subfonts then
         for _,v in pairs(fl.subfonts) do
	    local tg, glyphmin, glyphmax = v.glyphs, v.glyphmin, v.glyphmax
            if 0 <= glyphmax then
               for i = glyphmin, glyphmax do
                  if tg[i] and tg[i].name then unicodes[tg[i].name] = ind_to_uni[i] end
	       end
	   end
       end
         for _,v in pairs(fl.subfonts) do
            dest = add_fl_table(dest, v, unicodes,
				fl.ascent + fl.descent, fl.units_per_em, id)
         end
     end
     if dest then dest.unicodes = unicodes end
     fontloader.close(fl); collectgarbage("collect")
     return dest
   end
   -- supply vkern table
   supply_vkern_table = function(id, bname)
      local bx = font_extra_basename[bname].vkerns
      local lookuphash =  id.resources.lookuphash
      local desc = id.shared.rawdata.descriptions
      if bx and lookuphash then
	 for i,v in pairs(bx) do
	    lookuphash[i] = lookuphash[i] or v
	    for j,w in pairs(v) do
	       desc[j].kerns = desc[j].kerns or {}
	       desc[j].kerns[i] = w
	    end
	 end
      end
   end
end

--
do
   local cache_ver = 11
   local checksum = file.checksum

   local function prepare_extra_data_base(id)
      if (not id) or (not id.filename) then return end
      local bname = file.nameonly(id.filename)
      if not font_extra_basename[bname] then
	 -- if the cache is present, read it
	 local newsum = checksum(id.filename) -- MD5 checksum of the fontfile
	 local v = "extra_" .. string.lower(file.nameonly(id.filename))
	 local dat = ltjb.load_cache(
	    v,
	    function (t) return (t.version~=cache_ver) or (t.chksum~=newsum) end
	 )
	 -- if the cache is not found or outdated, save the cache
	 if dat then
	    font_extra_basename[bname] = dat[1] or {}
	 else
	    local dat = nil
	    dat = prepare_fl_data(dat, id)
	    font_extra_basename[bname] = dat or {}
	    ltjb.save_cache( v,
			     {
				chksum = checksum(id.filename),
				version = cache_ver,
				dat,
			     })
	 end
	 return bname
      end
   end
   local function prepare_extra_data_font(id, res)
      if type(res)=='table' and res.shared and res.filename then
	 font_extra_info[id] = font_extra_basename[file.nameonly(res.filename)]
      end
   end
    luatexbase.add_to_callback(
       'luaotfload.patch_font',
       function (tfmdata)
	  -- these function is executed one time per one fontfile
          local bname = prepare_extra_data_base(tfmdata)
          if bname then supply_vkern_table(tfmdata, bname) end
	  return tfmdata
       end,
       'ltj.prepare_extra_data', 1)
   luatexbase.add_to_callback(
      'luatexja.define_font',
      function (res, name, size, id)
	 prepare_extra_data_font(id, res)
      end,
      'ltj.prepare_extra_data', 1)

   local nulltable = {} -- dummy
   ltjr.vert_addfunc = function (n) font_extra_info[n] = nulltable end

   local identifiers = fonts.hashes.identifiers
   for i=1,font.nextid()-1 do
      if identifiers[i] then
	 prepare_extra_data_base(identifiers[i])
	 prepare_extra_data_font(i,identifiers[i])
      end
   end
end


------------------------------------------------------------------------
-- calculate vadvance
------------------------------------------------------------------------
do
   local function acc_feature(table_vadv, table_vorg, subtables, ft,  already_vert)
      for char_num,v in pairs(ft.shared.rawdata.descriptions) do
	 if v.slookups then
	    for sn, sv in pairs(v.slookups) do
	       if subtables[sn] and type(sv)=='table' then
		  if sv[4]~=0 then
		     table_vadv[char_num]
			= (table_vadv[char_num] or 0) + sv[4]
		  end
		  if sv[2]~=0 and not already_vert then
		     table_vorg[char_num]
			= (table_vorg[char_num] or 0) + sv[2]
		  end
	       end
	    end
	 end
      end
   end

luatexbase.add_to_callback(
   "luatexja.define_jfont",
   function (fmtable, fnum)
      local vadv = {}; fmtable.v_advance = vadv
      local vorg = {}; fmtable.v_origin = vorg
      local ft = font_getfont(fnum)
      local subtables = {}
      if ft.specification then
	 for feat_name,v in pairs(ft.specification.features.normal) do
	    if v==true then
	       for _,i in pairs(ft.resources.sequences) do
		  if i.order[1]== feat_name and i.type == 'gpos_single' then
		     for _,st in pairs(i.subtables) do
			subtables[st] = true
		     end
		  end
	       end
	    end
	 end
	 acc_feature(vadv, vorg, subtables, ft,
		     ft.specification.features.normal.vrt2 or ft.specification.features.normal.vert)
	 for i,v in pairs(vadv) do
	    vadv[i]=vadv[i]/ft.units_per_em*fmtable.size
	 end
	 for i,v in pairs(vorg) do
	    vorg[i]=vorg[i]/ft.units_per_em*fmtable.size
	 end
      end
      return fmtable
   end, 1, 'ltj.v_advance'
)
end

------------------------------------------------------------------------
-- supply tounicode entries
------------------------------------------------------------------------
do
  local ltjr_prepare_cid_font = ltjr.prepare_cid_font
  luatexbase.add_to_callback(
     'luaotfload.patch_font',
     function (tfmdata)
	if tfmdata.cidinfo then
	   local rd = ltjr_prepare_cid_font(tfmdata.cidinfo.registry, tfmdata.cidinfo.ordering)
	   if rd then
	      local ru, rc = rd.resources.unicodes, rd.characters
	      for i,v in pairs(tfmdata.characters) do
		 local w = ru["Japan1." .. tostring(v.index)]
		 if w then
		    v.tounicode = v.tounicode or rc[w]. tounicode
		 end
	      end
	   end
	end

	return tfmdata
     end,
     'ltj.supply_tounicode', 1)
end


------------------------------------------------------------------------
-- MISC
------------------------------------------------------------------------
do
   local getfont = node.direct.getfont
   local getchar = node.direct.getchar
   local get_dir_count = ltjd.get_dir_count
   local is_ucs_in_japanese_char = ltjc.is_ucs_in_japanese_char_direct
   local ensure_tex_attr = ltjb.ensure_tex_attr
   local node_write = node.direct.write
   local font = font
   local new_ic_kern
   if status.luatex_version>=89 then
       new_ic_kern = function(g)  return node_new(id_kern,3) end
   else
       local ITALIC       = luatexja.icflag_table.ITALIC
       new_ic_kern = function()
         local g = node_new(id_kern)
         setfield(g, 'subtype', 1); set_attr(g, attr_icflag, ITALIC)
	 return g
       end
   end
   -- EXT: italic correction
   function append_italic()
      local p = to_direct(tex.nest[tex.nest.ptr].tail)
      local TEMP = node_new(id_kern)
      if p and getid(p)==id_glyph then
	 if is_ucs_in_japanese_char(p) then
	    local j = font_metric_table[
	       has_attr(p, (get_dir_count()==dir_tate) and attr_curtfnt or attr_curjfnt)
	       ]
	    local g = new_ic_kern()
	    setfield(g, 'kern', j.char_type[find_char_class(getchar(p), j)].italic)
	    node_write(g); ensure_tex_attr(attr_icflag, 0)
	 else
	    local f = getfont(p)
	    local h = font_getfont(f) or font.fonts[f]
	    if h then
	       local g = new_ic_kern()
	       if h.characters[getchar(p)] and h.characters[getchar(p)].italic then
		  setfield(g, 'kern', h.characters[getchar(p)].italic)
		  node_write(g); ensure_tex_attr(attr_icflag, 0)
	       end
	    end
	 end
      end
      node_free(TEMP)
   end
end

