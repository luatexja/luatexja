--
-- luatexja/jfont.lua
--
luatexbase.provides_module({
  name = 'luatexja.jfont',
  date = '2019/02/11',
  description = 'Loader for Japanese fonts',
})

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

luatexja.jfont = luatexja.jfont or {}
------------------------------------------------------------------------
-- LOADING JFM
------------------------------------------------------------------------

local metrics={} -- this table stores all metric informations
local font_metric_table={} -- [font number] -> jfm_name, jfm_var, size

luatexbase.create_callback("luatexja.load_jfm", "data", function (ft, jn) return ft end)

local jfm_file_name, jfm_var, jfm_ksp
local defjfm_res
local jfm_dir, is_def_jfont, is_vert_enabled, auto_enable_vrt2

local function norm_val(a)
   if (not a) or (a==0.) then
      return nil
   elseif a==true then
      return 1
   else
      return a
   end
end

local fastcopy=table.fastcopy
function luatexja.jfont.define_jfm(to)
   local t = fastcopy(to)
   local real_char -- Does current character class have the 'real' character?
   if t.dir~=jfm_dir then
      defjfm_res= nil; return
   elseif type(t.zw)~='number' or type(t.zh)~='number' then
      defjfm_res= nil; return
   end
   t.version = (type(t.version)=='number') and t.version or 1
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
            v.width = nil
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
         if t.version>=2 then
            if v.end_stretch then defjfm_res= nil; return end
            if v.end_shrink  then defjfm_res= nil; return end
            if v.end_adjust then
               if type(v.end_adjust)~='table' then
                  v.end_adjust = nil
               elseif #(v.end_adjust)==0 then
                  v.end_adjust = nil
               else 
                  table.sort(v.end_adjust)
               end
            end
         else
            v.end_adjust = nil
            if v.end_stretch and v.end_stretch~=0.0 then 
               v.end_adjust = (v.end_adjust or {}) 
               v.end_adjust[#(v.end_adjust)+1] = v.end_stretch
            end
            if v.end_shrink and v.end_ahrink~=0.0 then 
               v.end_adjust = (v.end_adjust or {}) 
               v.end_adjust[#(v.end_adjust)+1] = -v.end_shrink
            end
            if v.end_adjust then v.end_adjust[#(v.end_adjust)+1] = 0.0 end
         end
         v.kern = v.kern or {}; v.glue = v.glue or {}
         for j,x in pairs(v.glue) do
            if v.kern[j] then defjfm_res= nil; return end
            x.ratio, x[5] = (x.ratio or (x[5] and 0.5*(1+x[5]) or 0.5)), nil
            do
               local xp
               xp, x[4] = (x.priority or x[4]), nil
               if type(xp)=='table' and t.version>=2 then
                  if type(xp[1])~='number' or xp[1]<-4 or xp[1]>3 then defjfm_res=nil end  -- stretch
                  if type(xp[2])~='number' or xp[2]<-4 or xp[2]>3 then defjfm_res=nil end  -- shrink
                  xp = (xp[1]+4)*8+(xp[2]+4)
               elseif xp and type(xp)~='number' then
                  defjfm_res = nil
               else
                  xp = (xp or 0)*9+36        
                  if xp<0 or xp>=64 then defjfm_res=nil end 
               end
               x.priority = xp
            end
            x.kanjiskip_natural = norm_val(x.kanjiskip_natural)
            x.kanjiskip_stretch = norm_val(x.kanjiskip_stretch)
            x.kanjiskip_shrink = norm_val(x.kanjiskip_shrink)
         end
         for j,x in pairs(v.kern) do
            if type(x)=='number' then
               v.kern[j] = {x, 0.5}
            elseif type(x)=='table' then
               v.kern[j] = { x[1], (x.ratio or (x[2] and 0.5*(1+x[2]) or 0.5)) }
            end
         end
         t.char_type[i] = v
         t[i] = nil
      end
   end
   if t.version<3 then
      -- In version 3, 'jcharbdd' is divided into 
      -- 'alchar': ALchar (or math boundary) 
      -- 'nox_alchar': ALchar (or math boundary), where xkanjiskip won't inserted
      -- 'glue': glue/kern, 'jcharbdd': other cases (和文B, rule, ...)
      t.chars.alchar = t.chars.jcharbdd
      t.chars.nox_alchar = t.chars.jcharbdd
      t.chars.glue = t.chars.jcharbdd
   end
   t = luatexbase.call_callback("luatexja.load_jfm", t, jfm_file_name)
   t.size_cache = {}
   defjfm_res = t
end

local update_jfm_cache
do
   local floor = math.floor
   local function myround(a) return floor(a+0.5) end
   local function mult_table(old,scale) -- modified from table.fastcopy
      if old then
         local new = { }
         for k,v in next, old do
            if type(v) == "table" then
               new[k] = mult_table(v,scale)
            elseif type(v) == "number" then
               new[k] = myround(v*scale)
            else
               new[k] = v
            end
         end
         return new
      else return nil end
   end
   local size_cache_num = 1
   update_jfm_cache = function (j,sz)
      if metrics[j].size_cache[sz] then return metrics[j].size_cache[sz].index end
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
               local g = node_new(id_kern, 1)
               setfield(g, 'kern', w[1])
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
      size_cache_num = size_cache_num + 1
      t.index = size_cache_num
      return size_cache_num
   end
end

luatexbase.create_callback("luatexja.find_char_class", "data",
                           function (arg, fmtable, char)
                              return 0
                          end)
local find_char_class
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

local load_jfont_metric
do
   local cstemp
   local global_flag -- true if \globaljfont, false if \jfont
   load_jfont_metric = function()
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
   function luatexja.jfont.jfontdefX(g, dir, csname)
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
   local provides_feature = luaotfload.aux.provides_feature
   function luatexja.jfont.jfontdefY()
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
      local t = identifiers[fn]
      if auto_enable_vrt2 then
         local lang, scr = t.properties.language, t.properties.script
         local vrt2_exist = provides_feature(
           fn, t.properties.script, t.properties.language, 'vrt2'
         )
         t.shared.features[vrt2_exist and 'vrt2' or 'vert'] = true
      end

      --texio.write_nl('term and log', 
      --'JFNT\t' .. identifiers[fn].name .. '\t' .. identifiers[fn].size .. '\t' .. fn, '')

      fmtable = luatexbase.call_callback("luatexja.define_jfont", fmtable, fn)
      font_metric_table[fn]=fmtable
      tex.sprint(cat_lp, global_flag, '\\protected\\expandafter\\def\\csname ',
                    (cstemp==' ') and '\\space' or cstemp, '\\endcsname{\\ltj@cur'..
                    (jfm_dir == 'yoko' and 'j' or 't') .. 'fnt', fn, '\\relax}')
      jfm_file_name = nil
   end
end

do
   local get_dir_count = ltjd.get_dir_count
   local dir_tate = luatexja.dir_table.dir_tate
   local tex_get_attr = tex.getattribute
   -- PUBLIC function
   function luatexja.jfont.get_zw()
      local a = font_metric_table[
         tex_get_attr((get_dir_count()==dir_tate) and attr_curtfnt or attr_curjfnt)]
      return a and a.zw or 0
   end
   function luatexja.jfont.get_zh()
      local a = font_metric_table[
         tex_get_attr((get_dir_count()==dir_tate) and attr_curtfnt or attr_curjfnt)]
      return a and a.zw or 0
   end
end

do
   local gmatch = string.gmatch
   -- extract jfm_file_name and jfm_var
   -- normalize position of 'jfm=' and 'jfmvar=' keys
   local function extract_metric(name)
      do
         local nametemp
         nametemp = name:match('^{(.*)}$')
         if nametemp then name = nametemp
         else
              nametemp = name:match('^"(.*)"$')
            name = nametemp or name
         end
      end
      jfm_file_name = ''; jfm_var = ''; jfm_ksp = true
      local tmp, index = name:sub(1, 5), 1
      if tmp == 'file:' or tmp == 'name:' or tmp == 'psft:' then
         index = 6
      end
      local p = name:find(":", index); index = p and (p+1) or index
      while index do
         local l = name:len()+1
         local q = name:find(";", index) or l
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
            name = name .. ';jfmvar=' .. jfm_var
         end
      end
      for x in gmatch (name, "[:;]([+%%-]?)ltjks") do
         jfm_ksp = not (x=='-')
      end
      if jfm_dir == 'tate' then
         is_vert_enabled = (not name:match('[:;]%-vert')) and (not  name:match('[:;]%-vrt2'))
         auto_enable_vrt2 
           = (not name:match('[:;][+%-]?vert')) and (not name:match('[:;][+%-]?vrt2'))
      else
         is_vert_enabled, auto_enable_vrt2 = nil, nil
      end
      return name
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

   local match, sp = string.match, tex.sp
   local function load_jfmonly(spec, dir)
      local spec, size = match(spec,'(.+)%s+at%s*([%.%w]*)')
      size = sp(size); extract_metric(spec)
      jfm_dir = dir
      local i = load_jfont_metric()
      local j = -update_jfm_cache(i, size)
      font_metric_table[j]=metrics[i].size_cache[s]      
      tex.sprint(cat_lp, '\\ltj@cur' .. (dir=='yoko' and 'j' or 't') .. 'fnt' .. tostring(j) .. '\\relax')
   end
   luatexja.jfont.load_jfmonly = load_jfmonly
end

------------------------------------------------------------------------
-- LATEX INTERFACE
------------------------------------------------------------------------
do
   -- these function are called from ltj-latex.sty
   local fenc_list, kyenc_list, ktenc_list = {}, {}, {}
   function luatexja.jfont.add_fenc_list(enc) fenc_list[enc] = 'true ' end
   function luatexja.jfont.add_kyenc_list(enc) kyenc_list[enc] = 'true ' end
   function luatexja.jfont.add_ktenc_list(enc) ktenc_list[enc] = 'true ' end
   function luatexja.jfont.is_kyenc(enc)
      tex.sprint(cat_lp, '\\let\\ifin@\\if' .. (kyenc_list[enc] or 'false '))
   end
   function luatexja.jfont.is_ktenc(enc)
      tex.sprint(cat_lp, '\\let\\ifin@\\if' .. (ktenc_list[enc] or 'false '))
   end
   function luatexja.jfont.is_kenc(enc)
      tex.sprint(cat_lp, '\\let\\ifin@\\if'
                 .. (kyenc_list[enc] or ktenc_list[enc] or 'false '))
   end

   local kfam_list, Nkfam_list = {}, {}
   function luatexja.jfont.add_kfam(fam)
      kfam_list[fam]=true
   end
   function luatexja.jfont.search_kfam(fam, use_fd)
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
   function luatexja.jfont.is_ffam(fam)
      tex.sprint(cat_lp, '\\let\\ifin@\\if' .. (ffam_list[fam] or 'false '))
   end
   function luatexja.jfont.add_ffam(fam)
      ffam_list[fam]='true '
   end
   function luatexja.jfont.search_ffam_declared()
     local s = ''
     for i,_ in pairs(fenc_list) do
        s = s .. '\\cdp@elt{' .. i .. '}'
     end
     tex.sprint(cat_lp, s)
   end
   function luatexja.jfont.search_ffam_fd(fam)
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
local alt_font_table = {}
local attr_curaltfnt = {}
local ucs_out = 0x110000

------ for TeX interface
-- EXT
function luatexja.jfont.set_alt_font(b,e,ind,bfnt)
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
function luatexja.jfont.clear_alt_font(bfnt)
   if alt_font_table[bfnt] then
      local t = alt_font_table[bfnt]
      for i,_ in pairs(t) do t[i]=nil; end
   end
end

------ used in ltjp.suppress_hyphenate_ja callback
function luatexja.jfont.replace_altfont(pf, pc)
   local a = alt_font_table[pf]
   return a and a[pc] or pf
end

------ for LaTeX interface

local alt_font_table_latex = {}

-- EXT
function luatexja.jfont.clear_alt_font_latex(bbase)
   local t = alt_font_table_latex[bbase]
   if t then
      for j,v in pairs(t) do t[j] = nil end
   end
end

-- EXT
function luatexja.jfont.set_alt_font_latex(b,e,ind,bbase)
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
   function luatexja.jfont.does_alt_set(bbase)
      aftl_base = alt_font_table_latex[bbase]
      tex.sprint(cat_lp, aftl_base and '\\@firstofone' or '\\@gobble')
   end
   -- EXT
   function luatexja.jfont.print_aftl_address()
      return ';ltjaltfont' .. tostring(aftl_base):sub(8)
   end

-- EXT
   function luatexja.jfont.output_alt_font_cmd(dir, bbase)
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
   function luatexja.jfont.pickup_alt_font_a(size_str)
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
   function luatexja.jfont.pickup_alt_font_b(afnt_num, afnt_base)
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
   function luatexja.jfont.cleanup_size_cache()
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
-- 追加のフォント情報
------------------------------------------------------------------------
local font_extra_info = {}
luatexja.jfont.font_extra_info= font_extra_info -- key: fontnumber
local font_extra_basename = {} -- key: basename

local list_rotate_glyphs
do
   -- output of function_uax50.lua
   -- UAX#50 for Unicode  11.0.0
   -- t[0] = true
  local t={ 0, 167, 168, 169, 170, 174, 175, 177, 178, 188, 191, 215, 216, 247, 248, 746, 748, 888, 890, 896, 900, 907, 908, 909, 910, 930, 931, 1328, 1329, 1367, 1369, 1419, 1421, 1424, 1425, 1480, 1488, 1515, 1519, 1525, 1536, 1565, 1566, 1806, 1807, 1867, 1869, 1970, 1984, 2043, 2045, 2094, 2096, 2111, 2112, 2140, 2142, 2143, 2144, 2155, 2208, 2229, 2230, 2238, 2259, 2436, 2437, 2445, 2447, 2449, 2451, 2473, 2474, 2481, 2482, 2483, 2486, 2490, 2492, 2501, 2503, 2505, 2507, 2511, 2519, 2520, 2524, 2526, 2527, 2532, 2534, 2559, 2561, 2564, 2565, 2571, 2575, 2577, 2579, 2601, 2602, 2609, 2610, 2612, 2613, 2615, 2616, 2618, 2620, 2621, 2622, 2627, 2631, 2633, 2635, 2638, 2641, 2642, 2649, 2653, 2654, 2655, 2662, 2679, 2689, 2692, 2693, 2702, 2703, 2706, 2707, 2729, 2730, 2737, 2738, 2740, 2741, 2746, 2748, 2758, 2759, 2762, 2763, 2766, 2768, 2769, 2784, 2788, 2790, 2802, 2809, 2816, 2817, 2820, 2821, 2829, 2831, 2833, 2835, 2857, 2858, 2865, 2866, 2868, 2869, 2874, 2876, 2885, 2887, 2889, 2891, 2894, 2902, 2904, 2908, 2910, 2911, 2916, 2918, 2936, 2946, 2948, 2949, 2955, 2958, 2961, 2962, 2966, 2969, 2971, 2972, 2973, 2974, 2976, 2979, 2981, 2984, 2987, 2990, 3002, 3006, 3011, 3014, 3017, 3018, 3022, 3024, 3025, 3031, 3032, 3046, 3067, 3072, 3085, 3086, 3089, 3090, 3113, 3114, 3130, 3133, 3141, 3142, 3145, 3146, 3150, 3157, 3159, 3160, 3163, 3168, 3172, 3174, 3184, 3192, 3213, 3214, 3217, 3218, 3241, 3242, 3252, 3253, 3258, 3260, 3269, 3270, 3273, 3274, 3278, 3285, 3287, 3294, 3295, 3296, 3300, 3302, 3312, 3313, 3315, 3328, 3332, 3333, 3341, 3342, 3345, 3346, 3397, 3398, 3401, 3402, 3408, 3412, 3428, 3430, 3456, 3458, 3460, 3461, 3479, 3482, 3506, 3507, 3516, 3517, 3518, 3520, 3527, 3530, 3531, 3535, 3541, 3542, 3543, 3544, 3552, 3558, 3568, 3570, 3573, 3585, 3643, 3647, 3676, 3713, 3715, 3716, 3717, 3719, 3721, 3722, 3723, 3725, 3726, 3732, 3736, 3737, 3744, 3745, 3748, 3749, 3750, 3751, 3752, 3754, 3756, 3757, 3770, 3771, 3774, 3776, 3781, 3782, 3783, 3784, 3790, 3792, 3802, 3804, 3808, 3840, 3912, 3913, 3949, 3953, 3992, 3993, 4029, 4030, 4045, 4046, 4059, 4096, 4294, 4295, 4296, 4301, 4302, 4304, 4352, 4608, 4681, 4682, 4686, 4688, 4695, 4696, 4697, 4698, 4702, 4704, 4745, 4746, 4750, 4752, 4785, 4786, 4790, 4792, 4799, 4800, 4801, 4802, 4806, 4808, 4823, 4824, 4881, 4882, 4886, 4888, 4955, 4957, 4989, 4992, 5018, 5024, 5110, 5112, 5118, 5120, 5121, 5760, 5789, 5792, 5881, 5888, 5901, 5902, 5909, 5920, 5943, 5952, 5972, 5984, 5997, 5998, 6001, 6002, 6004, 6016, 6110, 6112, 6122, 6128, 6138, 6144, 6159, 6160, 6170, 6176, 6265, 6272, 6315, 6400, 6431, 6432, 6444, 6448, 6460, 6464, 6465, 6468, 6510, 6512, 6517, 6528, 6572, 6576, 6602, 6608, 6619, 6622, 6684, 6686, 6751, 6752, 6781, 6783, 6794, 6800, 6810, 6816, 6830, 6832, 6847, 6912, 6988, 6992, 7037, 7040, 7156, 7164, 7224, 7227, 7242, 7245, 7305, 7312, 7355, 7357, 7368, 7376, 7418, 7424, 7674, 7675, 7958, 7960, 7966, 7968, 8006, 8008, 8014, 8016, 8024, 8025, 8026, 8027, 8028, 8029, 8030, 8031, 8062, 8064, 8117, 8118, 8133, 8134, 8148, 8150, 8156, 8157, 8176, 8178, 8181, 8182, 8191, 8192, 8214, 8215, 8224, 8226, 8240, 8242, 8251, 8253, 8258, 8259, 8263, 8266, 8273, 8274, 8293, 8294, 8306, 8308, 8335, 8336, 8349, 8352, 8384, 8400, 8413, 8417, 8418, 8421, 8433, 8450, 8451, 8458, 8463, 8464, 8467, 8469, 8470, 8472, 8478, 8484, 8485, 8486, 8487, 8488, 8489, 8490, 8494, 8495, 8501, 8512, 8517, 8523, 8524, 8526, 8527, 8586, 8588, 8592, 8734, 8735, 8756, 8758, 8960, 8968, 8972, 8992, 8996, 9001, 9003, 9004, 9085, 9115, 9150, 9166, 9167, 9168, 9169, 9180, 9186, 9251, 9252, 9472, 9632, 9754, 9760, 10088, 10102, 10132, 11026, 11056, 11088, 11098, 11124, 11126, 11158, 11160, 11192, 11218, 11219, 11244, 11248, 11264, 11311, 11312, 11359, 11360, 11508, 11513, 11558, 11559, 11560, 11565, 11566, 11568, 11624, 11631, 11633, 11647, 11671, 11680, 11687, 11688, 11695, 11696, 11703, 11704, 11711, 11712, 11719, 11720, 11727, 11728, 11735, 11736, 11743, 11744, 11855, 12296, 12306, 12308, 12320, 12336, 12337, 12448, 12449, 12540, 12541, 42192, 42540, 42560, 42744, 42752, 42938, 42999, 43052, 43056, 43066, 43072, 43128, 43136, 43206, 43214, 43226, 43232, 43348, 43359, 43360, 43392, 43470, 43471, 43482, 43486, 43519, 43520, 43575, 43584, 43598, 43600, 43610, 43612, 43715, 43739, 43767, 43777, 43783, 43785, 43791, 43793, 43799, 43808, 43815, 43816, 43823, 43824, 43878, 43888, 44014, 44016, 44026, 55296, 57344, 64256, 64263, 64275, 64280, 64285, 64311, 64312, 64317, 64318, 64319, 64320, 64322, 64323, 64325, 64326, 64450, 64467, 64832, 64848, 64912, 64914, 64968, 65008, 65022, 65024, 65040, 65056, 65072, 65097, 65104, 65112, 65119, 65123, 65127, 65136, 65141, 65142, 65277, 65279, 65280, 65288, 65290, 65293, 65294, 65306, 65311, 65339, 65340, 65341, 65342, 65343, 65344, 65371, 65471, 65474, 65480, 65482, 65488, 65490, 65496, 65498, 65501, 65507, 65508, 65512, 65519, 65529, 65532, 65536, 65548, 65549, 65575, 65576, 65595, 65596, 65598, 65599, 65614, 65616, 65630, 65664, 65787, 65792, 65795, 65799, 65844, 65847, 65935, 65936, 65948, 65952, 65953, 66000, 66046, 66176, 66205, 66208, 66257, 66272, 66300, 66304, 66340, 66349, 66379, 66384, 66427, 66432, 66462, 66463, 66500, 66504, 66518, 66560, 66718, 66720, 66730, 66736, 66772, 66776, 66812, 66816, 66856, 66864, 66916, 66927, 66928, 67072, 67383, 67392, 67414, 67424, 67432, 67584, 67590, 67592, 67593, 67594, 67638, 67639, 67641, 67644, 67645, 67647, 67670, 67671, 67743, 67751, 67760, 67808, 67827, 67828, 67830, 67835, 67868, 67871, 67898, 67903, 67904, 68000, 68024, 68028, 68048, 68050, 68100, 68101, 68103, 68108, 68116, 68117, 68120, 68121, 68150, 68152, 68155, 68159, 68169, 68176, 68185, 68192, 68256, 68288, 68327, 68331, 68343, 68352, 68406, 68409, 68438, 68440, 68467, 68472, 68498, 68505, 68509, 68521, 68528, 68608, 68681, 68736, 68787, 68800, 68851, 68858, 68904, 68912, 68922, 69216, 69247, 69376, 69416, 69424, 69466, 69632, 69710, 69714, 69744, 69759, 69826, 69837, 69838, 69840, 69865, 69872, 69882, 69888, 69941, 69942, 69959, 69968, 70007, 70016, 70094, 70096, 70112, 70113, 70133, 70144, 70162, 70163, 70207, 70272, 70279, 70280, 70281, 70282, 70286, 70287, 70302, 70303, 70314, 70320, 70379, 70384, 70394, 70400, 70404, 70405, 70413, 70415, 70417, 70419, 70441, 70442, 70449, 70450, 70452, 70453, 70458, 70459, 70469, 70471, 70473, 70475, 70478, 70480, 70481, 70487, 70488, 70493, 70500, 70502, 70509, 70512, 70517, 70656, 70746, 70747, 70748, 70749, 70751, 70784, 70856, 70864, 70874, 71168, 71237, 71248, 71258, 71264, 71277, 71296, 71352, 71360, 71370, 71424, 71451, 71453, 71468, 71472, 71488, 71680, 71740, 71840, 71923, 71935, 71936, 72384, 72441, 72704, 72713, 72714, 72759, 72760, 72774, 72784, 72813, 72816, 72848, 72850, 72872, 72873, 72887, 72960, 72967, 72968, 72970, 72971, 73015, 73018, 73019, 73020, 73022, 73023, 73032, 73040, 73050, 73056, 73062, 73063, 73065, 73066, 73103, 73104, 73106, 73107, 73113, 73120, 73130, 73440, 73465, 73728, 74650, 74752, 74863, 74864, 74869, 74880, 75076, 92160, 92729, 92736, 92767, 92768, 92778, 92782, 92784, 92880, 92910, 92912, 92918, 92928, 92998, 93008, 93018, 93019, 93026, 93027, 93048, 93053, 93072, 93760, 93851, 93952, 94021, 94032, 94079, 94095, 94112, 113664, 113771, 113776, 113789, 113792, 113801, 113808, 113818, 113820, 113828, 119296, 119366, 119808, 119893, 119894, 119965, 119966, 119968, 119970, 119971, 119973, 119975, 119977, 119981, 119982, 119994, 119995, 119996, 119997, 120004, 120005, 120070, 120071, 120075, 120077, 120085, 120086, 120093, 120094, 120122, 120123, 120127, 120128, 120133, 120134, 120135, 120138, 120145, 120146, 120486, 120488, 120780, 120782, 120832, 122880, 122887, 122888, 122905, 122907, 122914, 122915, 122917, 122918, 122923, 124928, 125125, 125127, 125143, 125184, 125259, 125264, 125274, 125278, 125280, 126065, 126133, 126464, 126468, 126469, 126496, 126497, 126499, 126500, 126501, 126503, 126504, 126505, 126515, 126516, 126520, 126521, 126522, 126523, 126524, 126530, 126531, 126535, 126536, 126537, 126538, 126539, 126540, 126541, 126544, 126545, 126547, 126548, 126549, 126551, 126552, 126553, 126554, 126555, 126556, 126557, 126558, 126559, 126560, 126561, 126563, 126564, 126565, 126567, 126571, 126572, 126579, 126580, 126584, 126585, 126589, 126590, 126591, 126592, 126602, 126603, 126620, 126625, 126628, 126629, 126634, 126635, 126652, 126704, 126706, 129024, 129036, 129040, 129096, 129104, 129114, 129120, 129160, 129168, 129198, 917505, 917506, 917536, 917632, 917760, 918000 }
   local function rotate_in_uax50(i)
     local lo, hi = 1, #t
     while lo < hi do
       local mi = math.ceil((lo+hi)/2)
       if t[mi]<=i then lo=mi else hi=mi-1 end 
     end
     return lo%2==1
   end
   list_rotate_glyphs = function (dest, id)
      if id.specification and id.resources then
         local rot = {}
         for i,_ in pairs(id.characters) do
            if rotate_in_uax50(i) then rot[i] = true end
         end
         if id.resources.sequences then
         for _,i in pairs(id.resources.sequences) do
            if i.order[1]== 'vert' and i.type == 'gsub_single' and i.steps then
               for _,j in pairs(i.steps) do
                  if type(j)=='table' then 
                     if type(j.coverage)=='table' then
                        for i,_ in pairs(j.coverage) do rot[i]=nil end
                     end
                  end
               end
            end
         end; end
         -- コードポイントが共有されているグリフについて
         if id.resources.duplicates then
         for i,v in pairs(id.resources.duplicates) do
            local f = rot[i]
            for j,_ in pairs(v) do f = f and rot[j] end
            rot[i]=f
            for j,_ in pairs(v) do rot[j] = f end
         end; end
         
         for i,_ in pairs(rot) do
            dest = dest or {}
            dest[i] = dest[i] or {}
            dest[i].rotation = true
         end
      end
      return dest
   end
end

-- vertical metrics
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
      local t = fontloader.info(id.filename)
      if not t then return dest end
      local fl
      if t.fontname then
        fl = fontloader.open(id.filename)
      else
        fl = fontloader.open(id.filename, id.fontname) -- マニュアルにはこっちで書いてあるが？
        if not fl then
          local index
          for i,v in ipairs(t) do
            if v.fontname == id.fontname then index=i; break end
          end  
          fl = fontloader.open(id.filename, index)
        end
      end
      if not fl then fontloader.close(fl); return dest end
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
   local cache_ver = 16

   local function prepare_extra_data_base(id)
      if (not id) or (not id.filename) then return end
      local bname = id.psname or file.nameonly(id.filename)
      if not font_extra_basename[bname] then
         -- if the cache is present, read it
         if not lfs then lfs=require"lfs"  end
         local newtime = lfs.attributes(id.filename,"modification")
         local v = "extra_" .. string.lower(bname)
         local dat = ltjb.load_cache(
            v,
            function (t) return (t.version~=cache_ver) or (t.modtime~=newtime) end
         )
         -- if the cache is not found or outdated, save the cache
         if dat then
            font_extra_basename[bname] = dat[1] or {}
         else
            local dat = nil
            dat = prepare_fl_data(dat, id)
            dat = list_rotate_glyphs(dat, id)
            font_extra_basename[bname] = dat or {}
            ltjb.save_cache( v,
                             {
                                modtime = newtime,
                                version = cache_ver,
                                dat,
                             })
         end
         return bname
      end
   end
   local function prepare_extra_data_font(id, res)
      if type(res)=='table' and res.shared and (res.psname or res.filename) then
         font_extra_info[id] = font_extra_basename[res.psname or file.nameonly(res.filename)]
      end
   end
    luatexbase.add_to_callback(
       'luaotfload.patch_font',
       function (tfmdata)
          -- these function is executed one time per one fontfile
          if jfm_file_name then
            local bname = prepare_extra_data_base(tfmdata)
            if bname then supply_vkern_table(tfmdata, bname) end
          end
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
            if v==true and ft.resources then
               for _,i in pairs(ft.resources.sequences) do
                  if i.order[1]== feat_name and i.type == 'gpos_single' and type(i.subtables)=='table' then
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
   end, 'ltj.v_advance', 1
)
end

------------------------------------------------------------------------
-- make table of vertical glyphs which does not covered by vert feature
-- nor UTR#50
------------------------------------------------------------------------
do
------------------------------------------------------------------------
-- VERT VARIANT TABLE
------------------------------------------------------------------------
  local provides_feature = luaotfload.aux.provides_feature
  local vert_form_table = {
     [0x3001]=0xFE11, [0x3002]=0xFE12, [0x3016]=0xFE17, [0x3017]=0xFE18,
     [0x2026]=0xFE19,
     [0x2025]=0xFE30, [0x2014]=0xFE31, [0x2013]=0xFE32, [0xFF3F]=0xFE33,
     [0xFF08]=0xFE35, [0xFF09]=0xFE36, [0xFF5B]=0xFE37, [0xFF5D]=0xFE38,
     [0x3014]=0xFE39, [0x3015]=0xFE3A, [0x3010]=0xFE3B, [0x3011]=0xFE3C,
     [0x300A]=0xFE3D, [0x300B]=0xFE3E, [0x3008]=0xFE3F, [0x3009]=0xFE40,
     [0x300C]=0xFE41, [0x300D]=0xFE42, [0x300E]=0xFE43, [0x300F]=0xFE44,
     [0xFF3B]=0xFE47, [0xFF3D]=0xFE48, 
  }
  local function add_vform(coverage, vform, ft, add_vert)
     if type(coverage)~='table' then return end
     for i,v in pairs(vert_form_table) do
         if not coverage[i] and ft.characters[v] then
             vform[i] = v
         end
     end
     if add_vert then -- vert feature が有効にならない場合
        for i,v in pairs(coverage) do vform[i] = vform[i] or v end
     end
  end

luatexbase.add_to_callback(
   "luatexja.define_jfont",
   function (fmtable, fnum)
      local vform = {}; fmtable.vform = vform
      local t = font_getfont(fnum)
      if t.specification and t.resources then
         local add_vert  
           = not (provides_feature(fnum, t.properties.script, t.properties.language, 'vert'))
             and not (provides_feature(fnum, t.properties.script, t.properties.language, 'vrt2'))
         -- 現在の language, script で vert もvrt2 も有効にできない場合，強制的に vert 適用
         for _,i in pairs(t.resources.sequences) do
            if i.order[1]== 'vert' and i.type == 'gsub_single' and i.steps then
               for _,j in pairs(i.steps) do
                  if type(j)=='table' then add_vform(j.coverage,vform, t, add_vert) end
               end
            end
          end
      end
      return fmtable
   end, 'ltj.get_vert_form', 1
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
        local cidinfo = tfmdata.cidinfo or tfmdata.resources.cidinfo
        if cidinfo and cidinfo.registry and cidinfo.ordering then
           local rd = ltjr_prepare_cid_font(cidinfo.registry, cidinfo.ordering)
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
   local dir_tate = luatexja.dir_table.dir_tate
   if status.luatex_version>=89 then
       new_ic_kern = function(g)  return node_new(id_kern,3) end
   else
       local ITALIC       = luatexja.icflag_table.ITALIC
       new_ic_kern = function()
         local g = node_new(id_kern, 1)
         set_attr(g, attr_icflag, ITALIC)
         return g
       end
   end
   -- EXT: italic correction
   function luatexja.jfont.append_italic()
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

luatexja.jfont.metrics = metrics
luatexja.jfont.font_metric_table = font_metric_table
luatexja.jfont.find_char_class = find_char_class

luatexja.jfont.update_jfm_cache = update_jfm_cache
