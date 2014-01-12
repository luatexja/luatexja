--
-- luatexja/ltj-pretreat.lua
--

luatexja.load_module('charrange'); local ltjc = luatexja.charrange
luatexja.load_module('stack');     local ltjs = luatexja.stack
luatexja.load_module('jfont');     local ltjf = luatexja.jfont

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
local ltjf_replace_altfont = ltjf.replace_altfont
local attr_orig_char = luatexbase.attributes['ltj@origchar']
local STCK = luatexja.userid_table.STCK

------------------------------------------------------------------------
-- MAIN PROCESS STEP 1: replace fonts
------------------------------------------------------------------------
local wt
do
   local head
   local end_math = node.end_of_math or 
      function(p)
	 while p and p.id~=id_math do p = node_next(p) end
	 return p
      end

   local suppress_hyphenate_ja_aux = {}
   suppress_hyphenate_ja_aux[id_glyph] = function(p)
      if (has_attr(p, attr_icflag) or 0)<=0 and ltjc_is_ucs_in_japanese_char(p) then
	 local pc = p.char
	 local pf = ltjf_replace_altfont(has_attr(p, attr_curjfnt) or p.font, pc)
	 p.font = pf;  set_attr(p, attr_curjfnt, pf)
	 p.subtype = floor(p.subtype*0.5)*2
	 set_attr(p, attr_orig_char, pc)
      end
      return p
   end
   suppress_hyphenate_ja_aux[id_math] = function(p) return end_math(node_next(p)) end
   suppress_hyphenate_ja_aux[id_whatsit] = function(p)
      if p.subtype==sid_user and p.user_id==STCK then
	 wt[#wt+1] = p; head = node_remove(head, p)
      end
      return p
   end

   local function suppress_hyphenate_ja (h)
      local p = h
      wt, head = {}, h
      while p do
	 local pfunc = suppress_hyphenate_ja_aux[p.id]
	 if pfunc then p = pfunc(p) end
	 p = node_next(p)
      end
      lang.hyphenate(head)
      return head
   end
   
   luatexbase.add_to_callback('hyphenate', 
			      function (head,tail)
				 return suppress_hyphenate_ja(head)
			      end,'ltj.hyphenate')
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

luatexja.pretreat = {
   set_box_stack_level = set_box_stack_level,
}
