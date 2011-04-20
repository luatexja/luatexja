local node_type = node.type
local has_attr = node.has_attribute
local node_insert_before = node.insert_before
local node_insert_after = node.insert_after
local node_hpack = node.hpack
local round = tex.round
local node_new = node.new
local id_glyph = node.id('glyph')
local id_glue_spec = node.id('glue_spec')
local id_glue = node.id('glue')
local id_whatsit = node.id('whatsit')
local next_node = node.next
local attr_jchar_class = luatexbase.attributes['luatexja@charclass']
local attr_curjfnt = luatexbase.attributes['luatexja@curjfnt']
local attr_yablshift = luatexbase.attributes['luatexja@yablshift']

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

---------- Stack table
---- ltj.stack_ch_table [stack_level] : 情報を格納したテーブル
----   .auto_spacing, .auto_xspacing: \autospacing etc.
----   [chr_code].pre, [chr_code].post, [chr_code].xsp

ltj.stack_ch_table={}; ltj.stack_ch_table[0]={}

local function new_stack_level()
  local i = tex.getcount('ltj@stack@pbp')
  if tex.currentgrouplevel > tex.getcount('ltj@group@level@pbp') then
    i = i+1 -- new stack level
    tex.setcount('ltj@group@level@pbp', tex.currentgrouplevel)
    for j,v in pairs(ltj.stack_ch_table) do -- clear the stack above i
      if j>=i then ltj.stack_ch_table[j]=nil end
    end
    ltj.stack_ch_table[i] = table.fastcopy(ltj.stack_ch_table[i-1])
    tex.setcount('ltj@stack@pbp', i)
  end
  return i
end
function ltj.set_ch_table(g,m,c,p)
  local i = new_stack_level()
  if not ltj.stack_ch_table[i][c] then ltj.stack_ch_table[i][c] = {} end
  ltj.stack_ch_table[i][c][m] = p
  if g=='global' then
    for j,v in pairs(ltj.stack_ch_table) do 
      if not ltj.stack_ch_table[j][c] then ltj.stack_ch_table[j][c] = {} end
      ltj.stack_ch_table[j][c][m] = p
    end
  end
end

local function get_penalty_table(m,c)
  local i = tex.getcount('ltj@stack@pbp')
  i = ltj.stack_ch_table[i][c]
  if i then i=i[m] end
  return i or 0
end

local function get_inhibit_xsp_table(c)
  local i = tex.getcount('ltj@stack@pbp')
  i = ltj.stack_ch_table[i][c]
  if i then i=i.xsp end
  return i or 3
end

--------
function ltj.out_ja_parameter_one(k)
   if k == 'yabaselineshift' then
      tex.write(print_scaled(tex.getattribute('luatexja@yablshift'))..'pt')
   elseif k == 'ykbaselineshift' then
      tex.write(print_scaled(tex.getattribute('luatexja@ykblshift'))..'pt')
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

function ltj.out_ja_parameter_two(k,c)
   if k == 'prebreakpenalty' then
      tex.write(get_penalty_table('pre',c))
   elseif k == 'postbreakpenalty' then
      tex.write(get_penalty_table('post',c))
   elseif k == 'cjkxspmode' then
      local i = get_inhibit_xsp_table(c)
      if i==0 then tex.write('inhibit')
      elseif i==1 then  tex.write('postonly')
      elseif i==2 then  tex.write('preonly')
      else tex.write('allow')
      end
   elseif k == 'asciixspmode' then
      local i = get_inhibit_xsp_table(c)
      if i==0 then tex.write('inhibit')
      elseif i==2 then  tex.write('postonly')
      elseif i==1 then  tex.write('preonly')
      else tex.write('allow')
      end
   end
end


--------- 
function ltj.print_global()
  if ltj.isglobal=='global' then tex.sprint('\\global') end
end

function ltj.create_ihb_node()
   local g=node_new(id_whatsit, node.subtype('user_defined'))
   g.user_id=30111; g.type=number; g.value=1
   node.write(g)
end


local function find_size_metric(px)
   if is_japanese_glyph_node(px) then
      return ltj.font_metric_table[px.font].size, ltj.font_metric_table[px.font].jfm
   else 
      return nil, nil
   end
end

local function new_jfm_glue(size,mt,bc,ac)
-- mt: metric key, bc, ac: char classes
   local g=nil
   local h
   local w=bc*0x800+ac
   if ltj.metrics[mt].glue[w] then
      h=node_new(id_glue_spec)
      h.width  =round(size*ltj.metrics[mt].glue[w].width)
      h.stretch=round(size*ltj.metrics[mt].glue[w].stretch)
      h.shrink =round(size*ltj.metrics[mt].glue[w].shrink)
      h.stretch_order=0; h.shrink_order=0
      g=node_new(id_glue)
      g.subtype=0; g.spec=h; return g
   elseif ltj.metrics[mt].kern[w] then
      g=node_new(node.id('kern'))
      g.subtype=0; g.kern=round(size*ltj.metrics[mt].kern[w]); return g
   else
      return nil
   end
end


function calc_between_two_jchar(q,p)
   -- q, p: node (possibly null)
   local ps,pm,qs,qm,g,h
   if not p then -- q is the last node
      qs, qm = find_size_metric(q)
      if not qm then 
	 return nil
      else
	 g=new_jfm_glue(qs,qm,
			    has_attr(q,attr_jchar_class),
				ltj.find_char_type('boxbdd',qm))
      end
   elseif not q then
      -- p is the first node etc.
      ps, pm = find_size_metric(p)
      if not pm then
	 return nil
      else
	 g=new_jfm_glue(ps,pm,
				ltj.find_char_type('boxbdd',pm),
				has_attr(p,attr_jchar_class))
      end
   else -- p and q are not nil
      qs, qm = find_size_metric(q)
      ps, pm = find_size_metric(p)
      if (not pm) and (not qm) then 
	 -- Both p and q are NOT Japanese glyph node
	 return nil
      elseif (qs==ps) and (qm==pm) then 
	 -- Both p and q are Japanese glyph node, and same metric and size
	 g=new_jfm_glue(ps,pm,
			    has_attr(q,attr_jchar_class),
			    has_attr(p,attr_jchar_class))
      elseif not qm then
	 -- q is not Japanese glyph node
	 g=new_jfm_glue(ps,pm,
			    ltj.find_char_type('jcharbdd',pm),
			    has_attr(p,attr_jchar_class))
      elseif not pm then
	 -- p is not Japanese glyph node
	 g=new_jfm_glue(qs,qm,
			    has_attr(q,attr_jchar_class),
			    ltj.find_char_type('jcharbdd',qm))
      else
	 g=new_jfm_glue(qs,qm,
			    has_attr(q,attr_jchar_class),
			    ltj.find_char_type('diffmet',qm))
	 h=new_jfm_glue(ps,pm,
			    ltj.find_char_type('diffmet',pm),
			    has_attr(p,attr_jchar_class))
	 g=ltj.calc_between_two_jchar_aux(g,h)
      end
   end
   return g
end


-- In the beginning of a hbox created by line breaking, there are the followings:
--   o a hbox by \parindent
--   o a whatsit node which contains local paragraph materials.
-- When we insert jfm glues, we ignore these nodes.
function ltj.is_parindent_box(p)
   if node_type(p.id)=='hlist' then 
      return (p.subtype==3)
      -- hlist (subtype=3) is a box by \parindent
   elseif p.id==id_whatsit then 
      return (p.subtype==node.subtype('local_par'))
   end
end

local function add_kinsoku_penalty(head,p)
   local c = p.char
   local e = get_penalty_table('pre',c)
   if e~=0 then
      local q = node.prev(p)
      if q and node_type(q.id)=='penalty' then
	 q.penalty=q.penalty+e
      else 
	 q=node_new(node.id('penalty'))
	 q.penalty=e
	 node_insert_before(head,p,q)
      end
   end
   e = get_penalty_table('post',c)
   if e~=0 then
      local q = next_node(p)
      if q and node_type(q.id)=='penalty' then
	 q.penalty=q.penalty+e
	 return false
      else 
	 q=node_new(node.id('penalty'))
	 q.penalty=e
	 node_insert_after(head,p,q)
	 return true
      end
   end
end

-- Insert jfm glue: main routine

local function insert_jfm_glue(head)
   local p = head
   local q = nil  -- the previous node of p
   local g
   local ihb_flag = false
   local inserted_after_penalty = false
   if not p then 
      return head 
   end
   while p and  ltj.is_parindent_box(p) do p=next_node(p) end
   while p do
      if p.id==id_whatsit and p.subtype==node.subtype('user_defined')
         and p.user_id==30111 then
	 g=p; p=next_node(p); 
	 ihb_flag=true; head,p=node.remove(head, g)
      else
	 g=calc_between_two_jchar(q,p)
	 if g and (not ihb_flag) then
	    h = node_insert_before(head,p,g)
	    if not q then head=h end 
	    -- If p is the first node (=head), the skip is inserted
	    -- before head. So we must change head.
	 end
	 --if is_japanese_glyph_node(q) then
	 --   node.insert(q, inserted_after_penalty)
	 --end
	 q=p; ihb_flag=false; 
	 if is_japanese_glyph_node(p) 
            and add_kinsoku_penalty(head,p) then
	    p=next_node(p); inserted_after_penalty = true
	 else 
	    inserted_after_penalty = false
	 end
	 p=next_node(p)
      end
   end
   -- Insert skip after the last node
   g=calc_between_two_jchar(q,nil)
   if g then h = node_insert_after(head,q,g) end
   return head
end



-- Insert \xkanjiskip at the boundaries between Japanese characters 
-- and non-Japanese characters. 
-- We also insert \kanjiskip between Kanji in this function.
local kanji_skip={}
local xkanji_skip={}
local cx = nil
local no_skip=0
local after_schar=1
local after_wchar=2
local insert_skip=no_skip


-- In the next two function, cx is the Kanji code.
local function insert_akxsp(head,q)
   if get_inhibit_xsp_table(cx)<=1 then return end
   local g = node_new(id_glue)
   g.subtype=0; g.spec=node.copy(xkanji_skip)
   node_insert_after(head,q,g)
end

local function insert_kaxsp(head,q,p)
   local g=true
   local c=p.char
   while p.components and p.subtype 
      and math.floor(p.subtype/2)%2==1 do
      p=p.components; c = p.char
   end
   if get_inhibit_xsp_table(c)%2 == 1 then
      if get_inhibit_xsp_table(cx)%2==0 then g=false end
   else 
      g=false
   end
   if g then
      g = node_new(id_glue)
      g.subtype=0; g.spec=node.copy(xkanji_skip)
      node_insert_after(head,q,g)
   end
end


local function set_insert_skip_after_achar(p)
   local c=p.char
   while p.components and p.subtype 
      and math.floor(p.subtype/2)%2==1 do
      p=node.tail(p.components); c = p.char
   end
  if get_inhibit_xsp_table(c)>=2 then
     insert_skip=after_schar
  else
     insert_skip=no_skip
  end
end

-- Insert \xkanjiskip before p, a glyph node
local function insks_around_char(head,q,p)
   if is_japanese_glyph_node(p) then
      cx=p.char
      if is_japanese_glyph_node(q)  then
	 local g = node_new(id_glue)
	 g.subtype=0; g.spec=node.copy(kanji_skip)
	 node_insert_before(head,p,g)
      elseif insert_skip==after_schar then
	 insert_akxsp(head,q)
      end
      insert_skip=after_wchar
   else
      if insert_skip==after_wchar then
	 insert_kaxsp(head,q,p)
      end
      set_insert_skip_after_achar(p)
   end
end

-- Return first and last glyph nodes in a hbox
local first_char = nil
local last_char = nil
local find_first_char = nil
local function check_box(bp)
   local p = bp; local  flag = false
   while p do
      local pt = node_type(p.id)
      if pt=='glyph' then
	 repeat 
	    if find_first_char then
	       first_char=p; find_first_char=false
	    end
	    last_char=p; flag=true; p=next_node(p)
	    if not p then return flag end
	 until p.id~=id_glyph
      end
      if pt=='hlist' then
	 flag=true
	 if p.shift==0 then
	    if check_box(p.head) then flag=true end
	 else if find_first_char then 
	       find_first_char=false
	    else 
	       last_char=nil
	    end
	 end
      elseif pt == 'ins' or pt == 'mark'
         or pt == 'adjust' 
         or pt == 'whatsit' or pt == 'penalty' then
	 p=p
      else
	 flag=true
	 if find_first_char then 
	    find_first_char=false
	 else 
	    last_char=nil
	 end
      end
      p=next_node(p)
   end
   return flag
end 

-- Insert \xkanjiskip around p, an hbox
local function insks_around_hbox(head,q,p)
   if p.shift==0 then
      find_first_char=true; first_char=nil; last_char=nil
      if check_box(p.head) then
	 -- first char
	 if is_japanese_glyph_node(first_char) then
	    cx=first_char.char
	    if insert_skip==after_schar then 
	       insert_akxsp(head,q)
	    elseif insert_skip==after_wchar then
	       local g = node_new(id_glue)
	       g.subtype=0; g.spec=node.copy(kanji_skip)
	       node_insert_before(head,p,g)
	    end
	    insert_skip=after_wchar
	 elseif first_char then
	    cx=first_char.char
	    if insert_skip==after_wchar then
	       insert_kaxsp(head,q,first_char)
	    end
	    set_insert_skip_after_achar(first_char)
	 end
	 -- last char
	 if is_japanese_glyph_node(last_char) then
	    if is_japanese_glyph_node(next_node(p)) then
	       local g = node_new(id_glue)
	       g.subtype=0; g.spec=node.copy(kanji_skip)
	       node_insert_after(head,p,g)
	    end
	    insert_skip=after_wchar
	 elseif last_char then
	    set_insert_skip_after_achar(last_char)
	 else insert_skip=no_skip
	 end
      else insert_skip=no_skip
      end
   else insert_skip=no_skip
   end
end

-- Insert \xkanjiskip around p, a penalty
local function insks_around_penalty(head,q,p)
   local r=next_node(p)
   if r  and r.id==id_glyph then
      if is_japanese_glyph_node(r) then
	 cx=r.char
	 if is_japanese_glyph_node(p)  then
	    local g = node_new(id_glue)
	    g.subtype=0; g.spec=node.copy(kanji_skip)
	    node_insert_before(head,r,g)
	 elseif insert_skip==insert_schar then
	    insert_akxsp(head,p)
	 end
	 q=p; p=next_node(p)
	 insert_skip=after_wchar
      else
	 if insert_skip==after_wchar then
	    insert_kaxsp(head,p,r)
	 end
	 set_insert_skip_after_achar(r)
      end
   end
end

-- Insert \xkanjiskip around p, a kern
local function insks_around_kern(head,q,p)
   if p.subtype==1 then -- \kern or \/
      if not has_attr(p,luatexbase.attributes['luatexja@icflag']) then
	 insert_skip=no_skip
      end
   elseif p.subtype==2 then -- \accent: We ignore the accent character.
      local v = next_node(next_node(next_node(p)))
      if v and v.id==id_glyph then
	 insks_around_char(head,q,v)
      end
   end
end

-- Insert \xkanjiskip around p, a math_node
local function insks_around_math(head,q,p)
   local g = { char = -1 }
   if (p.subtype==0) and (insert_skip==after_wchar) then
      insert_kaxsp(head,q,g)
      insert_skip=no_skip
   else
      set_insert_skip_after_achar(g)
   end
end

local function insert_kanji_skip(head)
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
   local p=head -- 「現在のnode」
   local q=nil  -- pの一つ前 
   insert_skip=no_skip
   while p do
      local pt = node_type(p.id)
      if pt=='glyph' then
	 repeat 
	    insks_around_char(head,q,p)
	    q=p; p=next_node(p)
	 until (not p) or p.id~=id_glyph
      else
	 if pt == 'hlist' then
	    insks_around_hbox(head,q,p)
	 elseif pt == 'penalty' then
	    insks_around_penalty(head,q,p)
	 elseif pt == 'kern' then
	    insks_around_kern(head,q,p)
	 elseif pt == 'math' then
	    insks_around_math(head,q,p)
	 elseif pt == 'ins' or pt == 'mark'
            or pt == 'adjust'
            or pt == 'whatsit' then
	    -- do nothing
	    p=p
	 else
	    -- rule, disc, glue, margin_kern
	    insert_skip=no_skip
	 end
	 q=p; p=next_node(p)
      end
   end
   return head
end

-- Shift baseline
local function baselineshift(head)
   local p=head
   local m=false -- is in math mode?
   while p do 
      local v=has_attr(p,attr_yablshift)
      if v then
	 local pt = node_type(p.id)
	 if pt=='glyph' then
	    p.yoffset=p.yoffset-v
	 elseif pt=='math' then
	    m=(p.subtype==0)
	 end
	 if m then -- boxes and rules are shifted only in math mode
	    if pt=='hlist' or pt=='vlist' then
	       p.shift=p.shift+v
	    elseif pt=='rule' then
	       p.height=p.height-v; p.depth=p.depth+v 
	    end
	 end
      end
      p=next_node(p)
   end
   return head
end


--====== Adjust the width of Japanese glyphs

-- TeX's \hss
local function get_hss()
   local hss = node_new(id_glue)
   local hss_spec = node_new(id_glue_spec)
   hss_spec.width = 0
   hss_spec.stretch = 65536
   hss_spec.stretch_order = 2
   hss_spec.shrink = 65536
   hss_spec.shrink_order = 2
   hss.spec = hss_spec
   return hss
end

local function set_ja_width(head)
   local p = head
   local t,s,th, g, q,a
   while p do
      if is_japanese_glyph_node(p) then
	 t=ltj.metrics[ltj.font_metric_table[p.font].jfm]
	 s=t.char_type[has_attr(p,attr_jchar_class)]
	 if not(s.left==0.0 and s.down==0.0 
		and round(s.width*ltj.font_metric_table[p.font].size)==p.width) then
	    -- must be encapsuled by a \hbox
	    head, q = node.remove(head,p)
	    p.next=nil
	    p.yoffset=round(p.yoffset-ltj.font_metric_table[p.font].size*s.down)
	    p.xoffset=round(p.xoffset-ltj.font_metric_table[p.font].size*s.left)
	    node_insert_after(p,p,get_hss())
	    g=node_hpack(p, round(ltj.font_metric_table[p.font].size*s.width)
			 , 'exactly')
	    g.height=round(ltj.font_metric_table[p.font].size*s.height)
	    g.depth=round(ltj.font_metric_table[p.font].size*s.depth)
	    head,p = node_insert_before(head,q,g)
	    p=q
	 else p=next_node(p)
	 end
      else p=next_node(p)
      end
   end
   return head
end

-- main process
local function main_process(head)
   local p = head
   p = insert_jfm_glue(p)
   p = insert_kanji_skip(p)
   p = baselineshift(p)
   p = set_ja_width(p)
   return p
end

-- debug
local depth=""
function ltj.show_node_list(head)
   local p =head; local k = depth
   depth=depth .. '.'
   while p do
      local pt=node_type(p.id)
      if pt == 'glyph' then
	 print(depth .. ' glyph', p.subtype, utf.char(p.char), p.font)
      elseif pt=='hlist' then
	 print(depth .. ' hlist', p.subtype, '(' .. print_scaled(p.height)
	    .. '+' .. print_scaled(p.depth)
	 .. ')x' .. print_scaled(p.width) )
	 ltj.show_node_list(p.head)
	 depth=k
      elseif pt == 'whatsit' then
	 print(depth .. ' whatsit', p.subtype)
      elseif pt == 'glue' then
	 print(depth .. ' glue', p.subtype, print_spec(p.spec))
      else
	 print(depth .. ' ' .. s, s.subtype)
      end
      p=next_node(p)
   end
end



--- the following function is modified from jafontspec.lua (by K. Maeda).
--- Instead of "%", we use U+FFFFF for suppressing spaces.
local function process_input_buffer(buffer)
   local c = utf.byte(buffer, utf.len(buffer))
   local p = node.new(id_glyph)
   p.char = c
   if utf.len(buffer) > 0 
   and ltj.is_ucs_in_japanese_char(p) then
	buffer = buffer .. string.char(0xF3,0xBF,0xBF,0xBF) -- U+FFFFF
   end
   return buffer
end


---------- Hyphenate
local function suppress_hyphenate_ja(head)
   local p
   for p in node.traverse(head) do
      if p.id == id_glyph then
	 local pc=p.char
	 if ltj.is_ucs_in_japanese_char(p) then
	    local v = has_attr(p,attr_curjfnt)
	    if v then 
	       p.font=v 
	       local l=ltj.find_char_type(pc,ltj.font_metric_table[v].jfm) or 0
	       node.set_attribute(p,attr_jchar_class,l)
	    end
	    v=has_attr(p,luatexbase.attributes['luatexja@ykblshift'])
	    if v then 
	       node.set_attribute(p,attr_yablshift,v)
	    else
	       node.unset_attribute(p,attr_yablshift)
	    end
	    p.lang=ltj.ja_lang_number
	 end
      end
   end
   lang.hyphenate(head)
   return head -- 共通化のため値を返す
end

-- callbacks
luatexbase.add_to_callback('process_input_buffer', 
   function (buffer)
     return process_input_buffer(buffer)
   end,'ltj.process_input_buffer')

luatexbase.add_to_callback('pre_linebreak_filter', 
   function (head,groupcode)
     return main_process(head)
   end,'ltj.pre_linebreak_filter',2)
luatexbase.add_to_callback('hpack_filter', 
  function (head,groupcode,size,packtype)
     return main_process(head)
  end,'ltj.hpack_filter',2)

--insert before callbacks from luaotfload
luatexbase.add_to_callback('hpack_filter', 
  function (head,groupcode,size,packtype)
     return suppress_hyphenate_ja(head)
  end,'ltj.hpack_filter_pre',0)
luatexbase.add_to_callback('hyphenate', 
 function (head,tail)
    return suppress_hyphenate_ja(head)
 end,'ltj.hyphenate')
