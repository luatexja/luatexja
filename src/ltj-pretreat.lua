--
-- luatexja/ltj-pretreat.lua
--

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
local fonts_ids = fonts.ids

local id_glyph = node.id('glyph')
local id_math = node.id('math')
local id_whatsit = node.id('whatsit')
local sid_user = node.subtype('user_defined')

local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_icflag = luatexbase.attributes['ltj@icflag']

local ltjf_font_metric_table = ltjf.font_metric_table
local ltjc_is_ucs_in_japanese_char = ltjc.is_ucs_in_japanese_char
local attr_orig_char = luatexbase.attributes['ltj@origchar']
local STCK = luatexja.userid_table.STCK

local fwglyph = {
   ["Japan1"] = {
      [0x00A4] = 16280,
      [0x00A9] =  8059,
      [0x00AC] =  8008,
      [0x00AE] =  8060,
      [0x00B5] = 12093,
      [0x00BC] =  8185,
      [0x00BD] =  8184,
      [0x00BE] =  9783,
      [0x2012] = 16206,
      [0x201C] =   672,
      [0x201D] =   673,
      [0x201E] =  8280,
      [0x2022] = 12256,
      [0x2026] =   668,
      [0x20AC] =  9779,
      [0x2122] = 11853,
      [0x2127] = 16204,
      [0x2153] =  9781,
      [0x2154] =  9782,
      [0x2155] =  9784,
      [0x215B] =  9796,
      [0x215C] =  9797,
      [0x215D] =  9798,
      [0x215E] =  9799,
      [0x2209] = 16299,
      [0x2225] = 16196,
      [0x2226] = 16300,
      [0x2245] = 16301,
      [0x2248] = 16302,
      [0x2262] = 16303,
      [0x2276] = 16304,
      [0x2277] = 16305,
      [0x2284] = 16306,
      [0x2285] = 16307,
      [0x228A] = 16308,
      [0x228B] = 16309,
      [0x22DA] = 16310,
      [0x22DB] = 16311,
      [0x2318] = 16271,
   }
}


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
	    local pf = has_attr(p, attr_curjfnt) or p.font
	    p.font = pf
	    p.subtype = floor(p.subtype*0.5)*2
	    set_attr(p, attr_orig_char, p.char)
	    local pfd = fonts_ids[pf]
	    if ltjf_font_metric_table[pf] and ltjf_font_metric_table[pf].mono_flag then
	       local pco = pfd.cidinfo.ordering
	       for i,v in pairs(fwglyph) do
		  if pco == i and pfd.resources then
		     local fwc = pfd.resources.unicodes[pco .. '.'.. tostring(v[p.char])]
		     if fwc then p.char = fwc end
		     break
		  end
	       end
	    end
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
