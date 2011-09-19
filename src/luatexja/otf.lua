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

require('luatexja.base');      local ltjb = luatexja.base
require('luatexja.jfont');     local ltjf = luatexja.jfont

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
   if curjfnt.cidinfo.ordering ~= "Japan1" then
      ltjb.package_error('luatexja-otf',
                         'Current Japanese font "'..curjfnt.psname..'" is not a CID-Keyed font (Adobe-Japan1)', 
                         'Select a CID-Keyed font using \jfont.')
      return
   end
   local char = curjfnt.unicodes['Japan1.'..tostring(key)]
   if not char then
      ltjb.package_warning('luatexja-otf',
                         'Current Japanese font "'..curjfnt.psname..'" does not include the specified CID character ('..tostring(key)..')', 
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
		     ltjf.find_char_class(g.char, ltjf.font_metric_table[v].jfm))
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


-------------------- all done
-- EOF
