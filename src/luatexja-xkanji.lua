------------------------------------------------------------------------
-- MAIN PROCESS STEP 3: insert \xkanjiskip (prefix: none)
------------------------------------------------------------------------

local node_type = node.type
local node_new = node.new
local node_prev = node.prev
local node_next = node.next
local node_copy = node.copy
local has_attr = node.has_attribute
local set_attr = node.set_attribute
local node_insert_before = node.insert_before
local node_insert_after = node.insert_after
local node_hpack = node.hpack
local round = tex.round

local id_penalty = node.id('penalty')
local id_glyph = node.id('glyph')
local id_glue = node.id('glue')
local id_glue_spec = node.id('glue_spec')
local id_kern = node.id('kern')
local id_hlist = node.id('hlist')
local id_ins = node.id('ins')
local id_mark = node.id('mark')
local id_adjust = node.id('adjust')
local id_math = node.id('math')
local id_whatsit = node.id('whatsit')

local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_autospc = luatexbase.attributes['ltj@autospc']
local attr_autoxspc = luatexbase.attributes['ltj@autoxspc']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local max_dimen = 1073741823

local ITALIC = 1
local TEMPORARY = 2
local FROM_JFM = 3
local KINSOKU = 4
local LINE_END = 5
local KANJI_SKIP = 6
local XKANJI_SKIP = 7
local PACKED = 8

local kanji_skip
local xkanji_skip

-- (glyph_node nr) ... (node nq) <GLUE> ,,, (node np)
local np, nq, nrc, nrf
local np_spc, nr_spc
local no_skip = 0 
local after_schar = 1
local after_wchar = 2 -- nr is a Japanese glyph_node
local insert_skip = no_skip
local head

local function is_japanese_glyph_node(p)
   return p and (p.id==id_glyph) 
   and (p.font==has_attr(p,attr_curjfnt))
end

local function get_zero_glue()
   local g = node_new(id_glue_spec)
   g.width = 0; g.stretch_order = 0; g.stretch = 0
   g.shrink_order = 0; g.shrink = 0
   return g
end

local function skip_table_to_spec(n)
   local g = node_new(id_glue_spec)
   local st = luatexja.stack.get_skip_table(n, ltj.box_stack_level)
   g.width = st.width; g.stretch = st.stretch; g.shrink = st.shrink
   g.stretch_order = st.stretch_order; g.shrink_order = st.shrink_order
   return g
end

local function add_glue_spec(g,h)
   -- g := g + h
   g.width = g.width + h.width
   if g.stretch_order<h.stretch_order then
      g.stretch_order = h.stretch_order
      g.stretch = h.stretch
   elseif g.stretch_order==h.stretch_order then
      g.stretch = g.stretch + h.stretch
   end
   if g.shrink_order<h.shrink_order then
      g.shrink_order = h.shrink_order
      g.shrink = h.shrink
   elseif g.shrink_order==h.shrink_order then
      g.shrink = g.shrink + h.shrink
   end
end

-- lowest part of \xkanjiskip 
local function get_xkanji_skip_from_jfm(pf)
   if pf then
      local px = { ltj.font_metric_table[pf].size, 
		   ltj.font_metric_table[pf].jfm }
      local i = ltj.metrics[px[2]].xkanjiskip
      if i then
	 return { round(i[1]*px[1]), round(i[2]*px[1]), round(i[3]*px[1]) }
      else return nil
      end
   else return nil
   end
end

local function insert_xkanjiskip_node(q, f, p)
   if nr_spc[2] or np_spc[2] then
      local g = node_new(id_glue); g.subtype = 0
      if xkanji_skip.width==max_dimen then -- use xkanjiskip from JFM
	 local gx = node_new(id_glue_spec)
	 gx.stretch_order = 0; gx.shrink_order = 0
	 local ak = get_xkanji_skip_from_jfm(f)
	 if ak then
	    gx.width = ak[1]; gx.stretch = ak[2]; gx.shrink = ak[3]
	 else gx = get_zero_glue() -- fallback
	 end
	 g.spec = gx
      else g.spec=node_copy(xkanji_skip)
      end
      local h = node_prev(p)
      if h  and has_attr(h, attr_icflag)==TEMPORARY then
	 if h.id==id_kern then
	    g.spec.width = g.spec.width + h.kern
	    set_attr(g,attr_icflag,XKANJI_SKIP)
	    node_insert_after(head, q, g)
	    head = node.remove(head, h)
	    node.free(h)
	 else
	    add_glue_spec(h.spec, g.spec)
	    node.free(g.spec); node.free(g)
	 end
      else
	 set_attr(g,attr_icflag,XKANJI_SKIP)
	 node_insert_after(head, q, g)
      end
   end
end

local function insert_ascii_kanji_xkskip(q, p)
   if luatexja.stack.get_penalty_table('xsp', p.char, 3, ltj.box_stack_level)<=1 then return end
   insert_xkanjiskip_node(q, p.font, p)
end

local function insert_kanji_ascii_xkskip(q, p)
   local g = true
   local c = p.char
   while p.components and p.subtype 
      and math.floor(p.subtype/2)%2==1 do
      p = p.components; c = p.char
   end
   if luatexja.stack.get_penalty_table('xsp', c, 3, ltj.box_stack_level)%2 == 1 then
      if luatexja.stack.get_penalty_table('xsp', nrc, 3, ltj.box_stack_level)%2 == 0 then g = false end
   else g = false
   end
   if g then insert_xkanjiskip_node(q, nrf, p) end
end

local function set_insert_skip_after_achar(p)
   local c = p.char
   while p.components and p.subtype 
      and math.floor(p.subtype/2)%2 == 1 do
      p=node.tail(p.components); c = p.char
   end
  if luatexja.stack.get_penalty_table('xsp', c, 3, ltj.box_stack_level)>=2 then
     insert_skip = after_schar
  else
     insert_skip = no_skip
  end
end

-- lowest part of \kanjiskip 
local function get_kanji_skip_from_jfm(pf)
   if pf then
      local px = { ltj.font_metric_table[pf].size, 
		   ltj.font_metric_table[pf].jfm }
      local i = ltj.metrics[px[2]].kanjiskip
      if i then
	 return { round(i[1]*px[1]), round(i[2]*px[1]), round(i[3]*px[1]) }
      else return nil
      end
   else return nil
   end
end

local function insert_kanji_skip(ope, p)
   local g = node_new(id_glue); g.subtype=0
   if nr_spc[1] or np_spc[1] then
      if kanji_skip.width==max_dimen then -- use kanjiskip from JFM
	 local gx = node_new(id_glue_spec);
	 gx.stretch_order = 0; gx.shrink_order = 0
	 local bk = get_kanji_skip_from_jfm(nrf)
	 local ak = get_kanji_skip_from_jfm(p.font)
	 if bk then
	    if ak then
	       gx.width = round(ltj.ja_diffmet_rule(bk[1], ak[1]))
	       gx.stretch = round(ltj.ja_diffmet_rule(bk[2], ak[2]))
	       gx.shrink = -round(ltj.ja_diffmet_rule(-bk[3], -ak[3]))
	    else
	       gx.width = bk[1]; gx.stretch = bk[2]; gx.shrink = bk[3]
	    end
	 elseif ak then
	    gx.width = ak[1]; gx.stretch = ak[2]; gx.shrink = ak[3]
	 else gx = get_zero_glue() -- fallback
	 end
	 g.spec = gx
      else g.spec=node_copy(kanji_skip)
      end
   else g.spec = get_zero_glue()
   end
   local h = node_prev(p)
   if h  and has_attr(h, attr_icflag)==TEMPORARY then
      if h.id==id_kern then
	 g.spec.width = g.spec.width + h.kern
	 head = node.remove(head, h)
	 node.free(h)
	 set_attr(g,attr_icflag,KANJI_SKIP)
	 ope(head, p, g)
      else
	 add_glue_spec(h.spec, g.spec)
	 node.free(g.spec); node.free(g)
      end
   else
      set_attr(g,attr_icflag,KANJI_SKIP)
      ope(head, p, g)
   end
end

-- When p is a glyph_node ...
local function insks_around_char()
   if is_japanese_glyph_node(np) then
      if insert_skip==after_wchar then
	 insert_kanji_skip(node_insert_before, np)
      elseif insert_skip==after_schar then
	 insert_ascii_kanji_xkskip(nq, np)
      end
      insert_skip=after_wchar
      nrc = np.char; nrf = np.font; nr_spc = np_spc
   else
      if insert_skip==after_wchar then
	 insert_kanji_ascii_xkskip(nq, np)
      end
      set_insert_skip_after_achar(np); nr_spc = np_spc
   end
   nq = np
end

-- Return first and last glyph nodes in a hbox
local first_char = nil
local last_char = nil
local find_first_char = nil
local function check_box(box_ptr)
   local p = box_ptr; local found_visible_node = false
   if not p then 
      find_first_char = false; first_char = nil; last_char = nil
      return true
   end
   while p do
      if p.id==id_glyph then
	 repeat 
	    if find_first_char then
	       first_char = p; find_first_char = false
	    end
	    last_char = p; found_visible_node = true; p=node_next(p)
	    if not p then return found_visible_node end
	 until p.id~=id_glyph
      end
      if p.id==id_hlist then
	 if has_attr(p, attr_icflag)==PACKED then
	    for q in node.traverse_id(id_glyph, p.head) do
	       if find_first_char then
		  first_char = q; find_first_char = false
	       end
	       last_char = q; found_visible_node = true
	    end
	 else
	    if p.shift==0 then
	       if check_box(p.head) then found_visible_node = true end
	    else if find_first_char then 
		  find_first_char = false
	       else 
		  last_char = nil
	       end
	    end
	 end
      elseif p.id==id_ins    or p.id==id_mark
          or p.id==id_adjust or p.id==id_whatsit
          or p.id==id_penalty then
	 p=p
      else
	 found_visible_node = true
	 if find_first_char then 
	    find_first_char = false
	 else 
	    last_char = nil
	 end
      end
      p = node_next(p)
   end
   return found_visible_node
end 

-- When np is a hlist_node ...
local function insks_around_hbox()
   if np.shift==0 then
      find_first_char = true; first_char = nil; last_char = nil
      if check_box(np.head) then
	 -- first char
	 if is_japanese_glyph_node(first_char) then
	    nrc = first_char.char; nrf = first_char.font
	    if insert_skip==after_schar then 
	       insert_ascii_kanji_xkskip(nq, first_char)
	    elseif insert_skip==after_wchar then
	       np_spc = { has_attr(first_char, attr_autospc)==1, 
			  has_attr(first_char, attr_autoxspc)==1 }
	       insert_kanji_skip(node_insert_before, np)
	    end
	    insert_skip = after_wchar
	 elseif first_char then
	    if insert_skip==after_wchar then
	       insert_kanji_ascii_xkskip(nq, first_char)
	    end
	    set_insert_skip_after_achar(first_char)
	 end
	 -- last char
	 if is_japanese_glyph_node(last_char) then
	    insert_skip = after_wchar
	    nrc = last_char.char; nrf = last_char.font
	    nr_spc = { has_attr(last_char, attr_autospc)==1, 
		       has_attr(last_char, attr_autoxspc)==1 }
	    if is_japanese_glyph_node(node_next(np)) then
	       insert_kanji_skip(node_insert_after, np)
	    end
	 elseif last_char then
	    set_insert_skip_after_achar(last_char)
	    nr_spc = { has_attr(last_char, attr_autospc)==1, 
		       has_attr(last_char, attr_autoxspc)==1 }
	 else insert_skip = no_skip
	 end
      else insert_skip = no_skip
      end
   else insert_skip = no_skip
   end
   nq = np
end

-- When np is a penalty ...
local function insks_around_penalty()
   nq = np
end

-- When np is a kern ...
-- 
local function insks_around_kern()
   if np.subtype==1 then -- \kern or \/
      local i = has_attr(np, attr_icflag)
      if not i or i==FROM_JFM then -- \kern
	 insert_skip = no_skip
      elseif i==ITALIC or i==LINE_END or i==TEMPORARY then
	 nq = np
      end
   elseif np.subtype==2 then 
      -- (np = kern from \accent) .. (accent char) .. (kern from \accent) .. (glyph)
      np = node_next(node_next(np))
   else  -- kern from TFM
      nq = np
   end
end

-- When np is a math_node ...
local function insks_around_math()
   local g = { char = -1 }
   if (np.subtype==0) and (insert_skip==after_wchar) then
      insert_kanji_ascii_xkskip(nq, g)
      insert_skip = no_skip
   else
      nq = np; set_insert_skip_after_achar(g); nr_spc = np_spc
   end
end

function ltj.int_insert_kanji_skip(ahead)
   kanji_skip=skip_table_to_spec('kanjiskip')
   xkanji_skip=skip_table_to_spec('xkanjiskip')
   head = ahead
   np = head; nq = nil; insert_skip = no_skip
   while np do
      np_spc = { (has_attr(np, attr_autospc)==1), 
		 (has_attr(np, attr_autoxspc)==1) }
      if np.id==id_glyph then
	 repeat 
	    np_spc = { has_attr(np, attr_autospc)==1, 
		       has_attr(np, attr_autoxspc)==1 }
	    insks_around_char(); np=node_next(np)
	 until (not np) or np.id~=id_glyph
      else
	 if np.id==id_hlist then
	    insks_around_hbox()
	 elseif np.id==id_penalty then
	    insks_around_penalty()
	 elseif np.id==id_kern then
	    insks_around_kern()
	 elseif np.id==id_math then
	    insks_around_math()
	 elseif np.id==id_ins    or np.id==id_mark
             or np.id==id_adjust or np.id==id_whatsit then
	    -- do nothing
	    np = np
	 else
	    -- rule, disc, glue, margin_kern
	    insert_skip = no_skip
	 end
	 np = node_next(np)
      end
   end
   return head
end