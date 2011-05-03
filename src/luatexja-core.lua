local node_type = node.type
local node_new = node.new
local node_prev = node.prev
local node_next = node.next
local has_attr = node.has_attribute
local node_insert_before = node.insert_before
local node_insert_after = node.insert_after
local node_hpack = node.hpack
local round = tex.round

local id_penalty = node.id('penalty')
local id_glyph = node.id('glyph')
local id_glue_spec = node.id('glue_spec')
local id_glue = node.id('glue')
local id_kern = node.id('kern')
local id_hlist = node.id('hlist')
local id_vlist = node.id('vlist')
local id_rule = node.id('rule')
local id_math = node.id('math')
local id_whatsit = node.id('whatsit')

local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_yablshift = luatexbase.attributes['ltj@yablshift']
local attr_ykblshift = luatexbase.attributes['ltj@ykblshift']
local attr_icflag = luatexbase.attributes['ltj@icflag']
-- attr_icflag: 1: kern from \/, 2: 'lineend' kern from JFM

local lang_ja_token = token.create('ltj@japanese')
local lang_ja = lang_ja_token[2]

-- 
local rgjc_get_range_setting = ltj.int_get_range_setting 
local rgjc_char_to_range     = ltj.int_char_to_range
local rgjc_is_ucs_in_japanese_char = ltj.int_is_ucs_in_japanese_char
local ljfm_find_char_class = ltj.int_find_char_class

------------------------------------------------------------------------
-- naming:
--    ltj.ext_... : called from \directlua{}
--    ltj.int_... : called from other Lua codes, but not from \directlua{}
--    (other)     : only called from this file

-- error messages
function ltj.error(s,t)
  tex.error('LuaTeX-ja error: ' .. s ,t) 
end

-- Three aux. functions, bollowed from tex.web
local unity=65536
local function print_scaled(s)
   local out=''
   local delta=10
   if s<0 then 
      out=out..'-'; s=-s
   end
   out=out..tostring(math.floor(s/unity)) .. '.'
   s=10*(s%unity)+5
   repeat
      if delta>unity then s=s+32768-50000 end
      out=out .. tostring(math.floor(s/unity)) 
      s=10*(s%unity)
      delta=delta*10
   until s<=delta
   return out
end

local function print_glue(d,order)
   local out=print_scaled(d)
   if order>0 then
      out=out..'fi'
      while order>1 do
	 out=out..'l'; order=order-1
      end
   else 
      out=out..'pt'
   end
   return out
end

local function print_spec(p)
   local out=print_scaled(p.width)..'pt'
   if p.stretch~=0 then
      out=out..' plus '..print_glue(p.stretch,p.stretch_order)
   end
   if p.shrink~=0 then
      out=out..' minus '..print_glue(p.shrink,p.shrink_order)
   end
return out
end

-- return true if and only if p is a Japanese character node
local function is_japanese_glyph_node(p)
   return p and (p.id==id_glyph) 
   and (p.font==has_attr(p,attr_curjfnt))
end


------------------------------------------------------------------------
-- CODE FOR STACK TABLE FOR CHARACTER PROPERTIES (prefix: cstb)
------------------------------------------------------------------------

---- table: charprop_stack_table [stack_level][chr_code].{pre|post|xsp}
local charprop_stack_table={}; charprop_stack_table[0]={}

local function cstb_get_stack_level()
  local i = tex.getcount('ltj@@stack')
  if tex.currentgrouplevel > tex.getcount('ltj@@group@level') then
    i = i+1 -- new stack level
    tex.setcount('ltj@@group@level', tex.currentgrouplevel)
    for j,v in pairs(charprop_stack_table) do -- clear the stack above i
      if j>=i then charprop_stack_table[j]=nil end
    end
    charprop_stack_table[i] = table.fastcopy(charprop_stack_table[i-1])
    tex.setcount('ltj@@stack', i)
  end
  return i
end

-- EXT
function ltj.ext_set_stack_table(g,m,c,p,lb,ub)
  local i = cstb_get_stack_level()
  if p<lb or p>ub then 
     ltj.error('Invalid code (' .. p .. '), should in the range '
	       .. tostring(lb) .. '..' .. tostring(ub) .. '.',
	    {"I'm going to use 0 instead of that illegal code value."})
     p=0
  elseif c<-1 or c>0x10FFFF then
     ltj.error('Invalid character code (' .. p 
	       .. '), should in the range -1.."10FFFF.',{})
     return 
  elseif not charprop_stack_table[i][c] then 
     charprop_stack_table[i][c] = {} 
  end
  charprop_stack_table[i][c][m] = p
  if g=='global' then
    for j,v in pairs(charprop_stack_table) do 
      if not charprop_stack_table[j][c] then charprop_stack_table[j][c] = {} end
      charprop_stack_table[j][c][m] = p
    end
  end
end

local function cstb_get_penalty_table(m,c)
  local i = charprop_stack_table[tex.getcount('ltj@@stack')][c]
  if i then i=i[m] end
  return i or 0
end

local function cstb_get_inhibit_xsp_table(c)
  local i = charprop_stack_table[tex.getcount('ltj@@stack')][c]
  if i then i=i.xsp end
  return i or 3
end
ltj.int_get_inhibit_xsp_table = cstb_get_inhibit_xsp_table

------------------------------------------------------------------------
-- CODE FOR GETTING/SETTING PARAMETERS 
------------------------------------------------------------------------

-- EXT: print parameters that don't need arguments
function ltj.ext_get_parameter_unary(k)
   if k == 'yalbaselineshift' then
      tex.write(print_scaled(tex.getattribute('ltj@yablshift'))..'pt')
   elseif k == 'yjabaselineshift' then
      tex.write(print_scaled(tex.getattribute('ltj@ykblshift'))..'pt')
   elseif k == 'kanjiskip' then
      tex.write(print_spec(tex.getskip('kanjiskip')))
   elseif k == 'xkanjiskip' then
      tex.write(print_spec(tex.getskip('xkanjiskip')))
   elseif k == 'jcharwidowpenalty' then
      tex.write(tex.getcount('jcharwidowpenalty'))
   elseif k == 'autospacing' then
      tex.write(tostring(ltj.auto_spacing))
   elseif k == 'autoxspacing' then
      tex.write(tostring(ltj.auto_xspacing))
   elseif k == 'differentjfm' then
      if ltj.calc_between_two_jchar_aux==ltj.calc_between_two_jchar_aux_large then
	 tex.write('large')
      elseif ltj.calc_between_two_jchar_aux==ltj.calc_between_two_jchar_aux_small then
	 tex.write('small')
      elseif ltj.calc_between_two_jchar_aux==ltj.calc_between_two_jchar_aux_average then
	 tex.write('average')
      elseif ltj.calc_between_two_jchar_aux==ltj.calc_between_two_jchar_aux_both then
	 tex.write('both')
      else -- This can't happen.
	 tex.write('???')
      end
   end
end

-- EXT: print parameters that need arguments
function ltj.ext_get_parameter_binary(k,c)
   if k == 'jacharrange' then
      if c<0 or c>216 then c=0 end
      tex.write(rgjc_get_range_setting(c))
   else
      if c<0 or c>0x10FFFF then
	 ltj.error('Invalid character code (' .. c 
		   .. '), should in the range 0.."10FFFF.',
		{"I'm going to use 0 instead of that illegal character code."})
	 c=0
      end
      if k == 'prebreakpenalty' then
	 tex.write(cstb_get_penalty_table('pre',c))
      elseif k == 'postbreakpenalty' then
	 tex.write(cstb_get_penalty_table('post',c))
      elseif k == 'kcatcode' then
	 tex.write(cstb_get_penalty_table('kcat',c))
      elseif k == 'chartorange' then 
	 tex.write(rgjc_char_to_range(c))
      elseif k == 'jaxspmode' or k == 'alxspmode' then
	 tex.write(cstb_get_inhibit_xsp_table(c))
      end
   end
end

-- EXT: print \global if necessary
function ltj.ext_print_global()
  if ltj.isglobal=='global' then tex.sprint('\\global') end
end


------------------------------------------------------------------------
-- MAIN PROCESS STEP 1: replace fonts (prefix: main1)
------------------------------------------------------------------------

--- the following function is modified from jafontspec.lua (by K. Maeda).
--- Instead of "%", we use U+FFFFF for suppressing spaces.
local function main1_process_input_buffer(buffer)
   local c = utf.byte(buffer, utf.len(buffer))
   local p = node_new(id_glyph)
   p.char = c
   if utf.len(buffer) > 0 
   and rgjc_is_ucs_in_japanese_char(p) then
	buffer = buffer .. string.char(0xF3,0xBF,0xBF,0xBF) -- U+FFFFF
   end
   return buffer
end

local function main1_suppress_hyphenate_ja(head)
   local p
   for p in node.traverse(head) do
      if p.id == id_glyph then
	 if rgjc_is_ucs_in_japanese_char(p) then
	    local v = has_attr(p, attr_curjfnt)
	    if v then 
	       p.font = v 
	       node.set_attribute(p,attr_jchar_class,
                 ljfm_find_char_class(p.char, ltj.font_metric_table[v].jfm))
	    end
	    v = has_attr(p, attr_ykblshift)
	    if v then 
	       node.set_attribute(p, attr_yablshift, v)
	    else
	       node.unset_attribute(p, attr_yablshift)
	    end
	    p.lang=lang_ja
	 end
      end
   end
   lang.hyphenate(head)
   return head -- 共通化のため値を返す
end

-- CALLBACKS
luatexbase.add_to_callback('process_input_buffer', 
   function (buffer)
     return main1_process_input_buffer(buffer)
   end,'ltj.process_input_buffer')
luatexbase.add_to_callback('hpack_filter', 
  function (head,groupcode,size,packtype)
     return main1_suppress_hyphenate_ja(head)
  end,'ltj.hpack_filter_pre',0)
luatexbase.add_to_callback('hyphenate', 
 function (head,tail)
    return main1_suppress_hyphenate_ja(head)
 end,'ltj.hyphenate')


------------------------------------------------------------------------
-- MAIN PROCESS STEP 2: insert glue/kerns from JFM (prefix: main2)
------------------------------------------------------------------------

-- EXT: for \inhibitglue
function ltj.ext_create_inhibitglue_node()
   local g=node_new(id_whatsit, node.subtype('user_defined'))
   g.user_id=30111; g.type=number; g.value=1; node.write(g)
end


local function main2_find_size_metric(px)
   if is_japanese_glyph_node(px) then
      return ltj.font_metric_table[px.font].size, 
      ltj.font_metric_table[px.font].jfm, ltj.font_metric_table[px.font].var
   else 
      return nil, nil, nil
   end
end

local function main2_new_jfm_glue(size,mt,bc,ac)
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

-- return value: g (glue/kern from JFM), w (width of 'lineend' kern)
local function main2_calc(qs,qm,qv,q,p,last,ihb_flag)
   -- q, p: node (possibly null)
   local ps, pm, pv, g, h
   local w = 0
   if (not p) or p==last then
      -- q is the last node
      if not qm then
	 return nil, 0
      elseif not ihb_flag then 
	 g=main2_new_jfm_glue(qs,qm,
			    has_attr(q,attr_jchar_class),
				ljfm_find_char_class('boxbdd',qm))
      end
   elseif qs==0 then
      -- p is the first node etc.
      ps, pm, pv = main2_find_size_metric(p)
      if not pm then
	 return nil, 0
      elseif not ihb_flag then 
	 g=main2_new_jfm_glue(ps,pm,
				ljfm_find_char_class('boxbdd',pm),
				has_attr(p,attr_jchar_class))
      end
   else -- p and q are not nil
      ps, pm, pv = main2_find_size_metric(p)
      if ihb_flag or ((not pm) and (not qm)) then 
	 g = nil
      elseif (qs==ps) and (qm==pm) and (qv==pv) then 
	 -- Both p and q are Japanese glyph nodes, and same metric and size
	 g = main2_new_jfm_glue(ps,pm,
				has_attr(q,attr_jchar_class),
				has_attr(p,attr_jchar_class))
      elseif not qm then
	 -- q is not a Japanese glyph node
	 g = main2_new_jfm_glue(ps,pm,
				ljfm_find_char_class('jcharbdd',pm),
				has_attr(p,attr_jchar_class))
      elseif not pm then
	 -- p is not a Japanese glyph node
	 g = main2_new_jfm_glue(qs,qm,
				has_attr(q,attr_jchar_class),
				ljfm_find_char_class('jcharbdd',qm))
      else
	 g = main2_new_jfm_glue(qs,qm,
				has_attr(q,attr_jchar_class),
				ljfm_find_char_class('diffmet',qm))
	 h = main2_new_jfm_glue(ps,pm,
				ljfm_find_char_class('diffmet',pm),
				has_attr(p,attr_jchar_class))
	 g = ltj.calc_between_two_jchar_aux(g,h)
      end
   end
   if g then node.set_attribute(g, attr_icflag, 3) end
   if qm then
      local x = ljfm_find_char_class('lineend', qm)
      if x~=0  then
	 qv = ltj.metrics[qm].char_type[has_attr(q,attr_jchar_class)]
	 if qv.kern and qv.kern[x] then 
	    w = round(qs*qv.kern[x])
	 end
      end
   end

   return g, w
end

local function main2_between_two_char(head,q,p,p_bp,ihb_flag,last)
   local qs = 0; local g, w
   local qm = nil, qv
   if q then
      qs, qm, qv = main2_find_size_metric(q)
   end
   g, w = main2_calc(qs, qm, qv, q, p, last, ihb_flag)
   if w~=0 and (not p_bp) then
      p_bp = node_new(id_penalty); p_bp.penalty = 0
      head = node_insert_before(head, p, p_bp)
   end
   if g then
      if g.id==id_kern then 
	 g.kern = round(g.kern - w)
      else
	 g.spec.width = round(g.spec.width - w)
      end
      head = node_insert_before(head, p, g)
   elseif w~=0 then
      g = node_new(id_kern); g.kern = -w; g.subtype = 1
      node.set_attribute(g,attr_icflag,2)
      head = node_insert_before(head, p, g)
      -- this g might be replaced by \[x]kanjiskip in step 3.
   end
   if w~=0 then
      g = node_new(id_kern); g.kern = w; g.subtype = 0
      head = node_insert_before(head, p_bp, g)
   end
return head, p_bp
end

-- In the beginning of a hlist created by line breaking, there are the followings:
--   - a hbox by \parindent
--   - a whatsit node which contains local paragraph materials.
-- When we insert jfm glues, we ignore these nodes.
local function main2_is_parindent_box(p)
   if p.id==id_hlist then 
      return (p.subtype==3)
      -- hlist (subtype=3) is a box by \parindent
   elseif p.id==id_whatsit then 
      return (p.subtype==node.subtype('local_par'))
   end
end

-- next three functions deal with inserting penalty by kinsoku.
local function main2_add_penalty_before(head,p,p_bp,pen)
   if p_bp then
      p_bp.penalty = p_bp.penalty + pen
   else -- we must create a new penalty node
      local g = node_new(id_penalty); g.penalty = pen
      local q = node_prev(p)
      if q then
	 if has_attr(q, attr_icflag) ~= 3 then
	    q = p
	 end
	 return node_insert_before(head, q, g)
      end
   end
   return head
end

local function main2_add_kinsoku_penalty(head,p,p_bp)
   local c = p.char
   local e = cstb_get_penalty_table('pre',c)
   if e~=0 then
      head = main2_add_penalty_before(head, p, p_bp, e)
   end
   e = cstb_get_penalty_table('post',c)
   if e~=0 then
      local q = node_next(p)
      if q and q.id==id_penalty then
	 q.penalty = q.penalty + e
	 return false
      else 
	 q = node_new(id_penalty); q.penalty = e
	 node_insert_after(head,p,q)
	 return true
      end
   end
end

local function main2_add_widow_penalty(head,widow_node,widow_bp)
   if not widow_node then 
      return head
   else
      return main2_add_penalty_before(head, widow_node,
                 widow_bp, tex.getcount('jcharwidowpenalty'))
   end
end

local depth=""

-- Insert jfm glue: main routine
-- mode = true iff insert_jfm_glue is called from pre_linebreak_filter
local function main2_insert_jfm_glue(head, mode)
   local p = head
   local p_bp = nil -- p と直前の文字の間の penalty node
   local q = nil  -- the previous node of p
   local widow_node = nil -- 最後の「句読点扱いでない」和文文字
   local widow_bp = nil -- \jcharwidowpenalty 挿入位置
   local last -- the sentinel 
   local ihb_flag = false -- is \inhibitglue specified?
   local g
   -- initialization
   if not p then return head 
   elseif mode then
      while p and main2_is_parindent_box(p) do p=node_next(p) end
      last=node.tail(head)
      if last and last.id==id_glue and last.subtype==15 then
	 last=node.prev(last)
	 while (last and last.id==id_penalty) do last=node.prev(last) end
      end
      if last then last=node_next(last) end
   else -- 番人を挿入
      last=node.tail(head); g = node_new('kern')
      node_insert_after(head,last,g); last = g
   end
   -- main loop
   while q~=last do
      if p.id==id_whatsit and p.subtype==node.subtype('user_defined')
         and p.user_id==30111 then
	 g = p; p = node_next(p)
	 ihb_flag = true; head, p = node.remove(head, g)
      else
	 head, p_bp = main2_between_two_char(head, q, p, p_bp, ihb_flag, last)
	 q=p; ihb_flag=false
	 if is_japanese_glyph_node(p) then
	    if cstb_get_penalty_table('kcat',p.char)%2~=1 then
	       widow_node = p; widow_bp = p_bp
	    end
	    if main2_add_kinsoku_penalty(head, p, p_bp) then
	       p_bp = node_next(p); p = p_bp
	    else p_bp = nil
	    end
	 else p_bp = nil
	 end
	 p=node_next(p)
      end
   end
   if mode then
      -- Insert \jcharwidowpenalty
      head = main2_add_widow_penalty(head, widow_node, widow_bp)
      -- cleanup
      p = node_prev(last)
      if p and p.id==id_kern and has_attr(p,attr_icflag)==2 then
	 head = node.remove(head, p)
      end
   else
      head = node.remove(head, last)
   end
   return head
end


------------------------------------------------------------------------
-- MAIN PROCESS STEP 4: width of japanese chars (prefix: main4)
------------------------------------------------------------------------

-- TeX's \hss
local function main4_get_hss()
   local hss = node_new(id_glue)
   local fil_spec = node_new(id_glue_spec)
   fil_spec.width = 0
   fil_spec.stretch = 65536
   fil_spec.stretch_order = 2
   fil_spec.shrink = 65536
   fil_spec.shrink_order = 2
   hss.spec = fil_spec
   return hss
end

local function main4_set_ja_width(head)
   local p = head
   local met_tb, t, s, g, q, a, h
   local m = false -- is in math mode?
   while p do
      local v=has_attr(p,attr_yablshift) or 0
      if p.id==id_glyph then
	 p.yoffset = p.yoffset-v
	 if is_japanese_glyph_node(p) then
	    met_tb = ltj.font_metric_table[p.font]
	    t = ltj.metrics[met_tb.jfm]
	    s = t.char_type[has_attr(p,attr_jchar_class)]
	    if s.width ~= 'prop' and
	       not(s.left==0.0 and s.down==0.0 and s.align=='left' 
		   and round(s.width*met_tb.size)==p.width) then
	       -- must be encapsuled by a \hbox
	       head, q = node.remove(head,p)
	       p.next=nil
	       p.yoffset=round(p.yoffset-met_tb.size*s.down)
	       p.xoffset=round(p.xoffset-met_tb.size*s.left)
	       if s.align=='middle' or s.align=='right' then
		  h = node_insert_before(p, p, main4_get_hss())
	       else h=p end
	       if s.align=='middle' or s.align=='left' then
		  node_insert_after(h, p, main4_get_hss())
	       end
	       g = node_hpack(h, round(met_tb.size*s.width), 'exactly')
	       g.height = round(met_tb.size*s.height)
	       g.depth = round(met_tb.size*s.depth)
	       head, p = node_insert_before(head, q, g)
	       p = q
	    else p=node_next(p)
	    end
	 else p=node_next(p)
	 end
      elseif p.id==id_math then
	 m=(p.subtype==0); p=node_next(p)
      else
	 if m then
	    if p.id==id_hlist or p.id==id_vlist then
	       p.shift=p.shift+v
	    elseif p.id==id_rule then
	       p.height=p.height-v; p.depth=p.depth+v 
	    end
	 end
	 p=node_next(p)
      end
   end
return head
end

-- main process
-- mode = true iff main_process is called from pre_linebreak_filter
local function main_process(head, mode)
   local p = head
   p = main2_insert_jfm_glue(p,mode)
   p = ltj.int_insert_kanji_skip(p)
   p = main4_set_ja_width(p)
   return p
end


-- debug
local debug_depth
function ltj.ext_show_node_list(head,depth,print_fn)
   debug_depth = depth
   if head then
      debug_show_node_list_X(head, print_fn)
   else
      print_fn(debug_depth .. ' (null list)')
   end
end
function debug_show_node_list_X(p,print_fn)
   debug_depth=debug_depth.. '.'
   local k = debug_depth
   while p do
      local pt=node_type(p.id)
      if pt == 'glyph' then
	 print_fn(debug_depth.. ' glyph  ', p.subtype, utf.char(p.char), p.font)
      elseif pt=='hlist' then
	 print_fn(debug_depth.. ' hlist  ', p.subtype, '(' .. print_scaled(p.height)
	    .. '+' .. print_scaled(p.depth)
	 .. ')x' .. print_scaled(p.width) )
	 debug_show_node_list_X(p.head,print_fn)
	 debug_depth=k
      elseif pt == 'whatsit' then
	 print_fn(debug_depth.. ' whatsit', p.subtype)
      elseif pt == 'glue' then
	 print_fn(debug_depth.. ' glue   ', p.subtype, print_spec(p.spec))
      elseif pt == 'kern' then
	 print_fn(debug_depth.. ' kern   ', p.subtype, print_scaled(p.kern) .. 'pt')
      elseif pt == 'penalty' then
	 print_fn(debug_depth.. ' penalty', p.penalty)
      else
	 print_fn(debug_depth.. ' ' .. node.type(p.id), p.subtype)
      end
      p=node_next(p)
   end
end



-- callbacks
luatexbase.add_to_callback('pre_linebreak_filter', 
   function (head,groupcode)
     return main_process(head, true)
   end,'ltj.pre_linebreak_filter',2)
luatexbase.add_to_callback('hpack_filter', 
  function (head,groupcode,size,packtype)
     return main_process(head, false)
  end,'ltj.hpack_filter',2)
