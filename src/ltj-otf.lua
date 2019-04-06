--
-- luatexja/ltj-otf.lua
--
require('unicode')
require('lualibs')

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('jfont');     local ltjf = luatexja.jfont
luatexja.load_module('rmlgbm');    local ltjr = luatexja.rmlgbm
luatexja.load_module('charrange'); local ltjc = luatexja.charrange
luatexja.load_module('direction'); local ltjd = luatexja.direction
luatexja.load_module('stack');     local ltjs = luatexja.stack

local id_glyph = node.id('glyph')
local id_whatsit = node.id('whatsit')
local sid_user = node.subtype('user_defined')

local setfield = node.direct.setfield
local getfield = node.direct.getfield
local getid = node.direct.getid
local getfont = node.direct.getfont
local getchar = node.direct.getchar
local getsubtype = node.direct.getsubtype

local to_node = node.direct.tonode
local to_direct = node.direct.todirect

local node_new = node.direct.new
local node_remove = node.direct.remove
local node_next = node.direct.getnext
local node_free = node.direct.free
local has_attr = node.direct.has_attribute
local set_attr = node.direct.set_attribute
local unset_attr = node.direct.unset_attribute
local node_insert_after = node.direct.insert_after
local node_write = node.direct.write
local node_traverse_id = node.direct.traverse_id


local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_curtfnt = luatexbase.attributes['ltj@curtfnt']
local attr_yablshift = luatexbase.attributes['ltj@yablshift']
local attr_ykblshift = luatexbase.attributes['ltj@ykblshift']
local attr_tablshift = luatexbase.attributes['ltj@tablshift']
local attr_tkblshift = luatexbase.attributes['ltj@tkblshift']
local lang_ja = luatexja.lang_ja
local identifiers = fonts.hashes.identifiers

local ltjf_font_metric_table = ltjf.font_metric_table
local ltjf_font_extra_info = ltjf.font_extra_info
local ltjf_find_char_class = ltjf.find_char_class
local ltjr_cidfont_data = ltjr.cidfont_data
local ltjc_is_ucs_in_japanese_char = ltjc.is_ucs_in_japanese_char
local ltjd_get_dir_count = ltjd.get_dir_count
local dir_tate = luatexja.dir_table.dir_tate

luatexja.userid_table.OTF = luatexbase.newuserwhatsitid('char_by_cid',  'luatexja')
local OTF = luatexja.userid_table.OTF
local tex_get_attr = tex.getattribute

local cache_var = 2
local cache_outdate_fn = function (t) return t.version~=cache_ver end
local ivd_aj1 = ltjb.load_cache('ltj-ivd_aj1',cache_outdate_fn)
if not ivd_aj1 then -- make cache
   ivd_aj1 = require('ltj-ivd_aj1.lua')
   ltjb.save_cache_luc('ltj-ivd_aj1', ivd_aj1)
end


local function get_ucs_from_rmlgbm(c)
   local v = (ivd_aj1 and ivd_aj1.table_ivd_aj1[c]
     or ltjr_cidfont_data["Adobe-Japan1"].resources.unicodes["Japan1." .. tostring(c)])
     or 0
   if v>=0x200000 then -- table
      local curjfnt_num = tex_get_attr((ltjd_get_dir_count()==dir_tate)
                                        and attr_curtfnt or attr_curjfnt)
      local curjfnt = identifiers[curjfnt_num].resources
      local base, ivs = v % 0x200000, 0xE00FF + math.floor(v/0x200000)
      curjfnt = curjfnt and curjfnt.variants
      curjfnt = curjfnt and curjfnt[ivs]
      return curjfnt and curjfnt[base] or base
   elseif v<0xF0000 then -- 素直に Unicode にマップ可能
      return v
   else -- privete use area
      local w = ltjr_cidfont_data["Adobe-Japan1"].characters[v]. tounicode
      -- must be non-nil!
      local i = string.len(w)
      if i==4 then -- UCS2
         return tonumber(w,16)
      elseif i==8 then
         i,w = tonumber(string.sub(w,1,4),16), tonumber(string.sub(w,-4),16)
         if (w>=0xD800) and (w<=0xDB7F) and (i>=0xDC00) and (i<=0xDFFF) then -- Surrogate pair
            return (w-0xD800)*0x400 + (i-0xDC00)
         else
            return 0
         end
      end
   end
end

-- Append a whatsit node to the list.
-- This whatsit node will be extracted to a glyph_node
local function append_jglyph(char)
   local p = node_new(id_whatsit,sid_user)
   setfield(p, 'user_id', OTF)
   setfield(p, 'type', 100)
   setfield(p, 'value', char)
   node_write(p)
end

local cid
do
   cid = function (key)
      if key==0 then return append_jglyph(char) end
      local curjfnt_num = tex_get_attr((ltjd_get_dir_count()==dir_tate)
                                        and attr_curtfnt or attr_curjfnt)
      local curjfnt = identifiers[curjfnt_num]
      local cidinfo = curjfnt.resources.cidinfo
      if not cidinfo or
         cidinfo.ordering ~= "Japan1" and
         cidinfo.ordering ~= "GB1" and
         cidinfo.ordering ~= "CNS1" and
         cidinfo.ordering ~= "Korea1" and
         cidinfo.ordering ~= "KR" then
         --      ltjb.package_warning('luatexja-otf',
         --			   'Current Japanese font (or other CJK font) "'
         --			      ..curjfnt.psname..'" is not a CID-Keyed font (Adobe-Japan1 etc.)')
            return append_jglyph(get_ucs_from_rmlgbm(key))
      end
      local fe, char = ltjf_font_extra_info[curjfnt_num], nil
      if fe and fe.unicodes then 
         char = fe.unicodes[cidinfo.ordering..'.'..tostring(key)]
      end
      if not char then
         ltjb.package_warning('luatexja-otf',
                              'Current Japanese font (or other CJK font) "'
                                 ..curjfnt.psname..'" does not have the specified CID character ('
                                 ..tostring(key)..')',
                              'Use a font including the specified CID character.')
         char = 0
      end
      return append_jglyph(char)
   end
end

local function extract(head)
   head = to_direct(head)
   local p = head
   local is_dir_tate = ltjs.list_dir == dir_tate
   local attr_ablshift = is_dir_tate and attr_tablshift or attr_yablshift
   local attr_kblshift = is_dir_tate and attr_tkblshift or attr_ykblshift
   local attr_curfnt =   is_dir_tate and attr_curtfnt or attr_curjfnt
   while p do
      if getid(p)==id_whatsit then
         if getsubtype(p)==sid_user then
            local puid = getfield(p, 'user_id')
            if puid==OTF then
            --if puid==OTF or puid==VSR then
               local g = node_new(id_glyph)
               setfield(g, 'subtype', 0)
	       setfield(g, 'char', getfield(p, 'value'))
               local v = has_attr(p, attr_curfnt); setfield(g, 'font',v)
               --if puid==OTF then
                  setfield(g, 'lang', lang_ja)
                  set_attr(g, attr_kblshift, has_attr(p, attr_kblshift))
               --else
               --   set_attr(g, attr_ablshift, has_attr(p, attr_ablshift))
               --end
               head = node_insert_after(head, p, g)
               head = node_remove(head, p)
               node_free(p); p = g
            end
         end
      end
      p = node_next(p)
   end
   return to_node(head)
end

ltjb.add_to_callback('hpack_filter', extract,'ltj.otf',
  luatexbase.priority_in_callback('hpack_filter', 'ltj.main'))
ltjb.add_to_callback('pre_linebreak_filter', extract,'ltj.otf',
  luatexbase.priority_in_callback('pre_linebreak_filter', 'ltj.main'))
-- additional callbacks
-- 以下は，LuaTeX-ja に用意された callback のサンプルになっている．
--   JFM の文字クラスの指定の所で，"AJ1-xxx" 形式での指定を可能とした．
--   これらの文字指定は，和文フォント定義ごとに，それぞれのフォントの
--   CID <-> グリフ 対応状況による変換テーブルが用意される．

-- 和文フォント読み込み時に，CID -> unicode 対応をとっておく．
local function cid_to_char(fmtable, fn)
   local fi = identifiers[fn]
   local fe = ltjf_font_extra_info[fn]
   if (fi.resources and fi.resources.cidinfo and fi.resources.cidinfo.ordering == "Japan1" )
      and (fe and fe.unicodes) then
      for i, v in pairs(fmtable.chars) do
	 local j = string.match(i, "^AJ1%-([0-9]*)")
	 if j then
	    j = tonumber(fe.unicodes['Japan1.'..tostring(j)])
	    if j then
	       fmtable.cid_char_type = fmtable.cid_char_type  or {}
	       fmtable.cid_char_type[j] = v
	    end
	 end
      end
   end
   return fmtable
end
luatexbase.add_to_callback("luatexja.define_jfont",
			   cid_to_char, "ltj.otf.define_jfont", 1)
--  既に読み込まれているフォントに対しても，同じことをやらないといけない
for fn, v in pairs(ltjf_font_metric_table) do
   ltjf_font_metric_table[fn] = cid_to_char(v, fn)
end


local function cid_set_char_class(arg, fmtable, char)
   if arg~=0 then return arg
   elseif fmtable.cid_char_type then
      return fmtable.cid_char_type[char] or 0
   else return 0
   end
end
luatexbase.add_to_callback("luatexja.find_char_class",
			   cid_set_char_class, "ltj.otf.find_char_class", 1)

--IVS
local function enable_ivs()
  ltjb.package_warning('luatexja-otf',
    'luatexja.otf.enable_ivs() has now no effect.')
end
local disable_ivs = enable_ivs

luatexja.otf = {
  append_jglyph = append_jglyph,
  enable_ivs = enable_ivs,  -- 隠し機能: IVS
  disable_ivs = disable_ivs,  -- 隠し機能: IVS
  cid = cid,
}


-- EOF
