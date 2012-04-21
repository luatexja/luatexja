--
-- luatexja/pretreat.lua
--
luatexbase.provides_module({
  name = 'luatexja.pretreat',
  date = '2011/06/27',
  version = '0.1',
  description = '',
})
module('luatexja.pretreat', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

luatexja.load_module('charrange'); local ltjc = luatexja.charrange
luatexja.load_module('jfont');     local ltjf = luatexja.jfont
luatexja.load_module('stack');     local ltjs = luatexja.stack

local has_attr = node.has_attribute
local set_attr = node.set_attribute
local unset_attr = node.unset_attribute
local node_type = node.type
local node_remove = node.remove
local node_next = node.next
local node_free = node.free

local id_glyph = node.id('glyph')
local id_math = node.id('math')
local id_whatsit = node.id('whatsit')
local sid_user = node.subtype('user_defined')

local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_yablshift = luatexbase.attributes['ltj@yablshift']
local attr_ykblshift = luatexbase.attributes['ltj@ykblshift']

local ltjf_font_metric_table = ltjf.font_metric_table

------------------------------------------------------------------------
-- MAIN PROCESS STEP 1: replace fonts
------------------------------------------------------------------------
box_stack_level = 0
-- This is used in jfmglue.lua.

local function suppress_hyphenate_ja(head)
   local non_math = true
   for p in node.traverse(head) do
      if p.id == id_glyph and non_math then
	 local i = has_attr(p, attr_icflag) or 0
	 if i==0 and ltjc.is_ucs_in_japanese_char(p) then
	    local v = has_attr(p, attr_curjfnt)
	    if v then 
	       p.font = v 
	    end
	    v = has_attr(p, attr_ykblshift)
	    if v then 
	       set_attr(p, attr_yablshift, v)
	    else
	       unset_attr(p, attr_yablshift)
	    end
	    if p.subtype%2==1 then p.subtype = p.subtype - 1 end
	    -- p.lang=lang_ja
	 end
      elseif p.id == id_math then 
	 non_math = (p.subtype ~= 0)
      end
   end
   lang.hyphenate(head)
   return head
end

-- mode: true iff this function is called from hpack_filter
function set_box_stack_level(head, mode)
   local box_set = false
   local p = head
   local cl = tex.currentgrouplevel + 1
   for p in node.traverse_id(id_whatsit, head) do
      if p.subtype==sid_user and p.user_id==30112 then
	 local g = p
	 if mode and g.value==cl then box_set = true end
	 head, p = node_remove(head, g); node_free(g); break
      end
   end
   if box_set then 
      box_stack_level = tex.getcount('ltj@@stack') + 1 
   else 
      box_stack_level = tex.getcount('ltj@@stack') 
   end
   return head
end

-- CALLBACKS
luatexbase.add_to_callback('hpack_filter', 
   function (head)
     return set_box_stack_level(head, true)
   end,'ltj.hpack_filter_pre',1)
luatexbase.add_to_callback('pre_linebreak_filter', 
  function (head)
     return set_box_stack_level(head, false)
  end,'ltj.pre_linebreak_filter_pre',1)
luatexbase.add_to_callback('hyphenate', 
 function (head,tail)
    return suppress_hyphenate_ja(head)
 end,'ltj.hyphenate')
