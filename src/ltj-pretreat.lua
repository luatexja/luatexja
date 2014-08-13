--
-- luatexja/ltj-pretreat.lua
--

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('charrange'); local ltjc = luatexja.charrange
luatexja.load_module('stack');     local ltjs = luatexja.stack
luatexja.load_module('jfont');     local ltjf = luatexja.jfont
luatexja.load_module('direction'); local ltjd = luatexja.direction

local Dnode = node.direct or node

local nullfunc = function(n) return n end
local to_node = (Dnode ~= node) and Dnode.tonode or nullfunc
local to_direct = (Dnode ~= node) and Dnode.todirect or nullfunc

local setfield = (Dnode ~= node) and Dnode.setfield or function(n, i, c) n[i] = c end
local getid = (Dnode ~= node) and Dnode.getid or function(n) return n.id end
local getfont = (Dnode ~= node) and Dnode.getfont or function(n) return n.font end
local getchar = (Dnode ~= node) and Dnode.getchar or function(n) return n.char end
local getfield = (Dnode ~= node) and Dnode.getfield or function(n, i) return n[i] end
local getsubtype = (Dnode ~= node) and Dnode.getsubtype or function(n) return n.subtype end

local pairs = pairs
local floor = math.floor
local has_attr = Dnode.has_attribute
local set_attr = Dnode.set_attribute
local node_traverse = Dnode.traverse
local node_remove = Dnode.remove
local node_next = (Dnode ~= node) and Dnode.getnext or node.next
local node_prev = (Dnode ~= node) and Dnode.getprev or node.prev
local node_free = Dnode.free
local node_end_of_math = Dnode.end_of_math
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
local ltjf_get_vert_glyph = ltjf.get_vert_glyph
local ltjf_replace_altfont = ltjf.replace_altfont
local attr_orig_char = luatexbase.attributes['ltj@origchar']
local STCK  = luatexja.userid_table.STCK
local DIR   = luatexja.userid_table.DIR
local PROCESSED_BEGIN_FLAG = luatexja.icflag_table.PROCESSED_BEGIN_FLAG

local dir_tate = luatexja.dir_table.dir_tate

------------------------------------------------------------------------
-- MAIN PROCESS STEP 1: replace fonts
------------------------------------------------------------------------
local wt, wtd = {}, {}
do
   local ltjd_get_dir_count = ltjd.get_dir_count
   local start_time_measure, stop_time_measure 
      = ltjb.start_time_measure, ltjb.stop_time_measure
   local head, real_head
   local is_dir_tate
   local suppress_hyphenate_ja_aux = {}
   suppress_hyphenate_ja_aux[id_glyph] = function(p)
      if (has_attr(p, attr_icflag) or 0)<=0 and is_ucs_in_japanese_char(p) then
         local pc = getchar(p)
	 local pf = ltjf_replace_altfont(has_attr(p, attr_curjfnt) or getfont(p), pc)
	 setfield(p, 'font', pf);  set_attr(p, attr_curjfnt, pf)
	 setfield(p, 'subtype', floor(getsubtype(p)*0.5)*2)
         set_attr(p, attr_orig_char, pc)
      end
      return p
   end
   suppress_hyphenate_ja_aux[id_math] = function(p)
      return node_end_of_math(node_next(p)) end
   suppress_hyphenate_ja_aux[50] = function(p) return p end
   suppress_hyphenate_ja_aux[id_whatsit] = function(p)
      if getsubtype(p)==sid_user then 
         local uid = getfield(p, 'user_id')
         if uid==STCK then
            wt[#wt+1] = p; node_remove(head, p)
         elseif uid==DIR then
	    if has_attr(p, attr_icflag)<PROCESSED_BEGIN_FLAG  then
	       ltjs.list_dir = has_attr(p, attr_dir)
	    else
	       wtd[#wtd+1] = p; node_remove(head, p)
	    end
         end
      end
      return p
   end

   local function suppress_hyphenate_ja (h)
      start_time_measure('ltj_hyphenate')
      head = to_direct(h); real_head = node_next(head)
      local p = head
      for i = 1,#wt do wt[i]=nil end
      for i = 1,#wtd do wtd[i]=nil end
      ltjs.list_dir=ltjd_get_dir_count()
      while p do
	 local flag
	 local pfunc = suppress_hyphenate_ja_aux[getid(p)]
	 if pfunc then p = pfunc(p) end
	 p = node_next(p)
      end
      stop_time_measure('ltj_hyphenate'); start_time_measure('tex_hyphenate')
      lang.hyphenate(h)
      stop_time_measure('tex_hyphenate')
      return h
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
      if mode and getfield(p, 'value')==cl then box_set = 1 end; node_free(p)
   end
   ltjs.report_stack_level(tex_getcount('ltj@@stack') + box_set)
   for _,p  in pairs(wtd) do
      node_free(p)
   end
   is_dir_tate = ltjs.list_dir == dir_tate
   if is_dir_tate then
      for p in Dnode.traverse_id(id_glyph,to_direct(head)) do
         if (has_attr(p, attr_icflag) or 0)<=0 and has_attr(p, attr_curjfnt)==getfont(p) then
            local pfn = has_attr(p, attr_curtfnt) or getfont(p)
            local pc = getchar(p)
            local pf = ltjf_replace_altfont(pfn, pc)
	    set_attr(p, attr_dir, pc)
	    pc = ltjf_get_vert_glyph(pf, pc) or pc
            setfield(p, 'char', pc); set_attr(p, attr_orig_char, pc)
            setfield(p, 'font', pf); set_attr(p, attr_curjfnt, pf)
         end
      end
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

luatexja.pretreat = {
   set_box_stack_level = set_box_stack_level,
}
