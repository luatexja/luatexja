-- error messages
function ltj.error(s)
  tex.error("LuaTeX-ja error: " .. s ); 
end

-- procedures for loading Japanese font metric
jfm={}; jfm.char_type={}; jfm.glue={}; jfm.kern={}

function jfm.define_char_type(t,lt) 
   if not jfm.char_type[t] then jfm.char_type[t]={} end
   jfm.char_type[t].chars=lt 
end
function jfm.define_type_dim(t,l,x,w,h,d,i)
   if not jfm.char_type[t] then jfm.char_type[t]={} end
   jfm.char_type[t].width=w; jfm.char_type[t].height=h;
   jfm.char_type[t].depth=d; jfm.char_type[t].italic=i; 
   jfm.char_type[t].left=l; jfm.char_type[t].down=x
end
function jfm.define_glue(b,a,w,st,sh)
   local j=b*0x800+a
   if not jfm.glue[j] then jfm.glue[j]={} end
   jfm.glue[j].width=w; jfm.glue[j].stretch=st; 
   jfm.glue[j].shrink=sh
end
function jfm.define_kern(b,a,w)
   local j=b*0x800+a
   if not jfm.kern[j] then jfm.kern[j]=w end
end

-- procedures for \loadjfontmetric
ltj.metrics={} -- this table stores all metric informations
ltj.font_metric_table={}

function ltj.search_metric(key)
   for i,v in ipairs(ltj.metrics) do 
      if v.name==key then return i end
   end
   return nil
end

function ltj.loadjfontmetric()
   if string.len(jfm.name)==0 then
      ltj.error("the key of font metric is null"); return nil
   elseif ltj.search_metric(jfm.name) then
      ltj.error("the metric '" .. jfm.name .. "' is already loaded"); return nil
   end
   if jfm.dir~='yoko' then
      ltj.error("jfm.dir must be 'yoko'"); return nil
   end
   local t={}
   t.name=jfm.name
   t.dir=jfm.dir
   t.zw=jfm.zw
   t.zh=jfm.zh
   t.char_type=jfm.char_type
   t.glue=jfm.glue
   t.kern=jfm.kern
   table.insert(ltj.metrics,t)
end

function ltj.find_char_type(c,m)
-- c: character code, m
   if not ltj.metrics[m] then return 0 end
   for i, v in pairs(ltj.metrics[m].char_type) do
      if i~=0 then
        for j,w in pairs(v.chars) do
           if w==c then return i end
        end
      end
   end
   return 0
end

-- procedures for \jfont command.
function ltj.jfontdefA(b)
  ltj.fntbki=font.current()
  local t = token.get_next()
  ltj.cstemp=token.csname_name(t)
  tex.sprint('\\csname ' .. ltj.cstemp .. '\\endcsname\\csname @jfont\\endcsname')
  -- A trick to get font id associated of the argument of \jfont.
  -- font.id() does not seem to work in my environment...
end
function ltj.jfontdefB(s) -- for horizontal font
   local j=ltj.search_metric(s)
   if not j then
      ltj.error("metric named '" .. s .. "' didn't loaded")
      return
   end
   local fn=font.current()
   local f = font.fonts[fn]
   ltj.font_metric_table[fn]={}
   ltj.font_metric_table[fn].jfm=j; ltj.font_metric_table[fn].size=f.size
   tex.sprint('\\expandafter\\expandafter\\expandafter\\global\\expandafter'
              .. '\\def\\csname ' .. ltj.cstemp .. '\\endcsname' 
	      .. '{\\csname luatexja@curjfnt\\endcsname=' .. fn
	      .. ' \\zw=' .. tex.round(f.size*ltj.metrics[j].zw) .. 'sp' 
	      .. '\\zh=' .. tex.round(f.size*ltj.metrics[j].zh) .. 'sp\\relax}')
   font.current(ltj.fntbki); ltj.fntbk = {}; ltj.cstemp = {}
end

-- return true if and only if p is a Japanese character node
function ltj.is_japanese_glyph_node(p)
   return p and (node.type(p.id)=='glyph') 
   and (p.font==node.has_attribute(p,luatexbase.attributes['luatexja@curjfnt']))
end

---------- Kinsoku 
----------
ltj.penalty_table = {}
function ltj.set_penalty_table(m,c,p)
   if not ltj.penalty_table[c] then ltj.penalty_table[c]={} end
   if m=='pre' then
      ltj.penalty_table[c].pre=p
   elseif m=='post' then
      ltj.penalty_table[c].post=p
   end
end
function ltj.get_penalty_table(m,c)
   local i=ltj.penalty_table[c]
   if i then 
      i=(ltj.penalty_table[c])[m]
   end
   if not i then i=0 end
   tex.swrite(i)
end

ltj.inhibit_xsp_table = {}
function ltj.set_inhibit_xsp_table(c,p)
   ltj.inhibit_xsp_table[c]=p
end
function ltj.get_inhibit_xsp_table(c,p)
   local i=ltj.inhibit_xsp_table[c]
   if not i then i=3 end
   tex.swrite(i)
end

----------
----------
function ltj.create_ihb_node()
   local g=node.new(node.id('whatsit'), node.subtype('user_defined'))
   g.user_id=30111; g.type=number; g.value=1
   node.write(g)
end

-- The fullname field of virtual font expresses its metric
function ltj.find_size_metric(px)
   if ltj.is_japanese_glyph_node(px) then
      return ltj.font_metric_table[px.font].size, ltj.font_metric_table[px.font].jfm
   else 
      return nil, nil
   end
end

function ltj.new_jfm_glue(size,mt,bc,ac)
-- mt: metric key, bc, ac: char classes
   local g=nil
   local h
   local w=bc*0x800+ac
   if ltj.metrics[mt].glue[w] then
      h=node.new(node.id('glue_spec'))
      h.width  =tex.round(size*ltj.metrics[mt].glue[w].width)
      h.stretch=tex.round(size*ltj.metrics[mt].glue[w].stretch)
      h.shrink =tex.round(size*ltj.metrics[mt].glue[w].shrink)
      h.stretch_order=0; h.shrink_order=0
      g=node.new(node.id('glue'))
      g.subtype=0; g.spec=h; return g
   elseif ltj.metrics[mt].kern[w] then
      g=node.new(node.id('kern'))
      g.subtype=0; g.kern=tex.round(size*ltj.metrics[mt].kern[w]); return g
   else
      return nil
   end
end

-- The fullname field of virtual font expresses its metric
function ltj.calc_between_two_jchar(q,p)
   -- q, p: node (possibly null)
   local ps,pm,qs,qm,g,h
   if not p then -- q is the last node
      qs, qm = ltj.find_size_metric(q)
      if not qm then 
	 return nil
      else
	 g=ltj.new_jfm_glue(qs,qm,
				node.has_attribute(q,luatexbase.attributes['luatexja@charclass']),
				ltj.find_char_type('boxbdd',qm))
      end
   elseif not q then
      -- p is the first node etc.
      ps, pm = ltj.find_size_metric(p)
      if not pm then
	 return nil
      else
	 g=ltj.new_jfm_glue(ps,pm,
				ltj.find_char_type('boxbdd',pm),
				node.has_attribute(p,luatexbase.attributes['luatexja@charclass']))
      end
   else -- p and q are not nil
      qs, qm = ltj.find_size_metric(q)
      ps, pm = ltj.find_size_metric(p)
      if (not pm) and (not qm) then 
	 -- Both p and q are NOT Japanese glyph node
	 return nil
      elseif (qs==ps) and (qm==pm) then 
	 -- Both p and q are Japanese glyph node, and same metric and size
	 g=ltj.new_jfm_glue(ps,pm,
			    node.has_attribute(q,luatexbase.attributes['luatexja@charclass']),
			    node.has_attribute(p,luatexbase.attributes['luatexja@charclass']))
      elseif not qm then
	 -- q is not Japanese glyph node
	 g=ltj.new_jfm_glue(ps,pm,
			    ltj.find_char_type('jcharbdd',pm),
			    node.has_attribute(p,luatexbase.attributes['luatexja@charclass']))
      elseif not pm then
	 -- p is not Japanese glyph node
	 g=ltj.new_jfm_glue(qs,qm,
			    node.has_attribute(q,luatexbase.attributes['luatexja@charclass']),
			    ltj.find_char_type('jcharbdd',qm))
      else
	 g=ltj.new_jfm_glue(qs,qm,
			    node.has_attribute(q,luatexbase.attributes['luatexja@charclass']),
			    ltj.find_char_type('diffmet',qm))
	 h=ltj.new_jfm_glue(ps,pm,
			    ltj.find_char_type('diffmet',pm),
			    node.has_attribute(p,luatexbase.attributes['luatexja@charclass']))
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
   if node.type(p.id)=='hlist' then 
      return (p.subtype==3)
      -- hlist (subtype=3) is a box by \parindent
   elseif node.type(p.id)=='whatsit' then 
      return (p.subtype==node.subtype('local_par'))
   end
end

function ltj.add_kinsoku_penalty(head,p)
   local c = p.char
   if not ltj.penalty_table[c] then return false; end
   if ltj.penalty_table[c].pre then
      local q = node.prev(p)
      if q and node.type(q.id)=='penalty' then
	 q.penalty=q.penalty+ltj.penalty_table[c].pre
      else 
	 q=node.new(node.id('penalty'))
	 q.penalty=ltj.penalty_table[c].pre
	 node.insert_before(head,p,q)
      end
   end
   if ltj.penalty_table[c].post then
      local q = node.next(p)
      if q and node.type(q.id)=='penalty' then
	 q.penalty=q.penalty+ltj.penalty_table[c].post
	 return false
      else 
	 q=node.new(node.id('penalty'))
	 q.penalty=ltj.penalty_table[c].post
	 node.insert_after(head,p,q)
	 return true
      end
   end
end

-- Insert jfm glue: main routine

function ltj.insert_jfm_glue(head)
   local p = head
   local q = nil  -- the previous node of p
   local g
   local ihb_flag = false
   if not p then 
      return head 
   end
   while p and  ltj.is_parindent_box(p) do p=node.next(p) end
   while p do
      if node.type(p.id)=='whatsit' and p.subtype==44
         and p.user_id==30111 then
	 g=p; p=node.next(p); 
	 ihb_flag=true; head,p=node.remove(head, g)
      else
	 g=ltj.calc_between_two_jchar(q,p)
	 if g and (not ihb_flag) then
	    h = node.insert_before(head,p,g)
	    if not q then head=h end 
	    -- If p is the first node (=head), the skip is inserted
	    -- before head. So we must change head.
	 end
	 q=p; ihb_flag=false
	 if ltj.is_japanese_glyph_node(p) 
            and ltj.add_kinsoku_penalty(head,p) then
	    p=node.next(p)
	 end
	 p=node.next(p)
      end
   end
   -- Insert skip after the last node
   g=ltj.calc_between_two_jchar(q,nil)
   if g then
      h = node.insert_after(head,q,g)
   end
   return head
end



-- Insert \xkanjiskip at the boundaries between Japanese characters 
-- and non-Japanese characters. 
-- We also insert \kanjiskip between Kanji in this function.
ltj.kanji_skip={}
ltj.xkanji_skip={}
ltj.insert_skip=0 
ltj.cx = nil
    -- 0: ``no_skip'', 1: ``after_schar'', 2: ``after_wchar''
-- These variables are ``global'', because we want to avoid to write one large function.
function ltj.insert_kanji_skip(head)
   if tex.count['luatexja@autospc']==0 then
      ltj.kanji_skip=tex.skip['kanjiskip']
   else
      ltj.kanji_skip=node.new(node.id('glue_spec'))
      ltj.kanji_skip.width=0;  ltj.kanji_skip.stretch=0; ltj.kanji_skip.shrink=0
   end
   if tex.count['luatexja@autoxspc']==0 then
      ltj.xkanji_skip=tex.skip['xkanjiskip']
   else
      ltj.xkanji_skip=node.new(node.id('glue_spec'))
      ltj.xkanji_skip.width=0;  ltj.xkanji_skip.stretch=0; ltj.xkanji_skip.shrink=0
   end
   local p=head -- 「現在のnode」
   local q=nil  -- pの一つ前 
   ltj.insert_skip=0
   while p do
      if node.type(p.id)=='glyph' then
	 repeat 
	    ltj.insks_around_char(head,q,p)
	    q=p; p=node.next(p)
	 until (not p) or node.type(p.id)~='glyph'
      else
	 if node.type(p.id) == 'hlist' then
	    ltj.insks_around_hbox(head,q,p)
	 elseif node.type(p.id) == 'penalty' then
	    ltj.insks_around_penalty(head,q,p)
	 elseif node.type(p.id) == 'kern' then
	    ltj.insks_around_kern(head,q,p)
	 elseif node.type(p.id) == 'math' then
	    ltj.insks_around_math(head,q,p)
	 elseif node.type(p.id) == 'ins' or node.type(p.id) == 'mark'
            or node.type(p.id) == 'adjust'
            or node.type(p.id) == 'whatsit' then
	    -- do nothing
	    p=p
	 else
	    -- rule, disc, glue, margin_kern
	    ltj.insert_skip=0
	 end
	 q=p; p=node.next(p)
      end
   end
   return head
end

-- Insert \xkanjiskip before p, a glyph node
-- TODO; ligature
function ltj.insks_around_char(head,q,p)
   local a=ltj.inhibit_xsp_table[p.char]
   if ltj.is_japanese_glyph_node(p) then
      ltj.cx=p.char
      if ltj.is_japanese_glyph_node(q)  then
	 local g = node.new(node.id('glue'))
	 g.subtype=0; g.spec=node.copy(ltj.kanji_skip)
	 node.insert_before(head,p,g)
      elseif ltj.insert_skip==1 then
	 ltj.insert_akxsp(head,q)
      end
      ltj.insert_skip=2
   else
      if not a then a=3 end
      if ltj.insert_skip==2 then
	 ltj.insert_kaxsp(head,q,a)
      end
      if  a>=2 then
	 ltj.insert_skip=1
      else
	 ltj.insert_skip=0
      end
   end
end

function ltj.insert_akxsp(head,q)
   local f = ltj.inhibit_xsp_table[ltj.cx]
   local g
   if f then 
      if f<=1 then return end
   end
   g = node.new(node.id('glue'))
   g.subtype=0; g.spec=node.copy(ltj.xkanji_skip)
   node.insert_after(head,q,g)
end

function ltj.insert_kaxsp(head,q,a)
   local g=true
   local f=ltj.inhibit_xsp_table[ltj.cx]
   if a%2 == 1 then
      if f then 
	 if f%2==0 then g=false end
      end
   else 
      g=false
   end
   if g then
      g = node.new(node.id('glue'))
      g.subtype=0; g.spec=node.copy(ltj.xkanji_skip)
      node.insert_after(head,q,g)
   end
end

-- Return first and last glyph nodes in a hbox
ltj.first_char = nil
ltj.last_char = nil
ltj.find_first_char = nil
function ltj.check_box(bp)
   local p, flag
   p=bp; flag=false
   while p do
      if node.type(p.id)=='glyph' then
	 repeat 
	    if ltj.find_first_char then
	       ltj.first_char=p; ltj.find_first_char=false
	    end
	    ltj.last_char=p; flag=true; p=node.next(p)
	    if not p then return flag end
	 until node.type(p.id)~='glyph'
      end
      if node.type(p.id)=='hlist' then
	 flag=true
	 if p.shift==0 then
	    if ltj.check_box(p.head) then flag=true end
	 else if ltj.find_first_char then 
	       ltj.find_first_char=false
	    else 
	       ltj.last_char=nil
	    end
	 end
      elseif node.type(p.id) == 'ins' or node.type(p.id) == 'mark'
         or node.type(p.id) == 'adjust' 
         or node.type(p.id) == 'whatsit' or node.type(p.id) == 'penalty' then
	 p=p
      else
	 flag=true
	 if ltj.find_first_char then 
	    ltj.find_first_char=false
	 else 
	    ltj.last_char=nil
	 end
      end
      p=node.next(p)
   end
   return flag
end 

-- Insert \xkanjiskip around p, an hbox
function ltj.insks_around_hbox(head,q,p)
   if p.shift==0 then
      ltj.find_first_char=true
      if ltj.check_box(p.head) then
	 -- first char
	 if ltj.is_japanese_glyph_node(ltj.first_char) then
	    ltj.cx=ltj.first_char.char
	    if ltj.insert_skip==1 then 
	       ltj.insert_akxsp(head,q)
	    elseif ltj.insert_skip==2 then
	       local g = node.new(node.id('glue'))
	       g.subtype=0; g.spec=node.copy(ltj.kanji_skip)
	       node.insert_before(head,p,g)
	    end
	    ltj.insert_skip=2
	 elseif ltj.first_char then
	    local a=ltj.inhibit_xsp_table[ltj.first_char.char]
	    if not a then a=3 end
	    if ltj.insert_skip==2 then
	       local g = node.new(node.id('glue'))
	       g.subtype=0; g.spec=node.copy(ltj.kanji_skip)
	       node.insert_after(head,q,g)
	    end
	    if  a>=2 then
	       ltj.insert_skip=1
	    else
	       ltj.insert_skip=0
	    end
	 end
	 -- last char
	 if ltj.is_japanese_glyph_node(ltj.last_char) then
	    if ltj.is_japanese_glyph_node(node.next(p)) then
	       local g = node.new(node.id('glue'))
	       g.subtype=0; g.spec=node.copy(ltj.kanji_skip)
	       node.insert_after(head,p,g)
	    end
	    ltj.insert_skip=2
	 elseif ltj.last_char then
	    local a=ltj.inhibit_xsp_table[ltj.last_char.char]
	    if not a then a=3 end
	    if a>=2 then
	       ltj.insert_skip=1
	    else
	       ltj.insert_skip=0
	    end
	 else ltj.insert_skip=0
	 end
      else ltj.insert_skip=0
      end
   else ltj.insert_skip=0
   end
end

-- Insert \xkanjiskip around p, a penalty
function ltj.insks_around_penalty(head,q,p)
   local r=node.next(p)
   if r  and node.type(r.id)=='glyph' then
      local a=ltj.inhibit_xsp_table[r.char]
      if ltj.is_japanese_glyph_node(r) then
	 ltj.cx=r.char
	 if ltj.is_japanese_glyph_node(p)  then
	    local g = node.new(node.id('glue'))
	    g.subtype=0; g.spec=node.copy(ltj.kanji_skip)
	    node.insert_before(head,r,g)
	 elseif ltj.insert_skip==1 then
	    ltj.insert_akxsp(head,p)
	 end
	 q=p; p=node.next(p)
	 ltj.insert_skip=2
      else
	 if not a then a=3 end
	 if ltj.insert_skip==2 then
	    ltj.insert_kaxsp(head,p,a)
	 end
	 if  a>=2 then
	    ltj.insert_skip=1
	 else
	    ltj.insert_skip=0
	 end
      end
   end
end

-- Insert \xkanjiskip around p, a kern
function ltj.insks_around_kern(head,q,p)
   if p.subtype==1 then -- \kern or \/
      if node.has_attribute(p,luatexbase.attributes['luatexja@icflag']) then
	 p=p -- p is a kern from \/: do nothing
      else
	 ltj.insert_skip=0
      end
   elseif p.subtype==2 then -- \accent: We ignore the accent character.
      local v = node.next(node.next(node.next(p)))
      if v and node.type(v.id)=='glyph' then
	 ltj.insks_around_char(head,q,v)
      end
   end
end

-- Insert \xkanjiskip around p, a math_node
function ltj.insks_around_math(head,q,p)
   local a=ltj.inhibit_xsp_table['math']
   if not a then a=3 end
   if (p.subtype==0) and (ltj.insert_skip==2) then
      ltj.insert_kaxsp(head,q,a)
      ltj.insert_skip=0
   else
      ltj.insert_skip=1
   end
end

-- Shift baseline
function ltj.baselineshift(head)
   local p=head
   local m=false -- is in math mode?
   while p do 
      local v=node.has_attribute(p,luatexbase.attributes['luatexja@yablshift'])
      if v then
	 if node.type(p.id)=='glyph' then
	    p.yoffset=p.yoffset-v
	 elseif node.type(p.id)=='math' then
	    m=(p.subtype==0)
	 end
	 if m then -- boxes and rules are shifted only in math mode
	    if node.type(p.id)=='hlist' or node.type(p.id)=='vlist' then
	       p.shift=p.shift+v
	    elseif node.type(p.id)=='rule' then
	       p.height=p.height-v; p.depth=p.depth+v 
	    end
	 end
      end
      p=node.next(p)
   end
   return head
end


-- main process
function ltj.main_process(head)
   local p = head
   p = ltj.insert_jfm_glue(p)
   p = ltj.insert_kanji_skip(p)
   p = ltj.baselineshift(p)
   p = ltj.set_ja_width(p)
   return p
end

-- TeX's \hss
function ltj.get_hss()
   local hss = node.new(node.id("glue"))
   local hss_spec = node.new(node.id("glue_spec"))
   hss_spec.width = 0
   hss_spec.stretch = 65536
   hss_spec.stretch_order = 2
   hss_spec.shrink = 65536
   hss_spec.shrink_order = 2
   hss.spec = hss_spec
   return hss
end

function ltj.set_ja_width(head)
   local p = head
   local t,s,th, g, q,a
   while p do
      if ltj.is_japanese_glyph_node(p) then
	 t=ltj.metrics[ltj.font_metric_table[p.font].jfm]
	 s=t.char_type[node.has_attribute(p,luatexbase.attributes['luatexja@charclass'])]
	 if not(s.left==0.0 and s.down==0.0 
		and tex.round(s.width*ltj.font_metric_table[p.font].size)==p.width) then
	    -- must be encapsuled by a \hbox
	    head, q = node.remove(head,p)
	    p.next=nil
	    p.yoffset=tex.round(p.yoffset-ltj.font_metric_table[p.font].size*s.down)
	    p.xoffset=tex.round(p.xoffset-ltj.font_metric_table[p.font].size*s.left)
	    node.insert_after(p,p,ltj.get_hss())
	    g=node.hpack(p, tex.round(ltj.font_metric_table[p.font].size*s.width)
			 , 'exactly')
	    g.height=tex.round(ltj.font_metric_table[p.font].size*s.height)
	    g.depth=tex.round(ltj.font_metric_table[p.font].size*s.depth)
	    head,p = node.insert_before(head,q,g)
	    p=q
	 else p=node.next(p)
	 end
      else p=node.next(p)
      end
   end
   return head
end

-- debug
ltj.depth=""
function ltj.to_pt(a) 
   return math.floor(a/65536*100000)/100000
end
function ltj.show_node_list(head)
   local p =head
   local k=ltj.depth
   ltj.depth=ltj.depth .. '.'
   while p do
      local s=node.type(p.id)
      if s == 'glyph' then
	 print(ltj.depth .. ' glyph', p.subtype, unicode.utf8.char(p.char), p.font)
      elseif s=='hlist' then
	 print(ltj.depth .. ' hlist', p.subtype, '(' .. ltj.to_pt(p.height)
	    .. '+' .. ltj.to_pt(p.depth)
	 .. ')x' .. ltj.to_pt(p.width) )
	 ltj.show_node_list(p.head)
	 ltj.depth=k
      elseif s=='whatsit' then
	 print(ltj.depth .. ' whatsit', p.subtype)
      elseif s=='glue' then
	 print(ltj.depth .. ' glue', p.subtype, ltj.to_pt(p.spec.width))
      else
	 print(ltj.depth .. ' ' .. s, s.subtype)
      end
      p=node.next(p)
   end
end



--- the following function is modified from jafontspec.lua (by K. Maeda).
--- Instead of "%", we use U+FFFFF for suppressing spaces.
utf = unicode.utf8
function ltj.process_input_buffer(buffer)
   if utf.len(buffer) > 0 
        and ltj.is_ucs_in_japanese_char(utf.byte(buffer, utf.len(buffer))) then
	buffer = buffer .. string.char(0xF3,0xBF,0xBF,0xBF) -- U+FFFFF
   end
   return buffer
end


---------- Hyphenate

-- 
function ltj.suppress_hyphenate_ja(head)
   local p=head
   while p do 
      if node.type(p.id)=='glyph' and  ltj.is_ucs_in_japanese_char(p.char) then
	 local v = node.has_attribute(p,luatexbase.attributes['luatexja@curjfnt'])
	 if v then 
	    p.font=v 
	    local l=ltj.find_char_type(p.char,ltj.font_metric_table[v].jfm)
	    if not l then l=0 end
	    node.set_attribute(p,luatexbase.attributes['luatexja@charclass'],l)
	 end
	 v=node.has_attribute(p,luatexbase.attributes['luatexja@ykblshift'])
	 if v then 
	    node.set_attribute(p,luatexbase.attributes['luatexja@yablshift'],v)
	 else
	    node.unset_attribute(p,luatexbase.attributes['luatexja@yablshift'])
	 end
	 p.lang=ltj.ja_lang_number
      end
      p=node.next(p)
   end
   lang.hyphenate(head)
   return head -- 共通化のため値を返す
end

-- callbacks
luatexbase.add_to_callback('process_input_buffer', 
   function (buffer)
     return ltj.process_input_buffer(buffer)
   end,'ltj.process_input_buffer')

luatexbase.add_to_callback('pre_linebreak_filter', 
   function (head,groupcode)
     return ltj.main_process(head)
   end,'ltj.pre_linebreak_filter',2)
luatexbase.add_to_callback('hpack_filter', 
  function (head,groupcode,size,packtype)
     return ltj.main_process(head)
  end,'ltj.hpack_filter',2)

--insert before callbacks from luaotfload
luatexbase.add_to_callback('hpack_filter', 
  function (head,groupcode,size,packtype)
     return ltj.suppress_hyphenate_ja(head)
  end,'ltj.hpack_filter_pre',0)
luatexbase.add_to_callback('hyphenate', 
 function (head,tail)
    return ltj.suppress_hyphenate_ja(head)
 end,'ltj.hyphenate')
