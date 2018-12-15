--
-- luatexja/ltj-pretreat.lua
--

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('charrange'); local ltjc = luatexja.charrange
luatexja.load_module('stack');     local ltjs = luatexja.stack
luatexja.load_module('jfont');     local ltjf = luatexja.jfont
luatexja.load_module('direction'); local ltjd = luatexja.direction

local to_node =  node.direct.tonode
local to_direct =  node.direct.todirect

local setfield =  node.direct.setfield
local getid =  node.direct.getid
local getfont =  node.direct.getfont
local getchar =  node.direct.getchar
local getfield =  node.direct.getfield
local getsubtype =  node.direct.getsubtype
local getlang = node.direct.getlang or function (n) return getfield(n,'lang') end

local pairs = pairs
local floor = math.floor
local has_attr = node.direct.has_attribute
local set_attr = node.direct.set_attribute
local node_traverse = node.direct.traverse
local node_remove = node.direct.remove
local node_next =  node.direct.getnext
local node_free = node.direct.free
local node_end_of_math = node.direct.end_of_math
local tex_getcount = tex.getcount

local id_glyph = node.id('glyph')
local id_math = node.id('math')
local id_whatsit = node.id('whatsit')
local sid_user = node.subtype('user_defined')

local attr_dir = luatexbase.attributes['ltj@dir']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_curtfnt = luatexbase.attributes['ltj@curtfnt']
local attr_icflag = luatexbase.attributes['ltj@icflag']

local is_ucs_in_japanese_char = ltjc.is_ucs_in_japanese_char_direct
local ltjs_orig_char_table = ltjs.orig_char_table
local ltjf_replace_altfont = ltjf.replace_altfont
--local ltjf_font_extra_info = ltjf.font_extra_info
local attr_orig_char = luatexbase.attributes['ltj@origchar']
local STCK  = luatexja.userid_table.STCK
local DIR   = luatexja.userid_table.DIR
local PROCESSED_BEGIN_FLAG = luatexja.icflag_table.PROCESSED_BEGIN_FLAG

local dir_tate = luatexja.dir_table.dir_tate
local lang_ja = luatexja.lang_ja

local setlang = node.direct.setlang or function(n,l) setfield(n,'lang',l) end 
local setfont = node.direct.setfont or function(n,l) setfield(n,'font',l) end 
local setchar = node.direct.setchar or function(n,l) setfield(n,'char',l) end 

------------------------------------------------------------------------
-- MAIN PROCESS STEP 1: replace fonts
------------------------------------------------------------------------
local wt, wtd = {}, {}
do
   local ltjd_get_dir_count = ltjd.get_dir_count
   local start_time_measure, stop_time_measure
      = ltjb.start_time_measure, ltjb.stop_time_measure
   local head
   local suppress_hyphenate_ja_aux = {
      [id_math] = function(p) return node_next(node_end_of_math(node_next(p))) end,
      [id_whatsit] = function(p)
	 if getsubtype(p)==sid_user then
	    local uid = getfield(p, 'user_id')
	    if uid==STCK then
	       wt[#wt+1] = p; node_remove(head, p)
	    elseif uid==DIR then
	       if has_attr(p, attr_icflag)<PROCESSED_BEGIN_FLAG  then
		  ltjs.list_dir = has_attr(p, attr_dir)
	       else -- こっちのケースは通常使用では起こらない
		  wtd[#wtd+1] = p; node_remove(head, p)
	       end
	    end
	 end
	 return node_next(p)
      end,
   }
   setmetatable(suppress_hyphenate_ja_aux, 
		{
		   __index = function() return node_next end,
		})
   local function suppress_hyphenate_ja (h)
      start_time_measure('ltj_hyphenate')
      head = to_direct(h)
      for i = 1,#wt do wt[i]=nil end
      for i = 1,#wtd do wtd[i]=nil end
      for i,_ in pairs(ltjs_orig_char_table) do
	 ltjs_orig_char_table[i] = nil
      end
      ltjs.list_dir=ltjd_get_dir_count()
      do
	 local p = head
	 while p do
	    local pid = getid(p)
	    while pid==id_glyph do
	       local pc = getchar(p)
	       if has_attr(p, attr_icflag, 0) and is_ucs_in_japanese_char(p, pc) then
                  local pf = has_attr(p, attr_curjfnt)
                  pf = (pf and pf>0 and pf) or getfont(p)
		  setfont(p, ltjf_replace_altfont(pf, pc))
		  setlang(p, lang_ja)
		  ltjs_orig_char_table[p] = pc
	       end
	       p = node_next(p); pid = getid(p)
	    end
	    p = (suppress_hyphenate_ja_aux[pid])(p)
	 end
      end
      stop_time_measure('ltj_hyphenate'); start_time_measure('tex_hyphenate')
      lang.hyphenate(h, nil)
      stop_time_measure('tex_hyphenate')
      return h
   end

   ltjb.add_to_callback('hyphenate',
			      function (head,tail)
				 return suppress_hyphenate_ja(head)
			      end,'ltj.hyphenate')
end

-- mode: true iff this function is called from hpack_filter
local ltjs_report_stack_level = ltjs.report_stack_level
local ltjf_font_metric_table  = ltjf.font_metric_table
local font_getfont = font.getfont
local function set_box_stack_level(head, mode)
   local box_set, cl = 0, tex.currentgrouplevel + 1
   if mode then
      for _,p  in pairs(wt) do
         if getfield(p, 'value')==cl then box_set = 1 end; node_free(p)
      end
   else
      for _,p  in pairs(wt) do node_free(p) end
   end
   ltjs_report_stack_level(tex_getcount('ltj@@stack') + box_set)
   for _,p  in pairs(wtd) do
      node_free(p)
   end
   if ltjs.list_dir == dir_tate then
      for p in node.direct.traverse_id(id_glyph,to_direct(head)) do
         if has_attr(p, attr_icflag, 0) and getlang(p)==lang_ja then
	    local nf = ltjf_replace_altfont( has_attr(p, attr_curtfnt) or getfont(p) , ltjs_orig_char_table[p])
	    setfont(p, nf)
	    if ltjf_font_metric_table[nf].vert_activated then
	       local pc = getchar(p)
	       pc = ltjf_font_metric_table[nf].vform[pc]
               if pc then setchar(p,  pc) end
	    end
	 end
      end
   end
   return head
end

-- CALLBACKS
ltjb.add_to_callback('hpack_filter',
   function (head)
     return set_box_stack_level(head, true)
   end,'ltj.set_stack_level',1)
ltjb.add_to_callback('pre_linebreak_filter',
  function (head)
     return set_box_stack_level(head, false)
  end,'ltj.set_stack_level',1)

luatexja.pretreat = {
   set_box_stack_level = set_box_stack_level,
   orig_char_table = orig_char_table,
}
