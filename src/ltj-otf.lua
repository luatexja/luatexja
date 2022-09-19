--
-- ltj-otf.lua
--
require 'lualibs'

luatexja.load_module 'base';      local ltjb = luatexja.base
luatexja.load_module 'jfont';     local ltjf = luatexja.jfont
luatexja.load_module 'rmlgbm';    local ltjr = luatexja.rmlgbm
luatexja.load_module 'charrange'; local ltjc = luatexja.charrange
luatexja.load_module 'direction'; local ltjd = luatexja.direction
luatexja.load_module 'stack';     local ltjs = luatexja.stack
luatexja.load_module 'lotf_aux';  local ltju = luatexja.lotf_aux

local id_glyph = node.id 'glyph'
local id_whatsit = node.id 'whatsit'
local sid_user = node.subtype 'user_defined'

local setfield = node.direct.setfield
local getfield = node.direct.getfield
local getid = node.direct.getid
local getfont = node.direct.getfont
local getchar = node.direct.getchar
local getsubtype = node.direct.getsubtype
local getvalue = node.direct.getdata
local setchar = node.direct.setchar
local setfont = node.direct.setfont
local setlang = node.direct.setlang
local setvalue = node.direct.setdata

local to_node = node.direct.tonode
local to_direct = node.direct.todirect
local node_new = node.direct.new
local node_remove = node.direct.remove
local node_next = node.direct.getnext
local node_free = node.direct.flush_node or node.direct.free
local get_attr = node.direct.get_attribute
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
local font_getfont = font.getfont

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

local cache_ver = 3
local ivd_aj1 = ltjb.load_cache('ltj-ivd_aj1',
   function (t) return t.version~=cache_ver end)
if not ivd_aj1 then -- make cache
   ivd_aj1 = require('ltj-ivd_aj1.lua')
   ltjb.save_cache_luc('ltj-ivd_aj1', ivd_aj1)
end


local function get_ucs_from_rmlgbm(c)
   local v = (ivd_aj1 and ivd_aj1.table_ivd_aj1[c]
      or ltjr_cidfont_data["Adobe-Japan1"].resources.unicodes["Japan1." .. tostring(c)])
      or 0
   if v>=0x200000 then -- table
      local curjfnt = tex_get_attr(
        (ltjd_get_dir_count()==dir_tate) and attr_curtfnt or attr_curjfnt)
      local tfmdata = font_getfont(curjfnt)
      if tfmdata and tfmdata.resources then
        local base, ivs = v % 0x200000, 0xE00FF + math.floor(v/0x200000)
        curjfnt = tfmdata.resources.variants; curjfnt = curjfnt and curjfnt[ivs]
        return curjfnt and curjfnt[base] or base
      else return base
      end
   elseif v<0xF0000 then -- 素直に Unicode にマップ可能
      return v
   else -- privete use area
      local r, aj = nil, ltjr_cidfont_data["Adobe-Japan1"]
      -- 先に ltj_vert_table を見る
      for i,w in pairs(aj.ltj_vert_table) do
         if w==v then r=i; break end
      end
      if not r then
         -- なければ ToUnicode から引く
         local w = aj.characters[v].tounicode -- must be non-nil!
         local i = string.len(w)
         if i==4 then -- UCS2
            r = tonumber(w,16)
         elseif i==8 then
            i,w = tonumber(string.sub(w,1,4),16), tonumber(string.sub(w,-4),16)
            if (w>=0xD800) and (w<=0xDB7F) and (i>=0xDC00) and (i<=0xDFFF) then -- Surrogate pair
               r = (w-0xD800)*0x400 + (i-0xDC00)
            else
               r = 0
            end
         end
      end
      if aj.ltj_vert_table[r] then
         -- CID が縦組用字形だった場合
         return ltju.replace_vert_variant(
            tex_get_attr((ltjd_get_dir_count()==dir_tate) and attr_curtfnt or attr_curjfnt),
            r)
      end
      return r
   end
end

-- Append a whatsit node to the list.
-- This whatsit node will be extracted to a glyph_node
local function append_jglyph(char)
   local p = node_new(id_whatsit,sid_user)
   setfield(p, 'user_id', OTF); setfield(p, 'type', 100)
   setvalue(p, char);  node_write(p)
end

local myutf
do
   myutf = function (ucs)
      if ltjd_get_dir_count()==dir_tate then
         ucs = ltju.replace_vert_variant(
            tex_get_attr((ltjd_get_dir_count()==dir_tate) and attr_curtfnt or attr_curjfnt),
            ucs)
      end
      return append_jglyph(ucs)
   end
end

local cid
do
   local ord = {
      ['Japan1']=true, ['GB1']=true, ['CNS1']=true, ['Korea1']=true, ['KR']=true
   }
   cid = function (key)
      if key==0 then return append_jglyph(0) end
      local curjfnt = tex_get_attr(
         (ltjd_get_dir_count()==dir_tate) and attr_curtfnt or attr_curjfnt)
      local cidinfo = ltju.get_cidinfo(curjfnt)
      if type(cidinfo)~="table" or not ord[cidinfo.ordering] then
            return append_jglyph(get_ucs_from_rmlgbm(key))
      else
         local char = ltjf_font_extra_info[curjfnt].ind_to_uni[key] or 0
         return append_jglyph(char)
      end
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
               local g = node_new(id_glyph, 0)
               setfont(g, get_attr(p, attr_curfnt), getvalue(p))
               setlang(g, lang_ja)
               set_attr(g, attr_kblshift, get_attr(p, attr_kblshift))
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

-- 和文フォント読み込み時に，ind -> unicode 対応をとっておく．
local function ind_to_uni(fmtable, fn)
   if fn<0 then return end
   local cid = ltju.get_cidinfo(fn)
   local t = ltjf_font_extra_info[fn]; t = t and t.ind_to_uni
   if t and cid.ordering == "Japan1" then
      for i, v in pairs(fmtable.chars) do
         local j = string.match(i, "^AJ1%-([0-9]*)")
         if j then
            j = t[tonumber(j)]
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
                           ind_to_uni, "ltj.otf.define_jfont", 1)
--  既に読み込まれているフォントに対しても，同じことをやらないといけない
for fn, v in pairs(ltjf_font_metric_table) do
   ltjf_font_metric_table[fn] = ind_to_uni(v, fn)
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
  enable_ivs = enable_ivs, disable_ivs = disable_ivs,
  cid = cid, utf = myutf,
}


-- EOF
