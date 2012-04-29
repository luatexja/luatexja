--
-- luatexja/otf.lua
--
luatexbase.provides_module({
  name = 'luatexja.otf',
  date = '2011/09/09',
  version = '0.1',
  description = 'The OTF Lua module for LuaTeX-ja',
})
module('luatexja.otf', package.seeall)

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('jfont');     local ltjf = luatexja.jfont

local id_glyph = node.id('glyph')
local id_whatsit = node.id('whatsit')
local sid_user = node.subtype('user_defined')

local node_new = node.new
local node_remove = node.remove
local node_next = node.next
local node_free = node.free
local has_attr = node.has_attribute
local set_attr = node.set_attribute
local unset_attr = node.unset_attribute
local node_insert_after = node.insert_after

local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_yablshift = luatexbase.attributes['ltj@yablshift']
local attr_ykblshift = luatexbase.attributes['ltj@ykblshift']

local ltjf_font_metric_table = ltjf.font_metric_table
local ltjf_find_char_class = ltjf.find_char_class


-- Append a whatsit node to the list.
-- This whatsit node will be extracted to a glyph_node
function append_jglyph(char)
   local p = node_new(id_whatsit,sid_user)
   local v = tex.attribute[attr_curjfnt]
   p.user_id=30113; p.type=100; p.value=char
   set_attr(p, attr_yablshift, tex.attribute[attr_ykblshift])
   node.write(p)
end

function cid(key)
   local curjfnt = fonts.ids[tex.attribute[attr_curjfnt]]
   if curjfnt.cidinfo.ordering ~= "Japan1" and
	   curjfnt.cidinfo.ordering ~= "GB1" and
	   curjfnt.cidinfo.ordering ~= "CNS1" and
	   curjfnt.cidinfo.ordering ~= "Korea1" then
      ltjb.package_error('luatexja-otf',
                         'Current Japanese font (or other CJK font) "'..curjfnt.psname..'" is not a CID-Keyed font (Adobe-Japan1 etc.)', 
                         'Select a CID-Keyed font using \jfont.')
      return
   end
   local char = curjfnt.unicodes[curjfnt.cidinfo.ordering..'.'..tostring(key)]
   if not char then
      ltjb.package_warning('luatexja-otf',
                         'Current Japanese font (or other CJK font) "'..curjfnt.psname..'" does not include the specified CID character ('..tostring(key)..')', 
                         'Use a font including the specified CID character.')
      return
   end
   append_jglyph(char)
end

function extract(head)
   local p = head, v
   while p do
      if p.id==id_whatsit then
	 if p.subtype==sid_user and p.user_id==30113 then
	    local g = node_new(id_glyph)
	    g.subtype = 0; g.char = p.value
	    v = has_attr(p, attr_curjfnt); g.font = v
	    set_attr(g, attr_jchar_class,
		     ltjf_find_char_class(g.char, ltjf_font_metric_table[v]))
	    set_attr(g, attr_curjfnt, v)
	    v = has_attr(p, attr_yablshift)
	    if v then 
	       set_attr(g, attr_yablshift, v)
	    else
	       unset_attr(g, attr_yablshift)
	    end
	    head = node_insert_after(head, p, g)
	    head = node_remove(head, p)
	    node_free(p); p = g
	 end
      end
      p = node_next(p)
   end
   return head
end

luatexbase.add_to_callback('hpack_filter', 
   function (head) return extract(head) end,'ltj.hpack_filter_otf',
   luatexbase.priority_in_callback('pre_linebreak_filter',
				   'ltj.pre_linebreak_filter'))
luatexbase.add_to_callback('pre_linebreak_filter', 
   function (head) return extract(head) end, 'ltj.pre_linebreak_filter_otf',
   luatexbase.priority_in_callback('pre_linebreak_filter',
				   'ltj.pre_linebreak_filter'))


-- additional callbacks
-- 以下は，LuaTeX-ja に用意された callback のサンプルになっている．
--   JFM の文字クラスの指定の所で，"AJ1-xxx" 形式での指定を可能とした．
--   これらの文字指定は，和文フォント定義ごとに，それぞれのフォントの
--   CID <-> グリフ 対応状況による変換テーブルが用意される．

-- フォント読み込み時に，CID
local function cid_to_char(fmtable, fn)
   local fi = fonts.ids[fn]
   if fi.cidinfo and fi.cidinfo.ordering == "Japan1" then
      fmtable.cid_char_type = {}
      for i, v in pairs(ltjf.metrics[fmtable.jfm].chars) do
	 local j = string.match(i, "^AJ1%-([0-9]*)")
	 if j then
	    j = tonumber(fi.unicodes['Japan1.'..tostring(j)])
	    if j then
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

-------------------- all done
-- EOF
