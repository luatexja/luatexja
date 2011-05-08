------------------------------------------------------------------------
-- MAIN PROCESS STEP 2: insert glue/kerns from JFM (prefix: none)
------------------------------------------------------------------------

local node_type = node.type
local node_new = node.new
local node_remove = node.remove
local node_prev = node.prev
local node_next = node.next
local has_attr = node.has_attribute
local node_insert_before = node.insert_before
local node_insert_after = node.insert_after
local round = tex.round

local id_penalty = node.id('penalty')
local id_glyph = node.id('glyph')
local id_glue_spec = node.id('glue_spec')
local id_glue = node.id('glue')
local id_kern = node.id('kern')
local id_hlist = node.id('hlist')
local id_whatsit = node.id('whatsit')
local sid_user = node.subtype('user_defined')

local TEMPORARY = 2
local FROM_JFM = 3
local KINSOKU = 4
local LINE_END = 5


local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_icflag = luatexbase.attributes['ltj@icflag']
-- attr_icflag: 1: kern from \/, 2: 'lineend' kern from JFM

-- 
local cstb_get_penalty_table = ltj.int_get_penalty_table
local ljfm_find_char_class = ltj.int_find_char_class

-- arithmetic with penalty.
-- p += e
local function add_penalty(p,e)
   local i = p
   if i>=10000 then
      if e<=-10000 then i = 0 end
   elseif i<=-10000 then
      if e>=10000 then i = 0 end
   else
      i = i + e
      if i>=10000 then i = 10000
      elseif i<=-10000 then i = -10000 end
   end
return p
end

-- return true if and only if p is a Japanese character node
local function is_japanese_glyph_node(p)
   return (p.id==id_glyph) and (p.font==has_attr(p,attr_curjfnt))
end

-- EXT: for \inhibitglue
function ltj.ext_create_inhibitglue_node()
   local g=node_new(id_whatsit, sid_user)
   g.user_id=30111; g.type=number; g.value=1; node.write(g)
end

-- In the beginning of a hlist created by line breaking, there are the followings:
--   - a hbox by \parindent
--   - a whatsit node which contains local paragraph materials.
-- When we insert jfm glues, we ignore these nodes.
local function is_parindent_box(p)
   if p.id==id_hlist then 
      return (p.subtype==3)
      -- hlist (subtype=3) is a box by \parindent
   elseif p.id==id_whatsit then 
      return (p.subtype==node.subtype('local_par'))
   end
end

local function find_size_metric(px)
   if is_japanese_glyph_node(px) then
      return { ltj.font_metric_table[px.font].size, 
	       ltj.font_metric_table[px.font].jfm, ltj.font_metric_table[px.font].var }
   else 
      return nil
   end
end

local function new_jfm_glue(size,mt,bc,ac)
-- mt: metric key, bc, ac: char classes
   local g=nil
   local z = ltj.metrics[mt].char_type[bc]
   if z.glue and z.glue[ac] then
      local h = node_new(id_glue_spec)
      h.width   = round(size*z.glue[ac][1])
      h.stretch = round(size*z.glue[ac][2])
      h.shrink  = round(size*z.glue[ac][3])
      h.stretch_order=0; h.shrink_order=0
      g = node_new(id_glue)
      g.subtype = 0; g.spec = h
   elseif z.kern and z.kern[ac] then
      g = node_new(id_kern)
      g.subtype = 1; g.kern = round(size*z.kern[ac])
   end
   return g
end

-- Insert jfm glue: main routine
-- local variables
local p
local q = nil  -- the previous node of p
local q_post   -- the postbreakpenalty of q
local ps, qs
local widow_node -- 最後の「句読点扱いでない」和文文字
local widow_bp -- 挿入位置 (a penalty)
local last -- the sentinel 
local chain = false -- is q a Japanese character?
local ihb_flag = false -- is \inhibitglue specified?
local head -- the head of current list
local mode -- true iff insert_jfm_glue is called from pre_linebreak_filter

-- initialize (insert the sentinel, etc.)
local function init_var()
   p = head;  q = nil; widow_node = nil; widow_bp = nil
   chain = false; ihb_flag = false; 
   if mode then
      while p and is_parindent_box(p) do p=node_next(p) end
      last=node.tail(head)
      if last and last.id==id_glue and last.subtype==15 then
	 last=node.prev(last)
	 while (last and last.id==id_penalty) do last=node.prev(last) end
      end
      if last then last=node_next(last) end
   else -- 番人を挿入
      last=node.tail(head); local g = node_new('kern')
      node_insert_after(head, last, g); last = g
   end
end

-- Insert JFM glue before the first node (which is a Japanese glyph node)
local function ins_gk_head()
   if is_japanese_glyph_node(p) then
      ps = find_size_metric(p)
      local g = new_jfm_glue(ps[1], ps[2],
			     ljfm_find_char_class('boxbdd',ps[2]),
			     has_attr(p,attr_jchar_class))
      if g then
	 node.set_attribute(g, attr_icflag, FROM_JFM)
	 head = node_insert_before(head, p, g)
      end
      q_post = cstb_get_penalty_table('post',p.char); chain = true
   elseif p.id==id_glyph then
      q_post = cstb_get_penalty_table('post',p.char)
   end
   qs = ps; q = p; p = node_next(p)
end

-- The real insertion process is handled in this procedure.
local function real_insert(g, w, pen, always_penalty_ins)
   -- g: glur/kern from JFM
   -- w: the width of kern that will be inserted between q and the end of a line
   -- pen: penalty
   -- always_penalty_ins: true iff we insert a penalty,
   --   for the linebreak between q and p.
   if w~=0 then
      if not g then
	 g = node_new(id_kern); g.kern = -w; g.subtype = 1
	 node.set_attribute(g, attr_icflag, TEMPORARY)
	 -- this g might be replaced by \[x]kanjiskip in step 3.
      else 
	 node.set_attribute(g, attr_icflag, FROM_JFM)
	 if g.id==id_kern then w=0
	 else g.spec.width = round(g.spec.width - w) 
	 end
      end
   end
   if w~=0 then
      local h = node_new(id_kern)
      node.set_attribute(h, attr_icflag, LINE_END)
      h.kern = w; h.subtype = 0; node_insert_before(head, p, h)
   elseif g then
      node.set_attribute(g, attr_icflag, FROM_JFM)
      if g.id==id_kern  then
	 pen=0; always_penalty_ins = false
      end
   end
   if w~=0  or pen~=0 or ((not g) and always_penalty_ins) then
      local h = node_new(id_penalty)
      h.penalty = pen; node.set_attribute(h, attr_icflag, KINSOKU)
      node_insert_before(head, p, h)
   end
   if g then
      node_insert_before(head, p, g); 
   end
end

-- This is a variant of real_insert (the case which a kern is related)
local function real_insert_kern(g)
   if g then
      if g.id==id_glue then
	 local h = node_new(id_penalty)
	 h.penalty = 10000; node.set_attribute(h, attr_icflag, KINSOKU)
	 node_insert_before(head, p, h)
      end
      node.set_attribute(g, attr_icflag, FROM_JFM)
      node_insert_before(head, p, g)
   end
end

-- Calc the glue between two Japanese characters
local function calc_ja_ja_glue()
   if ihb_flag then return nil
   elseif table.are_equal(qs,ps) then
      return new_jfm_glue(ps[1],ps[2],
			  has_attr(q,attr_jchar_class),
			  has_attr(p,attr_jchar_class))
   else
      local g = new_jfm_glue(qs[1],qs[2],
			     has_attr(q,attr_jchar_class),
			     ljfm_find_char_class('diffmet',qs[2]))
      local h = new_jfm_glue(ps[1],ps[2],
			     ljfm_find_char_class('diffmet',ps[2]),
			     has_attr(p,attr_jchar_class))
      return calc_ja_ja_aux(g,h)
   end
end

ltj.ja_diffmet_rule = math.two_average

local function calc_ja_ja_aux(gb,ga)
   if not gb then 
      return ga
   else
      if not ga then return gb end
      local k = node.type(gb.id) .. node.type(ga.id)
      if k == 'glueglue' then 
	 -- 両方とも glue．
	 gb.spec.width   = round(ltj.ja_diffmet_rule(gb.spec.width, ga.spec.width))
	 gb.spec.stretch = round(ltj.ja_diffmet_rule(gb.spec.stretch,ga.spec.shrink))
	 gb.spec.shrink  = -round(ltj.ja_diffmet_rule(-gb.spec.shrink, -ga.spec.shrink))
	 return gb
      elseif k == 'kernkern' then
	 -- 両方とも kern．
	 gb.kern = round(ltj.ja_diffmet_rule(gb.kern, ga.kern))
	 return gb
      elseif k == 'kernglue' then 
	 -- gb: kern, ga: glue
	 ga.spec.width   = round(ltj.ja_diffmet_rule(gb.kern,ga.spec.width))
	 ga.spec.stretch = round(ltj.ja_diffmet_rule(ga.spec.stretch, 0))
	 ga.spec.shrink  = -round(ltj.ja_diffmet_rule(-ga.spec.shrink, 0))
	 return ga
      else
	 -- gb: glue, ga: kern
	 gb.spec.width   = round(ltj.ja_diffmet_rule(ga.kern, gb.spec.width))
	 gb.spec.stretch = round(ltj.ja_diffmet_rule(gb.spec.stretch, 0))
	 gb.spec.shrink  = -round(ltj.ja_diffmet_rule(-gb.spec.shrink, 0))
	 return gb
      end
   end
end

local function ins_gk_any_JA()
   ps = find_size_metric(p)
   if chain then -- (q,p): JA-JA
      local g = calc_ja_ja_glue()
      local w = 0; local x = ljfm_find_char_class('lineend', qs[2])
      if (not ihb_flag) and x~=0  then
	 local h = ltj.metrics[qs[2]].char_type[has_attr(q, attr_jchar_class)]
	 if h.kern and h.kern[x] then w = round(qs[1]*h.kern[x]) end
      end
      q_post = add_penalty(q_post, cstb_get_penalty_table('pre', p.char))
      real_insert(g, w, q_post, false)
   elseif q.id==id_glyph then -- (q,p): AL-JA
      local g = nil
      if not ihb_flag then
	 g = new_jfm_glue(ps[1], ps[2],
			  ljfm_find_char_class('jcharbdd',ps[2]),
			  has_attr(p,attr_jchar_class))
      end
      q_post = add_penalty(q_post, cstb_get_penalty_table('pre', p.char))
      real_insert(g, 0, q_post, true)
   elseif q.id==id_kern then -- (q,p): kern-JA
      local g = nil
      if not ihb_flag then
	 g = new_jfm_glue(ps[1], ps[2],
			  ljfm_find_char_class('jcharbdd',ps[2]),
			  has_attr(p,attr_jchar_class))
      end
      real_insert_kern(g)
   else
      local g = nil
      if not ihb_flag then
	 g = new_jfm_glue(ps[1], ps[2],
			  ljfm_find_char_class('jcharbdd',ps[2]),
			  has_attr(p,attr_jchar_class))
      end
      real_insert(g, 0, q_post, true)
   end
   q, qs, q_post = p, ps, cstb_get_penalty_table('post',p.char)
   if cstb_get_penalty_table('kcat',p.char)%2~=1 then
      widow_node = p
   end
   p = node_next(p); chain = true
end

local function ins_gk_JA_any()
   -- the case (q,p): JA-JA is treated in ins_gk_any_JA()
   local g = nil
   if not ihb_flag then
      g = new_jfm_glue(qs[1], qs[2],
		       has_attr(q,attr_jchar_class),
		       ljfm_find_char_class('jcharbdd',qs[2]))
   end
   if p.id==id_glyph then -- (q,p): JA-AL
      local w = 0; local x = ljfm_find_char_class('lineend', qs[2])
      if (not ihb_flag) and x~=0  then
	 local h = ltj.metrics[qs[2]].char_type[has_attr(q,attr_jchar_class)]
	 if h.kern and h.kern[x] then w = round(qs[1]*h.kern[x]) end
      end
      q_post = add_penalty(q_post, cstb_get_penalty_table('pre',p.char))
      real_insert(g, w, q_post, true)
   elseif p.id==id_kern then -- (q,p): JA-kern
      real_insert_kern(g)
   else
      local w = 0; local x = ljfm_find_char_class('lineend', qs[2])
      if (not ihb_flag) and x~=0  then
	 local h = ltj.metrics[qs[2]].char_type[has_attr(q,attr_jchar_class)]
	 if h.kern and h.kern[x] then w = round(qs[1]*h.kern[x]) end
      end
      real_insert(g, w, q_post, false)
   end
   chain = false; q, qs, q_post = p, nil, 0; p = node_next(p)
end

-- Insert JFM glue after thr last node
local function ins_gk_tail()
   local g
   if is_japanese_glyph_node(p) then
      if mode then
	 local w = 0; local x = ljfm_find_char_class('lineend', qs[2])
	 if (not ihb_flag) and x~=0  then
	    local h = ltj.metrics[qs[2]].char_type[has_attr(q,attr_jchar_class)]
	    if h.kern and h.kern[x] then w = round(qs[1]*h.kern[x]) end
	 end
	 if w~=0 then
	    g = node_new(id_kern); g.subtype = 0; g.kern = w
	    node.set_attribute(g, attr_icflag, LINE_END)
	    node_insert_before(head, last, g)
	 end
      end
   end
end

local function add_widow_penalty()
   -- widoe_node: must be 
   if not widow_node then return end
   local a = node_prev(widow_node)
   local i = has_attr(a, attr_icflag) or 0
   local wp = tex.getcount('jcharwidowpenalty')
   if i==4 then
      a.penalty=add_penalty(a.penalty, wp)
   elseif i>=2 then
      local b = node_prev(a)
      if i==4 then
	 b.penalty=add_penalty(b.penalty, wp)
      else
	 local g = node_new(id_penalty)
	 g.penalty = wp; head = node_insert_before(head,a,g)
      end
   else
      local g = node_new(id_penalty)
      g.penalty = wp; head = node_insert_before(head,widow_node,g)
   end
end

-- Finishing: add \jcharwidowpenalty or remove the sentinel
local function finishing()
   if mode then
      -- Insert \jcharwidowpenalty
      add_widow_penalty()
   else
      head = node_remove(head, last)
   end
end

-- The interface
function ltj.int_insert_jfm_glue(ahead, amode)
   if not ahead then return ahead end
   head = ahead; mode = amode; init_var(); 
   while p~=last and p.id==id_whatsit and p.subtype==sid_user and p.user_id==30111 do
      local g = p; p = node_next(p); ihb_flag = true; head, p = node.remove(head, g)
   end
   if p~=last then ins_gk_head() else finishing() return head end

   while p~=last do
      if p.id==id_whatsit and p.subtype==sid_user and p.user_id==30111 then
	 local g = p; p = node_next(p)
	 ihb_flag = true; head, p = node.remove(head, g)
      else
	 if is_japanese_glyph_node(p) then -- p: JAchar
	    ins_gk_any_JA()
	 elseif chain then -- q: JAchar
	    ins_gk_JA_any()
	 else 
	    q, qs, q_post = p, nil, 0; p = node_next(p)
	 end
	 ihb_flag = false
      end
   end

   ins_gk_tail(); finishing(); return head
end

