------------------------------------------------------------------------
-- MAIN PROCESS STEP 3: insert \xkanjiskip (prefix: none)
------------------------------------------------------------------------

local node_type = node.type
local node_new = node.new
local node_prev = node.prev
local node_next = node.next
local has_attr = node.has_attribute
local node_insert_before = node.insert_before
local node_insert_after = node.insert_after
local node_hpack = node.hpack

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

local attr_icflag = luatexbase.attributes['luatexja@icflag']
local attr_curjfnt = luatexbase.attributes['luatexja@curjfnt']

local kanji_skip
local xkanji_skip
local no_skip = 0
local after_schar = 1
local after_wchar = 2
local insert_skip = no_skip

-- (glyph_node nr) ... (node nq) <GLUE> ,,, (node np)
local np, nq, nrc
local no_skip = 0 
local after_schar = 1
local after_wchar = 2 -- nr is a Japanese glyph_node
local insert_skip = no_skip

local cstb_get_inhibit_xsp_table = ltj.int_get_inhibit_xsp_table

local function is_japanese_glyph_node(p)
   return p and (p.id==id_glyph) 
   and (p.font==has_attr(p,attr_curjfnt))
end

-- the following 2 functions are the lowest part.
-- cx: the Kanji code of np
local function insert_ascii_kanji_xkskip(head,q,cx)
   if cstb_get_inhibit_xsp_table(cx)<=1 then return end
   local g = node_new(id_glue)
   g.subtype = 0; g.spec = node.copy(xkanji_skip)
   node_insert_after(head, q, g)
end

local function insert_kanji_ascii_xkskip(head,q,p)
   local g=true
   local c = p.char
   while p.components and p.subtype 
      and math.floor(p.subtype/2)%2==1 do
      p = p.components; c = p.char
   end
   if cstb_get_inhibit_xsp_table(c)%2 == 1 then
      if cstb_get_inhibit_xsp_table(nrc)%2 == 0 then g = false end
   else g = false
   end
   if g then
      g = node_new(id_glue)
      g.subtype = 0; g.spec = node.copy(xkanji_skip)
      node_insert_after(head, q, g)
   end
end


local function set_insert_skip_after_achar(p)
   local c = p.char
   while p.components and p.subtype 
      and math.floor(p.subtype/2)%2 == 1 do
      p=node.tail(p.components); c = p.char
   end
  if cstb_get_inhibit_xsp_table(c)>=2 then
     insert_skip = after_schar
  else
     insert_skip = no_skip
  end
end

-- When p is a glyph_node ...
local function insks_around_char(head)
   if is_japanese_glyph_node(np) then
      if insert_skip==after_wchar then
	 local g = node_new(id_glue)
	 g.subtype=0; g.spec=node.copy(kanji_skip)
	 node_insert_before(head, np, g)
      elseif insert_skip==after_schar then
	 insert_ascii_kanji_xkskip(head, nq, np.char)
      end
      insert_skip=after_wchar; nrc = np.char
   else
      if insert_skip==after_wchar then
	 insert_kanji_ascii_xkskip(head, nq, np)
      end
      set_insert_skip_after_achar(np)
   end
   nq = np
end

-- Return first and last glyph nodes in a hbox
local first_char = nil
local last_char = nil
local find_first_char = nil
local function check_box(box_ptr)
   local p = box_ptr; local found_visible_node = false
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
	 found_visible_node = true
	 if p.shift==0 then
	    if check_box(p.head) then found_visible_node = true end
	 else if find_first_char then 
	       find_first_char = false
	    else 
	       last_char = nil
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
local function insks_around_hbox(head)
   if np.shift==0 then
      find_first_char = true; first_char = nil; last_char = nil
      if check_box(np.head) then
	 -- first char
	 if is_japanese_glyph_node(first_char) then
	    nrc = first_char.char
	    if insert_skip==after_schar then 
	       insert_ascii_kanji_xkskip(head, nq, first_char.char)
	    elseif insert_skip==after_wchar then
	       local g = node_new(id_glue)
	       g.subtype = 0; g.spec = node.copy(kanji_skip)
	       node_insert_before(head, np, g)
	    end
	    insert_skip = after_wchar
	 elseif first_char then
	    if insert_skip==after_wchar then
	       insert_kanji_ascii_xkskip(head, nq, first_char)
	    end
	    set_insert_skip_after_achar(first_char)
	 end
	 -- last char
	 if is_japanese_glyph_node(last_char) then
	    if is_japanese_glyph_node(node_next(np)) then
	       local g = node_new(id_glue)
	       g.subtype = 0; g.spec = node.copy(kanji_skip)
	       node_insert_after(head, np, g)
	    end
	    insert_skip = after_wchar; nrc = last_char.char
	 elseif last_char then
	    set_insert_skip_after_achar(last_char)
	 else insert_skip = no_skip
	 end
      else insert_skip = no_skip
      end
   else insert_skip = no_skip
   end
   nq = np
end

-- When np is a penalty ...
local function insks_around_penalty(head)
   nq = np
end

-- When np is a kern ...
-- 
local function insks_around_kern(head)
   if np.subtype==1 then -- \kern or \/
      local i = has_attr(np, attr_icflag)
      if not i then -- \kern
	 insert_skip = no_skip
      elseif i==1 then
	 nq = np
      end
   elseif np.subtype==2 then 
      -- (np = kern from \accent) .. (accent char) .. (kern from \accent) .. (glyph)
      np = node_next(node_next(np))
   end
end

-- When np is a math_node ...
local function insks_around_math(head)
   local g = { char = -1 }
   if (np.subtype==0) and (insert_skip==after_wchar) then
      insert_kanji_ascii_xkskip(head, nq, g)
      insert_skip = no_skip
   else
      nq = np; set_insert_skip_after_achar(g)
   end
end

function ltj.int_insert_kanji_skip(head)
   if ltj.auto_spacing then
      kanji_skip=tex.skip['kanjiskip']
   else
      kanji_skip=node_new(id_glue_spec)
      kanji_skip.width=0;  kanji_skip.stretch=0; kanji_skip.shrink=0
   end
   if ltj.auto_xspacing then
      xkanji_skip=tex.skip['xkanjiskip']
   else
      xkanji_skip=node_new(id_glue_spec)
      xkanji_skip.width=0;  xkanji_skip.stretch=0; xkanji_skip.shrink=0
   end
   np = head; nq = nil; insert_skip = no_skip
   while np do
      if np.id==id_glyph then
	 repeat 
	    insks_around_char(head); np=node_next(np)
	 until (not np) or np.id~=id_glyph
      else
	 if np.id==id_hlist then
	    insks_around_hbox(head)
	 elseif np.id==id_penalty then
	    insks_around_penalty(head)
	 elseif np.id==id_kern then
	    insks_around_kern(head)
	 elseif np.id==id_math then
	    insks_around_math(head)
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
