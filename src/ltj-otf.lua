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

local Dnode = node.direct or node

local setfield = (Dnode ~= node) and Dnode.setfield or function(n, i, c) n[i] = c end
local getfield = (Dnode ~= node) and Dnode.getfield or function(n, i) return n[i] end
local getid = (Dnode ~= node) and Dnode.getid or function(n) return n.id end
local getfont = (Dnode ~= node) and Dnode.getfont or function(n) return n.font end
--local getlist = (Dnode ~= node) and Dnode.getlist or function(n) return n.head end
local getchar = (Dnode ~= node) and Dnode.getchar or function(n) return n.char end
local getsubtype = (Dnode ~= node) and Dnode.getsubtype or function(n) return n.subtype end

local nullfunc = function(n) return n end
local to_node = (Dnode ~= node) and Dnode.tonode or nullfunc
local to_direct = (Dnode ~= node) and Dnode.todirect or nullfunc

local node_new = Dnode.new
local node_remove = Dnode.remove
local node_next = (Dnode ~= node) and Dnode.getnext or node.next
local node_free = Dnode.free
local has_attr = Dnode.has_attribute
local set_attr = Dnode.set_attribute
local unset_attr = Dnode.unset_attribute
local node_insert_after = Dnode.insert_after
local node_write = Dnode.write
local node_traverse_id = Dnode.traverse_id


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
luatexja.userid_table.VSR = luatexbase.newuserwhatsitid('replace_vs',  'luatexja')
local OTF, VSR = luatexja.userid_table.OTF, luatexja.userid_table.VSR

local function get_ucs_from_rmlgbm(c)
   local v = ltjr_cidfont_data["Adobe-Japan1"].resources.unicodes["Japan1." .. tostring(c)]
   if not v then -- AJ1 範囲外
      return 0
   elseif v<0xF0000 then -- 素直に Unicode にマップ可能
      return v
   else
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
   local tex_get_attr = tex.getattribute
   cid = function (key)
      if key==0 then return append_jglyph(char) end
      local curjfnt = identifiers[tex_get_attr((ltjd_get_dir_count()==dir_tate)
                                                  and attr_curtfnt or attr_curjfnt)]
      if not curjfnt.cidinfo or
         curjfnt.cidinfo.ordering ~= "Japan1" and
         curjfnt.cidinfo.ordering ~= "GB1" and
         curjfnt.cidinfo.ordering ~= "CNS1" and
         curjfnt.cidinfo.ordering ~= "Korea1" then
         --      ltjb.package_warning('luatexja-otf',
         --			   'Current Japanese font (or other CJK font) "'
         --			      ..curjfnt.psname..'" is not a CID-Keyed font (Adobe-Japan1 etc.)')
            return append_jglyph(get_ucs_from_rmlgbm(key))
      end
      local char = curjfnt.resources.unicodes[curjfnt.cidinfo.ordering..'.'..tostring(key)]
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
            if puid==OTF or puid==VSR then
               local g = node_new(id_glyph)
               setfield(g, 'subtype', 0)
	       setfield(g, 'char', getfield(p, 'value'))
               local v = has_attr(p, attr_curfnt); setfield(g, 'font',v)
               if puid==OTF then
                  setfield(g, 'lang', lang_ja)
                  set_attr(g, attr_kblshift, has_attr(p, attr_kblshift))
               else
                  set_attr(g, attr_ablshift, has_attr(p, attr_ablshift))
               end
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

luatexbase.add_to_callback('hpack_filter', extract,
			   'ltj.hpack_filter_otf',
   luatexbase.priority_in_callback('pre_linebreak_filter',
				   'ltj.pre_linebreak_filter'))
luatexbase.add_to_callback('pre_linebreak_filter', extract,
			   'ltj.pre_linebreak_filter_otf',
   luatexbase.priority_in_callback('pre_linebreak_filter',
				   'ltj.pre_linebreak_filter'))


-- additional callbacks
-- 以下は，LuaTeX-ja に用意された callback のサンプルになっている．
--   JFM の文字クラスの指定の所で，"AJ1-xxx" 形式での指定を可能とした．
--   これらの文字指定は，和文フォント定義ごとに，それぞれのフォントの
--   CID <-> グリフ 対応状況による変換テーブルが用意される．

-- 和文フォント読み込み時に，CID -> unicode 対応をとっておく．
local function cid_to_char(fmtable, fn)
   local fi = identifiers[fn]
   if fi.cidinfo and fi.cidinfo.ordering == "Japan1" then
      for i, v in pairs(fmtable.chars) do
	 local j = string.match(i, "^AJ1%-([0-9]*)")
	 if j then
	    j = tonumber(fi.resources.unicodes['Japan1.'..tostring(j)])
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

-------------------- IVS
local enable_ivs
do
   local is_ivs_enabled = false
-- 組版時
   local function ivs_jglyph(char, bp, pf, uid)
      local p = node_new(id_whatsit,sid_user)
      setfield(p, 'user_id', uid)
      setfield(p, 'type', 100)
      setfield(p, 'value', char)
      return p
   end

   local function do_ivs_repr(head)
      head = to_direct(head)
      local p, r = head
      local is_dir_tate = ltjs.list_dir == dir_tate
      local attr_ablshift = is_dir_tate and attr_tablshift or attr_yablshift
      local attr_kblshift = is_dir_tate and attr_tkblshift or attr_ykblshift
      local attr_curfnt =   is_dir_tate and attr_curtfnt or attr_curjfnt
      while p do
	 local pid = getid(p)
	 if pid==id_glyph then
            local pf = getfont(p)
            local q = node_next(p) -- the next node of p
            if q and getid(q)==id_glyph then
               local qc = getchar(q)
               if (qc>=0xFE00 and qc<=0xFE0F) or (qc>=0xE0100 and qc<0xE01F0) then
                  -- q is a variation selector
                  if qc>=0xE0100 then qc = qc - 0xE0100 end
                  local pt = ltjf_font_extra_info[pf]
                  pt = pt and pt[getchar(p)];  pt = pt and  pt[qc]
                  head, r = node_remove(head,q)
		  node_free(q)
                  if pt then
		     local is_jachar = (getfield(p, 'lang')==lang_ja)
                     local np = ivs_jglyph(pt, p, pf,
                                           is_jachar and OTF or VSR)
		     if is_jachar then
			set_attr(np, attr_curfnt, pf)
			set_attr(np, attr_kblshift, has_attr(p, attr_kblshift))
		     end
                     head = node_insert_after(head, p, np)
                     head = node_remove(head,p)
		     node_free(p)
                  end
		  p = r
	       else
		  p = q
               end
	    else
	       p = node_next(p)
            end
	 else
	    p = node_next(p)
         end
      end
      return to_node(head)
   end

   enable_ivs = function ()
      if is_ivs_enabled then
	 ltjb.package_warning('luatexja-otf',
			      'luatexja.otf.enable_ivs() was already called, so this call is ignored', '')
      else
	 luatexbase.add_to_callback('hpack_filter',
				    do_ivs_repr,'do_ivs', 
				    luatexbase.priority_in_callback('hpack_filter',
								    'ltj.hpack_filter_pre')+1)
	 luatexbase.add_to_callback('pre_linebreak_filter',
				    do_ivs_repr, 'do_ivs', 
				    luatexbase.priority_in_callback('pre_linebreak_filter',
								    'ltj.pre_linebreak_filter_pre')+1)
	 is_ivs_enabled = true
      end
   end
end

luatexja.otf = {
  append_jglyph = append_jglyph,
  enable_ivs = enable_ivs,  -- 隠し機能: IVS
  cid = cid,
}

-- EOF
