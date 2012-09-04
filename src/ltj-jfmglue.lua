--
-- luatexja/jfmglue.lua
--
luatexbase.provides_module({
  name = 'luatexja.jfmglue',
  date = '2012/04/25',
  version = '0.4',
  description = 'Insertion process of JFM glues and kanjiskip',
})
module('luatexja.jfmglue', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('stack');     local ltjs = luatexja.stack
luatexja.load_module('jfont');     local ltjf = luatexja.jfont
luatexja.load_module('pretreat');  local ltjp = luatexja.pretreat

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
local table_insert = table.insert
local uniq_id = 0 -- unique id 

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
local id_jglyph = node.id('glyph') + 256      -- Japanese character
local id_box_like = node.id('hlist') + 256    -- vbox, shifted hbox
local id_pbox = node.id('hlist') + 512        -- already processed nodes (by \unhbox)
local id_pbox_w = node.id('hlist') + 513      -- cluster which consists of a whatsit
local sid_user = node.subtype('user_defined')

local sid_start_link = node.subtype('pdf_start_link')
local sid_start_thread = node.subtype('pdf_start_thread')
local sid_end_link = node.subtype('pdf_end_link')
local sid_end_thread = node.subtype('pdf_end_thread')

local ITALIC = 1
local PACKED = 2
local KINSOKU = 3
local FROM_JFM = 4
local LINE_END = 5
local KANJI_SKIP = 6
local XKANJI_SKIP = 7
local PROCESSED = 8
local IC_PROCESSED = 9
local BOXBDD = 15

local kanji_skip
local xkanji_skip

local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_autospc = luatexbase.attributes['ltj@autospc']
local attr_autoxspc = luatexbase.attributes['ltj@autoxspc']
local attr_uniqid = luatexbase.attributes['ltj@uniqid']
local max_dimen = 1073741823

local ltjs_get_penalty_table = ltjs.get_penalty_table
local ltjs_get_skip_table = ltjs.get_skip_table
local ltjf_find_char_class = ltjf.find_char_class
local ltjf_font_metric_table = ltjf.font_metric_table
local ltjf_metrics = ltjf.metrics
local box_stack_level
local par_indented -- is the paragraph indented?

-------------------- Helper functions

-- This function is called only for acquiring `special' characters.
local function fast_find_char_class(c,m)
   return m.chars[c] or 0
end

local spec_zero_glue = node_new(id_glue_spec)
   spec_zero_glue.width = 0; spec_zero_glue.stretch_order = 0; spec_zero_glue.stretch = 0
   spec_zero_glue.shrink_order = 0; spec_zero_glue.shrink = 0

local function get_zero_spec()
   return node_copy(spec_zero_glue)
end

local function skip_table_to_spec(n)
   local g = node_new(id_glue_spec)
   local st = ltjs_get_skip_table(n, box_stack_level)
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

-- Np, Nq, Bp, widow_Bp について
-- Np, Nq は別々のテーブル．
-- 1回のループごとに Nq = Np, Np = (new table) となるのは効率が悪いので，
-- Np <-> Nq 入れ替え，その後 Np をクリアすることでテーブルを再利用．
-- 同様の関係は Bp, widow_Bp にも．


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
   while p and p~=box_end do
      local pid = p.id
      if pid==id_kern then
	 if p.subtype==2 then
	    p = node_next(node_next(node_next(p))); pid = p.id
	 elseif has_attr(p, attr_icflag)==IC_PROCESSED then
	    p = node_next(p); pid = p.id
	 end
      end
      if pid==id_glyph then
	 repeat 
	    if find_first_char then 
	       first_char = p; find_first_char = false
	    end
	    last_char = p; found_visible_node = true; p=node_next(p)
	    if (not p) or p==box_end then return found_visible_node end
	 until p.id~=id_glyph
	 pid = p.id
      end
      if pid==id_hlist then
	 if has_attr(p, attr_icflag)==PACKED then
	    for q in node.traverse_id(id_glyph, p.head) do
	       if find_first_char then
	 	  first_char = q; find_first_char = false
	       end
	       last_char = q; found_visible_node = true; break
	    end
	 else
	    if p.shift==0 then
	       if check_box(p.head, nil) then found_visible_node = true end
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

function check_box_high(Nx, box_ptr, box_end)
   first_char = nil;  last_char = nil;  find_first_char = true
   if check_box(box_ptr, box_end) then
      if first_char then
         if first_char.font == has_attr(first_char, attr_curjfnt) then 
            set_np_xspc_jachar(Nx, first_char)
         else
            set_np_xspc_alchar(Nx, first_char.char,first_char, ligature_head)
         end
      end
   end
   return last_char
end

-------------------- Np の計算と情報取得

luatexbase.create_callback("luatexja.jfmglue.whatsit_getinfo", "data", 
                           function (Np, lp, Nq, box_stack_level) 
                              if Np.nuc then return Np 
                              else 
                                 return Np  -- your code
                              end
                           end)
luatexbase.create_callback("luatexja.jfmglue.whatsit_after", "data", 
                           function (stat, Nq, Np, box_stack_level) return false end)

-- calc next Np
local function set_attr_icflag_processed(p)
   local a = has_attr(p, attr_icflag) or 0
   if a<= ITALIC then 
      set_attr(p, attr_uniqid, uniq_id) 
      set_attr(p, attr_icflag, PROCESSED) 
   end
end

local function check_next_ickern()
   if lp.id == id_kern and has_attr(lp, attr_icflag)==ITALIC then
      set_attr(lp, attr_icflag, IC_PROCESSED) 
      set_attr(lp, attr_uniqid, uniq_id) 
      Np.last = lp; lp = node_next(lp)
   else Np.last = Np.nuc end
end

local function calc_np_pbox()
   local uid = has_attr(lp, attr_uniqid)
   Np.first = Np.first or lp; Np.id = id_pbox
   lpa = KINSOKU -- dummy=
   while lp~=last and lpa>=PACKED and lpa~=BOXBDD
      and has_attr(lp, attr_uniqid) == uid do
      Np.nuc = lp; set_attr(lp, attr_uniqid, uniq_id) 
      lp = node_next(lp); lpa = has_attr(lp, attr_icflag) or 0
   end
   check_next_ickern()
end

local calc_np_auxtable = {
   [id_glyph] = function() 
		   Np.first = Np.first or lp
		   if lp.font == has_attr(lp, attr_curjfnt) then 
		      Np.id = id_jglyph 
		   else 
		      Np.id = id_glyph 
		   end
		   Np.nuc = lp; set_attr_icflag_processed(lp)
		   lp = node_next(lp); check_next_ickern(); return true
		end,
   [id_hlist] = function() 
		   Np.first = Np.first or lp; Np.last = lp; Np.nuc = lp; 
		   set_attr_icflag_processed(lp)
		   if lp.shift~=0 then 
		      Np.id = id_box_like
		   else 
		      Np.id = id_hlist 
		   end
		   lp = node_next(lp); return true
		end,
   [id_vlist] = function()
		   Np.first = Np.first or lp; Np.nuc = lp; Np.last = lp;
		   Np.id = id_box_like; set_attr_icflag_processed(lp); 
		   lp = node_next(lp); return true
		end,
   [id_rule] = function()
		  Np.first = Np.first or lp; Np.nuc = lp; Np.last = lp;
		  Np.id = id_box_like; set_attr_icflag_processed(lp); 
		  lp = node_next(lp); return true
	       end,
   [id_ins] = function() 
		 set_attr_icflag_processed(lp); lp = node_next(lp)
		 return false
	      end,
   [id_mark] = function() 
		  set_attr_icflag_processed(lp); lp = node_next(lp)
		  return false
	       end,
   [id_adjust] = function() 
		    set_attr_icflag_processed(lp); lp = node_next(lp)
		    return false
		 end,
   [id_disc] = function()
		  Np.first = Np.first or lp; 
          Np.nuc = lp; set_attr_icflag_processed(lp); 
		  Np.last = lp; Np.id = id_disc; lp = node_next(lp); return true
	       end,
   [id_whatsit] = function() 
		  if lp.subtype==sid_user then
		     if lp.user_id==30111 then
			local lq = node_next(lp)
			head = node_remove(head, lp); node_free(lp); lp = lq; ihb_flag = true
		     else
			set_attr_icflag_processed(lp)
			luatexbase.call_callback("luatexja.jfmglue.whatsit_getinfo"
						 , Np, lp, Nq, box_stack_level)
			lp = node_next(lp)
			if Np.nuc then 
			   Np.id = id_pbox_w; Np.first = Np.nuc; Np.last = Np.nuc; return true
			end
		     end
		  else
             -- we do special treatment for these whatsit nodes.
             if lp.subtype == sid_start_link or lp.subtype == sid_start_thread then
                Np.first = lp 
             elseif lp.subtype == sid_end_link or lp.subtype == sid_end_thread then
                Nq.last = lp; Np.first = nil
             end
		     set_attr_icflag_processed(lp); lp = node_next(lp)
		  end
		  return false
		  end,
   [id_math] = function()
		  Np.first = Np.first or lp; Np.nuc = lp; 
		  set_attr_icflag_processed(lp); lp  = node_next(lp) 
		  while lp.id~=id_math do 
		     set_attr_icflag_processed(lp); lp  = node_next(lp) 
		  end
		  set_attr_icflag_processed(lp); 
		  Np.last = lp; Np.id = id_math; lp = node_next(lp); 
		  return true
	       end,
   [id_glue] = function()
		  Np.first = Np.first or lp; Np.nuc = lp; set_attr_icflag_processed(lp); 
		  Np.last = lp; Np.id = id_glue; lp = node_next(lp); return true
	       end,
   [id_kern] = function() 
		  Np.first = Np.first or lp
		  if lp.subtype==2 then
		     set_attr_icflag_processed(lp); lp = node_next(lp)
		     set_attr_icflag_processed(lp); lp = node_next(lp)
		     set_attr_icflag_processed(lp); lp = node_next(lp)
		     set_attr_icflag_processed(lp); Np.nuc = lp
		     if lp.font == has_attr(lp, attr_curjfnt) then 
			Np.id = id_jglyph 
		     else
			Np.id = id_glyph 
		     end
		     lp = node_next(lp); check_next_ickern(); 
		  else
		     Np.id = id_kern; set_attr_icflag_processed(lp);
		     Np.last = lp; lp = node_next(lp)
		  end
		  return true
	       end,
   [id_penalty] = function()
		     Bp[#Bp+1] = lp; set_attr_icflag_processed(lp); 
		     lp = node_next(lp); return false
		  end,
   [13] = function()
		  Np.first = Np.first or lp; Np.nuc = lp; Np.last = lp;
		  Np.id = id_box_like; set_attr_icflag_processed(lp); 
		  lp = node_next(lp); return true
	       end,
}

local function calc_np()
   -- We assume lp = node_next(Np.last)
   local lpi, lpa, Nr
   Nr = Nq; for k in pairs(Nr) do Nr[k] = nil end
   Nq = Np; Np = Nr
   for k in pairs(Bp) do Bp[k] = nil end
   ihb_flag = false 
   while lp ~= last do
      lpa = has_attr(lp, attr_icflag) or 0
      if lpa>=PACKED then
         if lpa == BOXBDD then
            local lq = node_next(lp)
            head = node_remove(head, lp); node_free(lp); lp = lq
         else calc_np_pbox(); return 
         end -- id_pbox
      elseif calc_np_auxtable[lp.id]() then return end
   end
   Np = nil; return
end

-- extract informations from Np
-- We think that "Np is a Japanese character" if Np.met~=nil,
--            "Np is an alphabetic character" if Np.pre~=nil,
--            "Np is not a character" otherwise.

-- 和文文字のデータを取得
function set_np_xspc_jachar(Nx, x)
   local z = ltjf_font_metric_table[x.font]
   local c = x.char
   local cls = ltjf_find_char_class(c, z)
   local m = ltjf_metrics[z.jfm]
   set_attr(x, attr_jchar_class, cls)
   Nx.class = cls
   Nx.char = c
   Nx.size= z.size
   Nx.met = m
   Nx.var = z.var
   Nx.pre = ltjs_get_penalty_table('pre', c, 0, box_stack_level)
   Nx.post = ltjs_get_penalty_table('post', c, 0, box_stack_level)
   z = fast_find_char_class('lineend', m)
   local y = m.size_cache[Nx.size].char_type[Nx.class]
   if y.kern and y.kern[z] then 
      Nx.lend = y.kern[z]
   else 
      Nx.lend = 0 
   end
   y = ltjs_get_penalty_table('xsp', c, 3, box_stack_level)
   Nx.xspc_before = (y%2==1)
   Nx.xspc_after  = (y>=2)
   Nx.auto_kspc = (has_attr(x, attr_autospc)==1)
   Nx.auto_xspc = (has_attr(x, attr_autoxspc)==1)
end

-- 欧文文字のデータを取得
local ligature_head = 1
local ligature_tail = 2
function set_np_xspc_alchar(Nx, c,x, lig)
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
      Nx.pre = ltjs_get_penalty_table('pre', c, 0, box_stack_level)
      Nx.post = ltjs_get_penalty_table('post', c, 0, box_stack_level)
      Nx.char = 'jcharbdd'
   else
      Nx.pre = 0; Nx.post = 0; Nx.char = -1
   end
   Nx.met = nil
   local y = ltjs_get_penalty_table('xsp', c, 3, box_stack_level)
   Nx.xspc_before = (y%2==1)
   Nx.xspc_after  = (y>=2)
   Nx.auto_xspc = (has_attr(x, attr_autoxspc)==1)
end

-- Np の情報取得メインルーチン
local function extract_np()
   local x = Np.nuc;
   if Np.id ==  id_jglyph then set_np_xspc_jachar(Np, x)
   elseif Np.id == id_glyph then set_np_xspc_alchar(Np, x.char, x, ligature_head)
   elseif Np.id == id_hlist then Np.last_char = check_box_high(Np, x.head, nil)
   elseif Np.id == id_pbox then Np.last_char = check_box_high(Np, Np.first, node.next(Np.last))
   elseif Np.id == id_disc then Np.last_char = check_box_high(Np, x.replace, nil)
   elseif Np.id == id_math then set_np_xspc_alchar(Np, -1, x)
   end
end

-- change the information for the next loop
-- (will be done if Nx is an alphabetic character or a hlist)
function after_hlist(Nx)
   if Nx.last_char then
      if Nx.last_char.font == has_attr(Nx.last_char, attr_curjfnt) then 
         set_np_xspc_jachar(Nx, Nx.last_char);
      else
         set_np_xspc_alchar(Nx, Nx.last_char.char,Nx.last_char, ligature_tail)
      end
   else
      Nx.pre = nil; Nx.met = nil
   end
end

local function after_alchar(Nx)
   local x = Nx.nuc
   set_np_xspc_alchar(Nx, x.char,x, ligature_tail)
end


-------------------- 最下層の処理

local function lineend_fix(g)
   if g and g.id==id_kern then 
      Nq.lend = 0
   elseif Nq.lend~=0 then
      if not g then
	 g = node_new(id_kern); g.subtype = 1; g.kern = -Nq.lend;
     set_attr(g, attr_icflag, LINEEND)
     set_attr(g, attr_uniqid, uniq_id) 
      elseif g.id==id_kern then
	 g.kern = g.kern - Nq.lend
      else
	 g.spec.width = g.spec.width - Nq.lend
      end
   end
   return g
end

-- change penalties (or create a new penalty, if needed)
local function handle_penalty_normal(post, pre, g)
   local a = (pre or 0) + (post or 0)
   if #Bp == 0 then
      if (a~=0 and not(g and g.id==id_kern)) or Nq.lend~=0 then
	 local p = node_new(id_penalty)
	 if a<-10000 then a = -10000 elseif a>10000 then a = 10000 end
	 p.penalty = a
	 head = node_insert_before(head, Np.first, p)
     table_insert(Bp, p); 
     set_attr(p, attr_icflag, KINSOKU)
     set_attr(p, attr_uniqid, uniq_id) 
      end
   else for i, v in pairs(Bp) do add_penalty(v,a) end
   end
end

local function handle_penalty_always(post, pre, g)
   local a = (pre or 0) + (post or 0)
   if #Bp == 0 then
      if not (g and g.id==id_glue) or Nq.lend~=0 then
	 local p = node_new(id_penalty)
	 if a<-10000 then a = -10000 elseif a>10000 then a = 10000 end
	 p.penalty = a
	 head = node_insert_before(head, Np.first, p)
	 table_insert(Bp, p)
     set_attr(p, attr_icflag, KINSOKU)
     set_attr(p, attr_uniqid, uniq_id) 
      end
   else for i, v in pairs(Bp) do add_penalty(v,a) end
   end
end

local function handle_penalty_suppress(post, pre, g)
   local a = (pre or 0) + (post or 0)
   if #Bp == 0 then
      if g and g.id==id_glue then
	 local p = node_new(id_penalty)
	 p.penalty = 10000; head = node_insert_before(head, Np.first, p)
	 table_insert(Bp, p); 
     set_attr(p, attr_icflag, KINSOKU)
     set_attr(p, attr_uniqid, uniq_id) 
      end
   else for i, v in pairs(Bp) do add_penalty(v,a) end
   end
end

-- 和文文字間の JFM glue を node 化
local function new_jfm_glue(Nn, bc, ac)
-- bc, ac: char classes
   local g = nil
   local z = Nn.met.size_cache[Nn.size].char_type[bc]
   if z.glue and z.glue[ac] then
      local h = node_new(id_glue_spec)
      h.width   = z.glue[ac][1]
      h.stretch = z.glue[ac][2]
      h.shrink  = z.glue[ac][3]
      h.stretch_order=0; h.shrink_order=0
      g = node_new(id_glue)
      g.subtype = 0; g.spec = h
   elseif z.kern and z.kern[ac] then
      g = node_new(id_kern)
      g.subtype = 1; g.kern = z.kern[ac]
   end
   if g then 
      set_attr(g, attr_icflag, FROM_JFM); set_attr(g, attr_uniqid, uniq_id) 
   end
   return g
end

-- Nq.last (kern w) .... (glue/kern g) Np.first
local function real_insert(w, g)
   if w~=0 then
      local h = node_new(id_kern)
      set_attr(h, attr_icflag, LINE_END)
      set_attr(h, attr_uniqid, uniq_id) 
      h.kern = w; h.subtype = 1
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
   local i = Nn.met.size_cache[Nn.size].kanjiskip
   if i then
      return { i[1], i[2], i[3] }
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
	 else node_free(gx); gx = get_zero_spec() -- fallback
	 end
	 g.spec = gx
      else g.spec=node_copy(kanji_skip); node_free(gx) end
   else
      g.spec =  get_zero_spec(); node_free(gx)
   end
   set_attr(g, attr_icflag, KANJI_SKIP)
   set_attr(g, attr_uniqid, uniq_id) 
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
			     fast_find_char_class('diffmet',Nq.met))
      local h = new_jfm_glue(Np, fast_find_char_class('diffmet',Np.met),
			     Np.class)
      return calc_ja_ja_aux(g,h)
   end
end

-------------------- 和欧文間空白量の決定

-- get xkanjiskip
local function get_xkanji_skip_from_jfm(Nn)
   local i = Nn.met.size_cache[Nn.size].xkanjiskip
   if i then
      return { i[1], i[2], i[3] }
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
	 else node_free(gx); gx = get_zero_spec() -- fallback
	 end
	 g.spec = gx
      else g.spec=node_copy(xkanji_skip) end
   else
      g.spec = get_zero_spec()
   end
   set_attr(g, attr_icflag, XKANJI_SKIP)
   set_attr(g, attr_uniqid, uniq_id) 
   return g
end


-------------------- 隣接した「塊」間の処理

local function get_OA_skip()
   if not ihb_flag then
      local c = Nq.char or 'jcharbdd'
      return new_jfm_glue(Np, fast_find_char_class(c,Np.met), Np.class)
   else return nil
   end
end
local function get_OB_skip()
   if not ihb_flag then
      local c = Np.char or 'jcharbdd'
      return new_jfm_glue(Nq, Nq.class, fast_find_char_class(c,Nq.met))
   else return nil
   end
end

-- (anything) .. jachar
local function handle_np_jachar()
   local g
   if Nq.id==id_jglyph or ((Nq.id==id_pbox or Nq.id==id_pbox_w) and Nq.met) then 
      g = calc_ja_ja_glue() or get_kanjiskip() -- M->K
      g = lineend_fix(g)
      handle_penalty_normal(Nq.post, Np.pre, g); real_insert(Nq.lend, g)
   elseif Nq.met then  -- Nq.id==id_hlist
      g = get_OA_skip() or get_kanjiskip() -- O_A->K
      handle_penalty_normal(0, Np.pre, g); real_insert(0, g)
   elseif Nq.pre then 
      g = get_OA_skip() or get_xkanjiskip(Np) -- O_A->X
      if Nq.id==id_hlist then Nq.post = 0 end
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
   if mode and ltjs_get_penalty_table('kcat', Np.char, 0, box_stack_level)%2~=1 then
      widow_Np.first = Np.first; 
      local Bpr = widow_Bp; widow_Bp = Bp; Bp = Bpr
   end
end

-- jachar .. (anything)
local function handle_nq_jachar()
   local g
   if Np.pre then 
      if Np.id==id_hlist then Np.pre = 0 end
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
local function handle_np_ja_hlist()
   local g
   if Nq.id==id_jglyph or ((Nq.id==id_pbox or Nq.id == id_pbox_w) and Nq.met) then 
      g = get_OB_skip() or get_kanjiskip() -- O_B->K
      g = lineend_fix(g)
      handle_penalty_normal(Nq.post, 0, g); real_insert(Nq.lend, g)
   elseif Nq.met then  -- Nq.id==id_hlist
      g = get_kanjiskip() -- K
      handle_penalty_suppress(0, 0, g); real_insert(0, g)
   elseif Nq.pre then 
      g = get_xkanjiskip(Np) -- X
      handle_penalty_suppress(0, 0, g); real_insert(0, g)
   end
end

-- (和文文字で終わる hlist) .. (anything)
local function handle_nq_ja_hlist()
   local g = nil
   if Np.pre then 
      g = get_xkanjiskip(Nq) -- X
      handle_penalty_suppress(0, 0, g); real_insert(0, g)
   end
end

-- Nq が前側のクラスタとなることによる修正
local function adjust_nq()
   if Nq.id==id_glyph then after_alchar(Nq)
   elseif Nq.id==id_hlist or Nq.id==id_pbox or Nq.id==id_disc then after_hlist(Nq)
   elseif Nq.id == id_pbox_w then 
      luatexbase.call_callback("luatexja.jfmglue.whatsit_after",
			       false, Nq, Np, box_stack_level)
   end
end

-------------------- 開始・終了時の処理

-- リスト末尾の処理
local function handle_list_tail()
   adjust_nq(); Np = Nq
   if mode then
      -- the current list is to be line-breaked:
      if Np.id == id_jglyph or (Np.id==id_pbox and Np.met) then 
	 if Np.lend~=0 then
	    g = node_new(id_kern); g.subtype = 0; g.kern = Np.lend
	    set_attr(g, attr_icflag, BOXBDD)
	    node_insert_after(head, Np.last, g)
	 end
      end
      -- Insert \jcharwidowpenalty
      Bp = widow_Bp; Np = widow_Np; Nq.lend = 0
      if Np.first then
	 handle_penalty_normal(0,
			       ltjs_get_penalty_table('jwp', 0, 0, box_stack_level))
      end
   else
      -- the current list is the contents of a hbox
      if Np.id == id_jglyph or (Np.id==id_pbox and Np.met) then 
	 local g = new_jfm_glue(Np, Np.class, fast_find_char_class('boxbdd',Np.met))
	 if g then
	    set_attr(g, attr_icflag, BOXBDD)
	    head = node_insert_after(head, Np.last, g)
	 end
      end
   end
end

-- リスト先頭の処理
local function handle_list_head()
   if Np.id ==  id_jglyph or (Np.id==id_pbox and Np.met) then 
      if not ihb_flag then
	 local g
	 if par_indented then
	    g = new_jfm_glue(Np, fast_find_char_class('parbdd',Np.met), Np.class)
	 else
	    g = new_jfm_glue(Np, fast_find_char_class('boxbdd',Np.met), Np.class)
	 end
	 if g then
	    set_attr(g, attr_icflag, BOXBDD)
	    if g.id==id_glue and #Bp==0 then
	       local h = node_new(id_penalty)
	       h.penalty = 10000; set_attr(h, attr_icflag, BOXBDD)
	    end
	    head = node_insert_before(head, Np.first, g)
	 end
      end
   end
end

-- initialize
local function init_var()
   uniq_id = uniq_id +1
   if uniq_id == 0x7FFFFFF then uniq_id = 0 end
   lp = head; Bp = {}; widow_Bp = {}; widow_Np = {first = nil}
   par_indented = false 
   box_stack_level = ltjp.box_stack_level
   kanji_skip=skip_table_to_spec('kanjiskip')
   xkanji_skip=skip_table_to_spec('xkanjiskip')
   Np = {
      auto_kspc=nil, auto_xspc=nil, char=nil, class=nil, 
      first=nil, id=nil, last=nil, lend=0, met=nil, nuc=nil, 
      post=nil, pre=nil, var=nil, xspc_after=nil, xspc_before=nil, 
   }
   Nq = {
      auto_kspc=nil, auto_xspc=nil, char=nil, class=nil, 
      first=nil, id=nil, last=nil, lend=0, met=nil, nuc=nil, 
      post=nil, pre=nil, var=nil, xspc_after=nil, xspc_before=nil, 
   }
   if mode then 
      -- the current list is to be line-breaked:
      -- hbox from \parindent is skipped.
      while lp and ((lp.id==id_whatsit and lp.subtype~=sid_user) 
		 or ((lp.id==id_hlist) and (lp.subtype==3))) do
	 if (lp.id==id_hlist) and (lp.subtype==3) then par_indented = true end
	 lp=node_next(lp) end
     last=node.tail(head)
   else 
      -- the current list is the contents of a hbox:
      -- insert a sentinelEG
      last=node.tail(head); local g = node_new(id_kern)
      node_insert_after(head, last, g); last = g
   end
end

local function cleanup()
   -- adjust attr_icflag for avoiding error
   tex.attribute[attr_icflag] = -(0x7FFFFFFF)
   node_free(kanji_skip); node_free(xkanji_skip)
   if mode then
      local h = node_next(head)
      if h.id == id_penalty and h.penalty == 10000 then
	 h = h.next
	 if h.id == id_glue and h.subtype == 15 and not h.next then
	    return false
	 end
      end
      return head
   else
      head = node_remove(head, last); node_free(last);-- remove the sentinel
      return head
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
      return cleanup()
   end
   calc_np()
   while Np do
      extract_np(); adjust_nq()
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
      calc_np()
   end
   handle_list_tail()
   return cleanup()
end

-- \inhibitglue

function create_inhibitglue_node()
   local tn = node_new(id_whatsit, sid_user)
   tn.user_id=30111; tn.type=100; tn.value=1
   node.write(tn)
end

-- Node for indicating beginning of a paragraph
-- (for ltjsclasses)
function create_beginpar_node()
   local tn = node_new(id_whatsit, sid_user)
   tn.user_id=30114; tn.type=100; tn.value=1
   node.write(tn)
end

local function whatsit_callback(Np, lp, Nq, bsl)
   if Np and Np.nuc then return Np 
   elseif Np and lp.user_id == 30114 then
      Np.first = lp; Np.nuc = lp; Np.last = lp
      Np.char = 'parbdd'
      Np.met = nil
      Np.pre = 0; Np.post = 0
      Np.xspc_before = false
      Np.xspc_after  = false
      Np.auto_xspc = false
      return Np
   end
end
local function whatsit_after_callback(s, Nq, Np, bsl)
   if not s and Nq.nuc.user_id == 30114 then
      local x, y = node.prev(Nq.nuc), Nq.nuc
      Nq.first, Nq.nuc, Nq.last = x, x, x
      head = node_remove(head, y)
   end
   return s
end

luatexbase.add_to_callback("luatexja.jfmglue.whatsit_getinfo", whatsit_callback,
                           "luatexja.beginpar.np_info", 1)
luatexbase.add_to_callback("luatexja.jfmglue.whatsit_after", whatsit_after_callback,
                           "luatexja.beginpar.np_info_after", 1)

