--
-- luatexja/pretreat.lua
--
luatexbase.provides_module({
  name = 'luatexja.pretreat',
  date = '2012/07/19',
  version = '0.2',
  description = '',
})
module('luatexja.pretreat', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

luatexja.load_module('charrange'); local ltjc = luatexja.charrange
luatexja.load_module('jfont');     local ltjf = luatexja.jfont
luatexja.load_module('stack');     local ltjs = luatexja.stack

local floor = math.floor
local has_attr = node.has_attribute
local set_attr = node.set_attribute
local node_traverse = node.traverse
local node_type = node.type
local node_remove = node.remove
local node_next = node.next
local node_free = node.free
local tex_getcount = tex.getcount

local id_glyph = node.id('glyph')
local id_math = node.id('math')
local id_whatsit = node.id('whatsit')
local sid_user = node.subtype('user_defined')

local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_icflag = luatexbase.attributes['ltj@icflag']

local ltjf_font_metric_table = ltjf.font_metric_table
local ltjc_is_ucs_in_japanese_char = ltjc.is_ucs_in_japanese_char
local attr_orig_char = luatexbase.attributes['ltj@origchar']

------------------------------------------------------------------------
-- MAIN PROCESS STEP 1: replace fonts
------------------------------------------------------------------------
box_stack_level = 0
-- This is used in jfmglue.lua.

local function suppress_hyphenate_ja(head)
   local non_math, p = true, nil
   for p in node_traverse(head) do
      if p.id == id_glyph and non_math then
	 if (has_attr(p, attr_icflag) or 0)<=0 and ltjc_is_ucs_in_japanese_char(p) then
	    p.font = has_attr(p, attr_curjfnt) or p.font
	    p.subtype = floor(p.subtype*0.5)*2
	    set_attr(p, attr_orig_char, p.char)
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
   box_stack_level = tex_getcount('ltj@@stack') + (box_set and 1 or 0)
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
