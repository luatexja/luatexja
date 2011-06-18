--
-- luatexja/jfmglue.lua
--
luatexbase.provides_module({
  name = 'luatexja.jfmglue',
  date = '2011/06/09',
  version = '0.1',
  description = 'Insertion process of JFM glues and kanjiskip',
})
module('luatexja.jfmglue', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

local ltjb = luatexja.base
local ltjs = luatexja.stack

local node_type = node.type
local node_new = node.new
local node_remove = node.remove
local node_prev = node.prev
local node_next = node.next
local node_copy = node.copy
local node_tail = node.tail
local node_free = node.free
local has_attr = node.has_attribute
local set_attr = node.set_attribute
local node_insert_before = node.insert_before
local node_insert_after = node.insert_after
local round = tex.round

local id_glyph = node.id('glyph')
local id_hlist = node.id('hlist')
local id_vlist = node.id('vlist')
local id_rule = node.id('rule')
local id_ins = node.id('ins')
local id_mark = node.id('mark')
local id_adjust = node.id('adjust')
local id_disc = node.id('disc')
local id_whatsit = node.id('whatsit')
local id_math = node.id('math')
local id_glue = node.id('glue')
local id_kern = node.id('kern')
local id_penalty = node.id('penalty')

local id_glue_spec = node.id('glue_spec')
local id_jglyph = node.id('glyph') + 256
local id_box_like = node.id('hlist') + 256
local id_pbox = node.id('hlist') + 512
local sid_user = node.subtype('user_defined')

local ITALIC = 1
local KINSOKU = 2
local FROM_JFM = 3
local LINE_END = 4
local KANJI_SKIP = 5
local XKANJI_SKIP = 6
local BOXBDD = 7
local PROCESSED = 8
local PACKED = 9

local kanji_skip
local xkanji_skip

local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_autospc = luatexbase.attributes['ltj@autospc']
local attr_autoxspc = luatexbase.attributes['ltj@autoxspc']
local max_dimen = 1073741823



-------------------- Helper functions

local function find_char_class(c,m)
   return m.chars[c] or 0
end

local function get_zero_glue()
   local g = node_new(id_glue_spec)
   g.width = 0; g.stretch_order = 0; g.stretch = 0
   g.shrink_order = 0; g.shrink = 0
   return g
end

local function skip_table_to_spec(n)
   local g = node_new(id_glue_spec)
   local st = ltjs.get_skip_table(n, ltj.box_stack_level)
   g.width = st.width; g.stretch = st.stretch; g.shrink = st.shrink
   g.stretch_order = st.stretch_order; g.shrink_order = st.shrink_order
   return g
end

-- penalty 値の計算
local function add_penalty(p,e)
   if p.penalty>=10000 then
      if e<=-10000 then p.penalty = 0 end
   elseif p.penalty<=-10000 then
      if e>=10000 then p.penalty = 0 end
   else
      p.penalty = p.penalty + e
      if p.penalty>=10000 then p.penalty = 10000
      elseif p.penalty<=-10000 then p.penalty = -10000 end
   end
   return
end

-- 「異なる JFM」の間の調整方法
diffmet_rule = math.two_average
function math.two_add(a,b) return a+b end
function math.two_average(a,b) return (a+b)/2 end

-------------------- idea
-- 2 node の間に glue/kern/penalty を挿入する．
-- 基本方針: char node q と char node p の間

-- 　Np: 「p を核とする塊」
-- 　　first: 最初の node，nuc: p，last: 最後の node
-- 　　id: 核 node の種類
-- 　Nq: 「q を核とする塊」
-- 　　実際の glue は Np.last, Nq.first の間に挿入される
-- 　Bp: Np.last, Nq.first の間の penalty node 達の配列

-- 核の定義：
-- 　node x が non-char node のときは，x のみ
-- 　x が char_node のときは，
-- 　- x が \accent の第二引数だったとき
-- 　  [kern2 kern y kern2] x の 3 node が核に加わる
-- 　- x の直後に \/ 由来 kern があったとき
-- 　  その \/ 由来の kern が核に加わる
-- p, q の走査で無視するもの：
-- 　ins, mark, adjust, whatsit, penalty
--
-- Nq.last .. + .. Bp.first .... Bp[last] .... * .. Np.first
-- +: kern from LINEEND はここに入る
-- *: jfm glue はここに入る

local head -- the head of current list
local last -- the last node of current list
local lp   -- 外側での list 走査時のカーソル

local Np, Nq, Bp
local widow_Bp, widow_Np -- \jcharwidowpenalty 挿入位置管理用

local ihb_flag -- JFM グルー挿入抑止用 flag
               -- on: \inhibitglue 指定時，hlist の周囲

-------------------- hlist 内の文字の検索

local first_char, last_char, find_first_char

local function check_box(box_ptr, box_end)
   local p = box_ptr; local found_visible_node = false
   if not p then 
      find_first_char = false; first_char = nil; last_char = nil
      return true
   end
   while p~=box_end do
      local pid = p.id
      if pid==id_kern then
	 if p.subtype==2 then
	    p = node_next(node_next(node_next(p))); pid = p.id
	 elseif has_attr(p, attr_icflag)==ITALIC then
	    p = node_next(p); pid = p.id
	 end
      end
      if pid==id_glyph then
	 repeat 
	    if find_first_char then 
	       first_char = p; find_first_char = false
	    end
	    last_char = p; found_visible_node = true; p=node_next(p)
	    if not p then return found_visible_node end
	 until p.id~=id_glyph
      end
      if pid==id_hlist then
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
      elseif not (pid==id_ins   or pid==id_mark
		  or pid==id_adjust or pid==id_whatsit
		  or pid==id_penalty) then
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

-------------------- Np の計算と情報取得
-- calc next Np
local function check_next_ickern()
   if lp.id == id_kern and has_attr(lp, attr_icflag)==ITALIC then
      Np.last = lp; lp = node_next(lp)
   else Np.last = Np.nuc end
end

local function calc_np()
   -- We assume lp = node_next(Np.last)
   local pBp = Bp
   local lpi, lpa
   Nq = Np; Bp = {}; Bp[0] = 0; Np = {}; ihb_flag = false 
   while true do
      lpi = lp.id; lpa = has_attr(lp, attr_icflag) or 0
      if lp==last then Np = nil; return
      elseif lpi == id_ins or lpi == id_mark or lpi == id_adjust then
	 lp = node_next(lp)
      elseif lpi == id_penalty then
	 table.insert(Bp, lp); Bp[0] = Bp[0] + 1; lp = node_next(lp)
      elseif lpi == id_whatsit then
	 if lp.subtype==sid_user and lp.user_id==30111 then
	    local lq = node_next(lp)
	    head = node_remove(head, lp); lp = lq; ihb_flag = true
	 else
	    lp = node_next(lp)
	 end
      else -- a `cluster' is found
	 Np.first = lp
	 if lpa >=2 then
	    if lpa == BOXBDD then
	       local lq = node_next(lp)
	       head = node_remove(head, lp); lp = lq
	    else -- id_pbox
	       Np.id = id_pbox; Np.nuc = lp
	       while lp~=last and lpa>=2 and lpa~=7 do
		  lp = node_next(lp); lpa = has_attr(lp, attr_icflag) or 0
	       end
	       Np.last = lp; check_next_ickern(); return
	    end
	 elseif lpi == id_glyph then -- id_[j]glyph
	    if lp.font == has_attr(lp, attr_curjfnt) then Np.id = id_jglyph 
	    else Np.id = id_glyph end
	    Np.nuc = lp; lp = node_next(lp); check_next_ickern(); return
	 elseif lpi == id_hlist then -- hlist
	    Np.nuc = lp; Np.last = lp
	    if lp.shift~=0 then Np.id = id_box_like
	    else Np.id = lpi end
	    lp = node_next(lp); return
	 elseif lpi == id_vlist or lpi == id_rule then -- id_box_like
	    Np.nuc = lp; Np.last = lp; Np.id = id_box_like; break
	 elseif lpi == id_math then -- id_math
	    Np.nuc = lp; lp  = node_next(lp)
	    while lp.id~=id_math do lp  = node_next(lp) end
	    break
	 elseif lpi == id_kern and lp.subtype==2 then -- id_kern
	    lp = node_next(node_next(node_next(lp))) 
	    Np.nuc = lp ; lp = node_next(lp); check_next_ickern(); return
	 else -- id_disc, id_glue, id_kern
	    Np.nuc = lp; break
	 end
      end
   end
   Np.last = lp; Np.id = lpi; lp = node_next(lp)
end

-- extract informations from Np
-- We think that "Np is a Japanese character" if Np.met~=nil,
--            "Np is an alphabetic character" if Np.pre~=nil,
--            "Np is not a character" otherwise.

-- 和文文字のデータを取得
local function set_np_xspc_jachar(c,x)
   Np.class = has_attr(x, attr_jchar_class)
   Np.char = c
   local z = ltj.font_metric_table[x.font]
   Np.size= z.size
   Np.met = ltj.metrics[z.jfm]
   Np.var = z.var
   Np.pre = ltjs.get_penalty_table('pre', c, 0, ltj.box_stack_level)
   Np.post = ltjs.get_penalty_table('post', c, 0, ltj.box_stack_level)
   z = find_char_class('lineend', Np.met)
   local y = Np.met.char_type[Np.class]
   if y.kern and y.kern[z] then 
      Np.lend = round(Np.size*y.kern[z]) 
   else 
      Np.lend = 0 
   end
   y = ltjs.get_penalty_table('xsp', c, 3, ltj.box_stack_level)
   Np.xspc_before = (y>=2)
   Np.xspc_after  = (y%2==1)
   Np.auto_kspc = (has_attr(x, attr_autospc)==1)
   Np.auto_xspc = (has_attr(x, attr_autoxspc)==1)
end

-- 欧文文字のデータを取得
local ligature_head = 1
local ligature_tail = 2
local function set_np_xspc_alchar(c,x, lig)
   if c~=-1 then
      if lig == ligature_head then
	 while x.components and x.subtype and math.floor(x.subtype/2)%2==1 do
	    x = x.components; c = x.char
	 end
      else
	 while x.components and x.subtype and math.floor(x.subtype/2)%2==1 do
	    x = node_tail(x.components); c = x.char
	 end
      end
      Np.pre = ltjs.get_penalty_table('pre', c, 0, ltj.box_stack_level)
      Np.post = ltjs.get_penalty_table('post', c, 0, ltj.box_stack_level)
   else
      Np.pre = 0; Np.post = 0
   end
   Np.met = nil
   local y = ltjs.get_penalty_table('xsp', c, 3, ltj.box_stack_level)
   Np.xspc_before = (y%2==1)
   Np.xspc_after  = (y>=2)
   Np.auto_xspc = (has_attr(x, attr_autoxspc)==1)
end

-- Np の情報取得メインルーチン
local function extract_np()
   local x = Np.nuc
   if Np.id ==  id_jglyph then
      set_np_xspc_jachar(x.char, x)
   elseif Np.id == id_glyph then
      set_np_xspc_alchar(x.char, x, ligature_head)
   elseif Np.id == id_hlist then
      find_first_char = true; first_char = nil; last_char = nil
      if check_box(x.head, nil) then
	 if first_char then
	    if first_char.font == has_attr(first_char, attr_curjfnt) then 
	       set_np_xspc_jachar(first_char.char,first_char)
	    else
	       set_np_xspc_alchar(first_char.char,first_char, ligature_head)
	    end
	 end
      end
   elseif Np.id == id_pbox then --  mikann 
      find_first_char = true; first_char = nil; last_char = nil
      if check_box(Np.first, Np.last) then
	 if first_char then
	    if first_char.font == has_attr(first_char, attr_curjfnt) then 
	       set_np_xspc_jachar(first_char.char,first_char)
	    else
	       set_np_xspc_alchar(first_char.char,first_char, ligature_head)
	    end
	 end
      end
   elseif Np.id == id_disc then 
      find_first_char = true; first_char = nil; last_char = nil
      if check_box(x.replace, nil) then
	 if first_char then
	    if first_char.font == has_attr(first_char, attr_curjfnt) then 
	       set_np_xspc_jachar(first_char.char,first_char)
	    else
	       set_np_xspc_alchar(first_char.char,first_char, ligature_head)
	    end
	 end
      end
   elseif Np.id == id_math then
      set_np_xspc_alchar(-1, x)
   end
end

-- change the information for the next loop
-- (will be done if Np is an alphabetic character or a hlist)
local function after_hlist()
   if last_char then
      if last_char.font == has_attr(last_char, attr_curjfnt) then 
	 set_np_xspc_jachar(last_char.char,last_char, ligature_after)
      else
	 set_np_xspc_alchar(last_char.char,last_char, ligature_after)
      end
   else
      Np.pre = nil; Np.met = nil
   end
end
local function after_alchar()
   local x = Np.nuc
   set_np_xspc_alchar(x.char,x, ligature_after)
end


-------------------- 最下層の処理

local function lineend_fix(g)
   if g and g.id==id_kern then 
      Nq.lend = 0
   elseif Nq.lend and Nq.lend~=0 then
      if not g then
	 g = node_new(id_kern); g.subtype = 1
	 g.kern = -Nq.lend; set_attr(g, attr_icflag, LINEEND)
      elseif g.id==id_kern then
	 g.kern = g.kern - Nq.lend
      else
	 g.spec.width = g.spec.width - Nq.lend
      end
   end
   return g
end

-- change penalties (or create a new penalty, if needed)
local function handle_penalty_normal(pre, post, g)
   local a = (pre or 0) + (post or 0)
   if Bp[0] == 0 then
      if (a~=0 and not(g and g.id==id_kern)) or Nq.lend~=0 then
	 local p = node_new(id_penalty)
	 if a<-10000 then a = -10000 elseif a>10000 then a = 10000 end
	 p.penalty = a
	 head = node_insert_before(head, Np.first, p)
	 Bp[1] = p; Bp[0] = 1; set_attr(p, attr_icflag, KINSOKU)
      end
   else
      for i, v in ipairs(Bp) do add_penalty(v,a) end
   end
end

local function handle_penalty_always(pre, post, g)
   local a = (pre or 0) + (post or 0)
   if Bp[0] == 0 then
      if not (g and g.id==id_glue) or Nq.lend~=0 then
	 local p = node_new(id_penalty)
	 if a<-10000 then a = -10000 elseif a>10000 then a = 10000 end
	 p.penalty = a
	 head = node_insert_before(head, Np.first, p)
	 Bp[1] = p; Bp[0] = 1; set_attr(p, attr_icflag, KINSOKU)
      end
   else
      for i, v in ipairs(Bp) do add_penalty(v,a) end
   end
end

local function handle_penalty_suppress(pre, post, g)
   local a = (pre or 0) + (post or 0)
   if Bp[0] == 0 then
      if g and g.id==id_glue then
	 local p = node_new(id_penalty)
	 p.penalty = 10000; head = node_insert_before(head, Np.first, p)
	 Bp[1] = p; Bp[0] = 1; set_attr(p, attr_icflag, KINSOKU)
      end
   else
      for i, v in ipairs(Bp) do add_penalty(v,a) end
   end
end

-- 和文文字間の JFM glue を node 化
local function new_jfm_glue(Nn, bc, ac)
-- bc, ac: char classes
   local g = nil
   local z = Nn.met.char_type[bc]
   if z.glue and z.glue[ac] then
      local h = node_new(id_glue_spec)
      h.width   = round(Nn.size*z.glue[ac][1])
      h.stretch = round(Nn.size*z.glue[ac][2])
      h.shrink  = round(Nn.size*z.glue[ac][3])
      h.stretch_order=0; h.shrink_order=0
      g = node_new(id_glue)
      g.subtype = 0; g.spec = h
   elseif z.kern and z.kern[ac] then
      g = node_new(id_kern)
      g.subtype = 1; g.kern = round(Nn.size*z.kern[ac])
   end
   if g then set_attr(g, attr_icflag, FROM_JFM) end
   return g
end

-- Nq.last (kern w) .... (glue/kern g) Np.first
local function real_insert(w, g)
   if w~=0 then
      local h = node_new(id_kern)
      set_attr(h, attr_icflag, LINE_END)
      h.kern = Nq.lend; h.subtype = 1
      head = node_insert_after(head, Nq.last, h)
   end
   if g then
      head = node_insert_before(head, Np.first, g)
      Np.first = g
   end
end

-------------------- 和文文字間空白量の決定

-- get kanjiskip
local function get_kanji_skip_from_jfm(Nn)
   local i = Nn.met.kanjiskip
   if i then
      return { round(i[1]*Nn.size), round(i[2]*Nn.size), round(i[3]*Nn.size) }
   else return nil
   end
end
local function get_kanjiskip()
   local g = node_new(id_glue)
   if Np.auto_kspc or Nq.auto_kspc then
      if kanji_skip.width == max_dimen then
	 local gx = node_new(id_glue_spec);
	 gx.stretch_order = 0; gx.shrink_order = 0
	 local bk = get_kanji_skip_from_jfm(Nq)
	 local ak
	 if (Np.met==Nq.met) and (Nq.size==Np.size) and (Nq.var==Np.var) then
	    ak = nil
	 else
	    ak = get_kanji_skip_from_jfm(Np)
	 end
	 if bk then
	    if ak then
	       gx.width = round(diffmet_rule(bk[1], ak[1]))
	       gx.stretch = round(diffmet_rule(bk[2], ak[2]))
	       gx.shrink = -round(diffmet_rule(-bk[3], -ak[3]))
	    else
	       gx.width = bk[1]; gx.stretch = bk[2]; gx.shrink = bk[3]
	    end
	 elseif ak then
	    gx.width = ak[1]; gx.stretch = ak[2]; gx.shrink = ak[3]
	 else gx = get_zero_glue() -- fallback
	 end
	 g.spec = gx
      else g.spec=node_copy(kanji_skip) end
   else
      local gx = get_zero_glue()
      g.spec = gx
   end
   set_attr(g, attr_icflag, KANJI_SKIP)
   return g
end

local function calc_ja_ja_aux(gb,ga)
   if not gb then 
      return ga
   else
      if not ga then return gb end
      local k = node.type(gb.id) .. node.type(ga.id)
      if k == 'glueglue' then 
	 -- 両方とも glue．
	 gb.spec.width   = round(diffmet_rule(gb.spec.width, ga.spec.width))
	 gb.spec.stretch = round(diffmet_rule(gb.spec.stretch,ga.spec.shrink))
	 gb.spec.shrink  = -round(diffmet_rule(-gb.spec.shrink, -ga.spec.shrink))
	 node_free(ga)
	 return gb
      elseif k == 'kernkern' then
	 -- 両方とも kern．
	 gb.kern = round(diffmet_rule(gb.kern, ga.kern))
	 node_free(ga)
	 return gb
      elseif k == 'kernglue' then 
	 -- gb: kern, ga: glue
	 ga.spec.width   = round(diffmet_rule(gb.kern,ga.spec.width))
	 ga.spec.stretch = round(diffmet_rule(ga.spec.stretch, 0))
	 ga.spec.shrink  = -round(diffmet_rule(-ga.spec.shrink, 0))
	 node_free(gb)
	 return ga
      else
	 -- gb: glue, ga: kern
	 gb.spec.width   = round(diffmet_rule(ga.kern, gb.spec.width))
	 gb.spec.stretch = round(diffmet_rule(gb.spec.stretch, 0))
	 gb.spec.shrink  = -round(diffmet_rule(-gb.spec.shrink, 0))
	 node_free(ga)
	 return gb
      end
   end
end

local function calc_ja_ja_glue()
   if  ihb_flag then return nil
   elseif (Nq.size==Np.size) and (Nq.met==Np.met) and (Nq.var==Np.var) then
      return new_jfm_glue(Nq, Nq.class, Np.class)
   else
      local g = new_jfm_glue(Nq, Nq.class,
			     find_char_class('diffmet',Nq.met))
      local h = new_jfm_glue(Np, find_char_class('diffmet',Np.met),
			     Np.class)
      return calc_ja_ja_aux(g,h)
   end
end

-------------------- 和欧文間空白量の決定

-- get xkanjiskip
local function get_xkanji_skip_from_jfm(Nn)
   local i = Nn.met.xkanjiskip
   if i then
      return { round(i[1]*Nn.size), round(i[2]*Nn.size), round(i[3]*Nn.size) }
   else return nil
   end
end
local function get_xkanjiskip(Nn)
   local g = node_new(id_glue)
   if Nq.xspc_after and Np.xspc_before and (Nq.auto_xspc or Np.auto_xspc) then
      if xkanji_skip.width == max_dimen then
	 local gx = node_new(id_glue_spec);
	 gx.stretch_order = 0; gx.shrink_order = 0
	 local bk = get_xkanji_skip_from_jfm(Nn)
	 if bk then
	    gx.width = bk[1]; gx.stretch = bk[2]; gx.shrink = bk[3]
	 else gx = get_zero_glue() -- fallback
	 end
	 g.spec = gx
      else g.spec=node_copy(xkanji_skip) end
   else
      local gx = get_zero_glue()
      g.spec = gx
   end
   set_attr(g, attr_icflag, XKANJI_SKIP)
   return g
end


-------------------- 隣接した「塊」間の処理

local function get_OA_skip()
   if not ihb_flag then
      return new_jfm_glue(Np, find_char_class('jcharbdd',Np.met), Np.class)
   else return nil
   end
end
local function get_OB_skip()
   if not ihb_flag then
      return new_jfm_glue(Nq, Nq.class, find_char_class('jcharbdd',Nq.met))
   else return nil
   end
end

-- (anything) .. jachar
local function handle_np_jachar()
   local g = nil
   if Nq.id==id_jglyph or (Nq.id==id_pbox and Nq.met) then 
      g = calc_ja_ja_glue() or get_kanjiskip() -- M->K
      g = lineend_fix(g)
      handle_penalty_normal(Nq.post, Np.pre, g); real_insert(Nq.lend, g)
   elseif Nq.met then  -- Nq.id==id_hlist
      g = get_OA_skip() or get_kanjiskip() -- O_A->K
      handle_penalty_normal(0, Np.pre, g); real_insert(0, g)
   elseif Nq.pre then 
      g = get_OA_skip() or get_xkanjiskip(Np) -- O_A->X
      handle_penalty_normal(Nq.post, Np.pre, g); real_insert(0, g)
   else
      g = get_OA_skip() -- O_A
      if Nq.id==id_glue then handle_penalty_normal(0, Np.pre, g)
      elseif Nq.id==id_kern then handle_penalty_suppress(0, Np.pre, g)
      else handle_penalty_always(0, Np.pre, g)
      end
      real_insert(0, g)
   end
   -- \jcharwidowpenalty 挿入予定箇所更新
   if ltjs.get_penalty_table('kcat', Np.char, 0, ltj.box_stack_level)%2~=1 then
      widow_Np = Np; widow_Bp = Bp
   end
end

-- jachar .. (anything)
local function handle_nq_jachar()
   local g = nil
   if Np.pre then 
      g = get_OB_skip() or get_xkanjiskip(Nq) -- O_B->X
      g = lineend_fix(g)
      handle_penalty_normal(Nq.post, Np.pre, g); real_insert(Nq.lend, g)
   else
      g = get_OB_skip(); g = lineend_fix(g) -- O_B
      if Np.id==id_glue then handle_penalty_normal(Nq.post, 0, g)
      elseif Np.id==id_kern then handle_penalty_suppress(Nq.post, 0, g)
      else handle_penalty_always(Nq.post, 0, g)
      end
      real_insert(Nq.lend, g)
   end
end

-- (anything) .. (和文文字で終わる hlist)
local function handle_nq_ja_hlist()
   local g = nil
   if Nq.id==id_jglyph or (Nq.id==id_pbox and Nq.pre) then 
      g = get_OB_skip() or get_kanjiskip() -- O_B->K
      g = lineend_fix(g)
      handle_penalty_normal(Nq.post, Np.pre, g); real_insert(Nq.lend, g)
   elseif Nq.met then  -- Nq.id==id_hlist
      g = get_kanjiskip() -- K
      handle_penalty_suppress(0, 0, g); real_insert(0, g)
   elseif Nq.pre then 
      g = get_xkanjiskip(Np) -- X
      handle_penalty_suppress(0, 0, g); real_insert(0, g)
   end
end

-- (和文文字で終わる hlist) .. (anything)
local function handle_np_ja_hlist()
   local g = nil
   if Nq.pre then 
      g = get_xkanjiskip(Nq) -- X
      handle_penalty_suppress(0, 0, g); real_insert(0, g)
   end
end

-------------------- 開始・終了時の処理

-- リスト末尾の処理
local function handle_list_tail()
   Np = Nq
   if mode then
      -- the current list is to be line-breaked:
      if Np.id == id_jglyph or (Np.id==id_pbox and Np.met) then 
	 if Np.lend~=0 then
	    g = node_new(id_kern); g.subtype = 0; g.kern = Np.lend
	    set_attr(g, attr_icflag, LINE_END)
	    node_insert_after(head, Np.last, g)
	 end
      end
      -- Insert \jcharwidowpenalty
      Bp = widow_Bp; Np = widow_Np
      if Np then
	 handle_penalty_normal(0,
			       ltjs.get_penalty_table('jwp', 0, 0, ltj.box_stack_level))
      end
   else
      -- the current list is the contents of a hbox
      if Np.id == id_jglyph or (Np.id==id_pbox and Np.met) then 
	 local g = new_jfm_glue(Np, Np.class, find_char_class('boxbdd',Np.met))
	 if g then
	    set_attr(g, attr_icflag, FROM_JFM)
	    head = node_insert_after(head, Np.last, g)
	 end
      end
      head = node_remove(head, last) -- remove the sentinel
   end
end

-- リスト先頭の処理
local function handle_list_head()
   if Np.id ==  id_jglyph or (Np.id==id_pbox and Np.met) then 
      local g = new_jfm_glue(Np, find_char_class('boxbdd',Np.met), Np.class)
      if g then
	 set_attr(g, attr_icflag, FROM_JFM)
	 if g.id==id_glue then
	    handle_penalty_suppress(0, 0)
	 end
	 head = node_insert_before(head, Np.first, g)
      end
   end
end

-- initialize
local function init_var()
   lp = head; widow_Bp = nil; widow_Np = nil
   kanji_skip=skip_table_to_spec('kanjiskip')
   xkanji_skip=skip_table_to_spec('xkanjiskip')
   if mode then 
      -- the current list is to be line-breaked:
      -- hbox from \parindent is skipped.
      while lp and (lp.id==id_whatsit or ((lp.id==id_hlist) and (lp.subtype==3))) do
	 lp=node_next(lp) end
      last=node.tail(head)
   else 
      -- the current list is the contents of a hbox:
      -- insert a sentinel
      last=node.tail(head); local g = node_new(id_kern)
      node_insert_after(head, last, g); last = g
   end
end

-------------------- 外部から呼ばれる関数

-- main interface
function main(ahead, amode)
   if not ahead then return ahead end
   head = ahead; mode = amode; init_var(); calc_np()
   if Np then 
      extract_np(); handle_list_head()
   else
      if not mode then
	 head = node_remove(head, last) -- remove the sentinel
      end
      return head
   end
   calc_np()
   while Np do
      extract_np()
      -- 挿入部
      if Np.id == id_jglyph then 
	 handle_np_jachar()
      elseif Np.met then 
	 if Np.id==id_hlist then handle_np_ja_hlist()
	 else handle_np_jachar() end
      elseif Nq.met then 
	 if Nq.id==id_hlist then handle_nq_ja_hlist()
	 else handle_nq_jachar() end
      end
      -- Np の後処理
      if Np.id==id_glyph then after_alchar()
      elseif Np.id==id_hlist or Np.id==id_pbox or Np.id==id_disc then after_hlist()
      end
      calc_np()
   end
   handle_list_tail(); return head
end

-- \inhibitglue
function create_inhibitglue_node()
   local g=node_new(id_whatsit, sid_user)
   g.user_id=30111; g.type=100; g.value=1; node.write(g)
end

-- TODO: 二重挿入の回避