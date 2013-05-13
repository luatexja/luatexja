--
-- luatexja/ltj-pretreat.lua
--

luatexja.load_module('charrange'); local ltjc = luatexja.charrange
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

local ltjc_is_ucs_in_japanese_char = ltjc.is_ucs_in_japanese_char
local attr_orig_char = luatexbase.attributes['ltj@origchar']
local STCK = luatexja.userid_table.STCK

------------------------------------------------------------------------
-- MAIN PROCESS STEP 1: replace fonts
------------------------------------------------------------------------
local wt

local function suppress_hyphenate_ja(head)
   local non_math, p = true, head
   wt = {}
   while p do
      local pid = p.id
      if pid == id_glyph then
	 if (has_attr(p, attr_icflag) or 0)<=0 and ltjc_is_ucs_in_japanese_char(p) then
	    p.font = has_attr(p, attr_curjfnt) or p.font
	    p.subtype = floor(p.subtype*0.5)*2
	    set_attr(p, attr_orig_char, p.char)
	 end
      elseif pid == id_math then 
	 p = node_next(p) -- skip math on
	 while p and p.id~=id_math do p = node_next(p) end
      elseif pid == id_whatsit and p.subtype==sid_user and p.user_id==STCK then
	 wt[#wt+1] = p; head = node_remove(head, p)
      end
      p = node_next(p)
   end
   lang.hyphenate(head)
   return head
end

-- mode: true iff this function is called from hpack_filter
local function set_box_stack_level(head, mode)
   local box_set, cl = 0, tex.currentgrouplevel + 1
   for _,p  in pairs(wt) do
      if mode and p.value==cl then box_set = 1 end; node_free(p)
   end
   ltjs.report_stack_level(tex_getcount('ltj@@stack') + box_set)
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

luatexja.pretreat = {
   set_box_stack_level = set_box_stack_level,
}
