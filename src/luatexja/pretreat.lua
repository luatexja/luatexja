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

require('luatexja.charrange'); local ltjc = luatexja.charrange
require('luatexja.jfont');     local ltjf = luatexja.jfont
require('luatexja.stack');     local ltjs = luatexja.stack

local has_attr = node.has_attribute
local set_attr = node.set_attribute
local unset_attr = node.unset_attribute
local node_remove = node.remove
local node_next = node.next

local id_glyph = node.id('glyph')
local id_whatsit = node.id('whatsit')
local sid_user = node.subtype('user_defined')

local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_yablshift = luatexbase.attributes['ltj@yablshift']
local attr_ykblshift = luatexbase.attributes['ltj@ykblshift']

local lang_ja_token = token.create('ltj@japanese')
local lang_ja = lang_ja_token[2]

------------------------------------------------------------------------
-- MAIN PROCESS STEP 1: replace fonts
------------------------------------------------------------------------
box_stack_level = 0
-- This is used in jfmglue.lua.

local function suppress_hyphenate_ja(head)
   for p in node.traverse_id(id_glyph, head) do
      if ltjc.is_ucs_in_japanese_char(p) then
	 local v = has_attr(p, attr_curjfnt)
	 if v then 
	    p.font = v 
	    set_attr(p, attr_jchar_class,
		     ltjf.find_char_class(p.char, ltjf.font_metric_table[v].jfm))
	 end
	 v = has_attr(p, attr_ykblshift)
	 if v then 
	    set_attr(p, attr_yablshift, v)
	 else
	    unset_attr(p, attr_yablshift)
	 end
         if p.subtype%2==1 then p.subtype = p.subtype - 1 end
	 p.lang=lang_ja
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
	 head, p = node_remove(head, g); break
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
