--
-- ltj-pretreat.lua
--

luatexja.load_module 'base';      local ltjb = luatexja.base
luatexja.load_module 'charrange'; local ltjc = luatexja.charrange
luatexja.load_module 'stack';     local ltjs = luatexja.stack
luatexja.load_module 'jfont';     local ltjf = luatexja.jfont
luatexja.load_module 'direction'; local ltjd = luatexja.direction

local to_node =  node.direct.tonode
local to_direct =  node.direct.todirect

local setfield =  node.direct.setfield
local getid =  node.direct.getid
local getfont =  node.direct.getfont
local getchar =  node.direct.getchar
local getfield =  node.direct.getfield
local getsubtype =  node.direct.getsubtype
local getlang = node.direct.getlang

local pairs = pairs
local floor = math.floor
local get_attr = node.direct.get_attribute
local has_attr = node.direct.has_attribute
local set_attr = node.direct.set_attribute
local node_traverse = node.direct.traverse
local node_remove = node.direct.remove
local node_next =  node.direct.getnext
local node_free = node.direct.flush_node or node.direct.free
local node_end_of_math = node.direct.end_of_math
local getcount = tex.getcount

local id_glyph = node.id 'glyph'
local id_math = node.id 'math'
local id_whatsit = node.id 'whatsit'
local sid_user = node.subtype 'user_defined'

local attr_dir = luatexbase.attributes['ltj@dir']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_curtfnt = luatexbase.attributes['ltj@curtfnt']
local attr_icflag = luatexbase.attributes['ltj@icflag']

local is_ucs_in_japanese_char = ltjc.is_ucs_in_japanese_char_direct
local ltjs_orig_char_table = ltjs.orig_char_table
local ltjf_replace_altfont = ltjf.replace_altfont
local STCK  = luatexja.userid_table.STCK
local DIR   = luatexja.userid_table.DIR
local JA_AL_BDD = luatexja.userid_table.JA_AL_BDD
local PROCESSED_BEGIN_FLAG = luatexja.icflag_table.PROCESSED_BEGIN_FLAG

local dir_tate = luatexja.dir_table.dir_tate
local lang_ja = luatexja.lang_ja

local setlang = node.direct.setlang
local setfont = node.direct.setfont
local setchar = node.direct.setchar

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
               if get_attr(p, attr_icflag)<PROCESSED_BEGIN_FLAG  then
                  ltjs.list_dir = get_attr(p, attr_dir)
               else -- こっちのケースは通常使用では起こらない
                  wtd[#wtd+1] = p; node_remove(head, p)
               end
            end
         end
         return node_next(p)
      end,
   }
   setmetatable(suppress_hyphenate_ja_aux,
                { __index = function() return node_next end, })
   local id_boundary = node.id 'boundary'
   local node_new, insert_before = node.direct.new, node.direct.insert_before
   local setsubtype = node.direct.setsubtype
   local function suppress_hyphenate_ja (h)
      start_time_measure 'ltj_hyphenate'
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
            local pid, prev_chartype = getid(p), 0
            -- prev_chartype: 0: not char 1: ALchar 2: JAchar
            while pid==id_glyph do
               local pc = getchar(p)
               if has_attr(p, attr_icflag, 0) and is_ucs_in_japanese_char(p, pc) then
                  if prev_chartype==1 then
                     local b = node_new(id_whatsit,sid_user);
                     setfield(b, 'type', 100); setfield(b, 'user_id', JA_AL_BDD);
                     insert_before(head, p, b)
                  end
                  setlang(p, lang_ja);
                  ltjs_orig_char_table[p], prev_chartype = pc, 2
               elseif prev_chartype==2 then
                  local b = node_new(id_whatsit,sid_user);
                  setfield(b, 'type', 100); setfield(b, 'user_id', JA_AL_BDD);
                  insert_before(head, p, b); prev_chartype = 1
               else prev_chartype = 1
               end
               p = node_next(p); pid = getid(p)
            end
            p = (suppress_hyphenate_ja_aux[pid])(p)
         end
      end
      stop_time_measure 'ltj_hyphenate'; start_time_measure 'tex_hyphenate'
      lang.hyphenate(h, nil)
      stop_time_measure 'tex_hyphenate'
      return h
   end

   ltjb.add_to_callback('hyphenate', suppress_hyphenate_ja, 'ltj.hyphenate')
end

-- mode: true iff this function is called from hpack_filter
local set_box_stack_level
do
local ltjs_report_stack_level = ltjs.report_stack_level
local ltjf_font_metric_table  = ltjf.font_metric_table
local traverse_glyph = node.direct.traverse_glyph
local cnt_stack = luatexbase.registernumber 'ltj@@stack'
local texget, getvalue = tex.get, node.direct.getdata
function set_box_stack_level(head, mode)
   local box_set = 0
   if mode then
      local cl = (texget 'currentgrouplevel') + 1
      for i=1,#wt do
         local p = wt[i]
         if getvalue(p)==cl then box_set = 1 end; node_free(p)
      end
   else
      for i=1,#wt do node_free(wt[i]) end
   end
   ltjs_report_stack_level(getcount(cnt_stack) + box_set)
   for _,p  in pairs(wtd) do node_free(p) end
   if ltjs.list_dir == dir_tate then
      for p in traverse_glyph(to_direct(head)) do
         if getlang(p)==lang_ja and has_attr(p, attr_icflag, 0) then
            local pc = ltjs_orig_char_table[p] or getchar(p)
            local pf = ltjf_replace_altfont(attr_curtfnt, pc, p)
            if ltjf_font_metric_table[pf].vert_activated then
               pc = ltjf_font_metric_table[pf].vform[pc]; if pc then setchar(p,  pc) end
            end
         end
      end
   else
      for p in traverse_glyph(to_direct(head)) do
         if getlang(p)==lang_ja and has_attr(p, attr_icflag, 0) then
            ltjf_replace_altfont(attr_curjfnt, ltjs_orig_char_table[p] or getchar(p), p)
         end
      end
   end
   return head
end
end

-- CALLBACKS
ltjb.add_to_callback('hpack_filter',
   function (head)
     return set_box_stack_level(head, true)
   end, 'ltj.set_stack_level', 1)
ltjb.add_to_callback('pre_linebreak_filter',
   function (head)
      return set_box_stack_level(head, false)
   end, 'ltj.set_stack_level', 1)

luatexja.pretreat = {
   set_box_stack_level = set_box_stack_level,
   orig_char_table = orig_char_table,
}
