--
-- luatexja/jfmglue.lua
--
luatexbase.provides_module({
  name = 'luatexja.jfmglue',
  date = '2012/07/19',
  version = '0.5',
  description = 'Insertion process of JFM glues and kanjiskip',
})
module('luatexja.jfmglue', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

luatexja.load_module('stack');     local ltjs = luatexja.stack
luatexja.load_module('jfont');     local ltjf = luatexja.jfont
luatexja.load_module('pretreat');  local ltjp = luatexja.pretreat

local has_attr = node.has_attribute
local set_attr = node.set_attribute
local insert_before = node.insert_before
local node_next = node.next
local round = tex.round
local uniq_id = 0 -- unique id 
local ltjs_fast_get_penalty_table  = ltjs.fast_get_penalty_table
local ltjf_font_metric_table = ltjf.font_metric_table
local ltjf_find_char_class = ltjf.find_char_class
local node_new = node.new
local node_copy = node.copy

local ligature_head = 1
local ligature_tail = 2

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
local PROCESSED_BEGIN_FLAG = 16

local kanji_skip
local xkanji_skip

local attr_orig_char = luatexbase.attributes['ltj@origchar']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_autospc = luatexbase.attributes['ltj@autospc']
local attr_autoxspc = luatexbase.attributes['ltj@autoxspc']
local attr_uniqid = luatexbase.attributes['ltj@uniqid']
local max_dimen = 1073741823

local function get_attr_icflag(p)
   return (has_attr(p, attr_icflag) or 0)%PROCESSED_BEGIN_FLAG
end

-------------------- Helper functions

local function copy_attr(new, old) 
  -- 仕様が決まるまで off にしておく
end

-- This function is called only for acquiring `special' characters.
local function fast_find_char_class(c,m)
   return m.size_cache.chars[c] or 0
end

local spec_zero_glue = node_new(id_glue_spec)
   spec_zero_glue.width = 0; spec_zero_glue.stretch_order = 0; spec_zero_glue.stretch = 0
   spec_zero_glue.shrink_order = 0; spec_zero_glue.shrink = 0

local function get_zero_spec()
   return node_copy(spec_zero_glue)
end

local function skip_table_to_spec(n)
   local g, st = node_new(id_glue_spec), ltjs.fast_get_skip_table(n)
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
function math.two_average(a,b) return (a+b)*0.5 end

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
      if pid==id_kern and p.subtype==2 then
	 p = node_next(node_next(node_next(p))); pid = p.id -- p must be glyph_node
       end
      if pid==id_glyph then
	 repeat 
	    if find_first_char then 
	       first_char = p; find_first_char = false
	    end
	    last_char = p; found_visible_node = true; p=node_next(p)
	    if (not p) or p==box_end then return found_visible_node end
	 until p.id~=id_glyph
	 pid = p.id -- p must be non-nil
      end
      if pid==id_kern and get_attr_icflag(p)==IC_PROCESSED then
	 p = node_next(p); 
      elseif pid==id_hlist then
	 if PACKED == get_attr_icflag(p) then
	    if find_first_char then
	       first_char = p.head; find_first_char = false
	    end
	    last_char = p.head; found_visible_node = true
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
			   function (Np, lp, Nq) 
			      if Np.nuc then return Np 
			      else 
				 return Np  -- your code
			      end
			   end)
luatexbase.create_callback("luatexja.jfmglue.whatsit_after", "data", 
			   function (stat, Nq, Np) return false end)

-- calc next Np
do

local function set_attr_icflag_processed(p)
   if get_attr_icflag(p)<= ITALIC then 
      --set_attr(p, attr_uniqid, uniq_id) 
      set_attr(p, attr_icflag, PROCESSED) 
   end
end

local function check_next_ickern(lp)
   if lp.id == id_kern and ITALIC == get_attr_icflag(lp) then
      set_attr(lp, attr_icflag, IC_PROCESSED) 
      --set_attr(lp, attr_uniqid, uniq_id) 
      Np.last = lp; return node_next(lp)
   else 
      Np.last = Np.nuc; return lp
   end
end

local function calc_np_pbox(lp, last)
   local uid = has_attr(lp, attr_uniqid)
   Np.first = Np.first or lp; Np.id = id_pbox
   local lpa = KINSOKU -- dummy=
   set_attr(lp, attr_icflag, get_attr_icflag(lp));
   while lp~=last and lpa>=PACKED and lpa<BOXBDD
      and uid == has_attr(lp, attr_uniqid) do
      Np.nuc = lp; --set_attr(lp, attr_uniqid, uniq_id) 
      lp = node_next(lp); lpa = has_attr(lp, attr_icflag)
      -- get_attr_icflag() ではいけない！
   end
   return check_next_ickern(lp)
end


local calc_np_auxtable = {
   [id_glyph] = function (lp) 
		   Np.first, Np.nuc = (Np.first or lp), lp;
		   Np.id = (lp.font == has_attr(lp, attr_curjfnt)) and id_jglyph or id_glyph
		   --set_attr(lp, attr_uniqid, uniq_id) 
		   --set_attr_icflag_processed(lp) treated in ltj-setwidth.lua
		   return true, check_next_ickern(node_next(lp)); 
		end,
   [id_hlist] = function(lp) 
		   Np.first = Np.first or lp; Np.last = lp; Np.nuc = lp; 
		   set_attr_icflag_processed(lp)
		   Np.id = (lp.shift~=0) and id_box_like or id_hlist
		   return true, node_next(lp)
		end,
   box_like = function(lp)
		 Np.first = Np.first or lp; Np.nuc = lp; Np.last = lp;
		 Np.id = id_box_like; set_attr_icflag_processed(lp); 
		 return true, node_next(lp);
	      end,
   skip = function(lp) 
	     set_attr_icflag_processed(lp); return false, node_next(lp)
	  end,
   [id_whatsit] = function(lp) 
		  if lp.subtype==sid_user then
		     if lp.user_id==30111 then
			local lq = node_next(lp); 
			head = node.remove(head, lp); node.free(lp); ihb_flag = true
			return false, lq;
		     else
			set_attr_icflag_processed(lp)
			luatexbase.call_callback("luatexja.jfmglue.whatsit_getinfo",
						 Np, lp, Nq)
			if Np.nuc then 
			   Np.id = id_pbox_w; Np.first = Np.nuc; Np.last = Np.nuc; 
			   return true, node_next(lp)
			else
			   return false, node_next(lp)
			end
		     end
		  else
		     -- we do special treatment for these whatsit nodes.
		     if lp.subtype == sid_start_link or lp.subtype == sid_start_thread then
			Np.first = lp 
		     elseif lp.subtype == sid_end_link or lp.subtype == sid_end_thread then
			Np.first, Nq.last = nil, lp;
		     end
		     set_attr_icflag_processed(lp); return false, node_next(lp)
		  end
		  end,
   [id_math] = function(lp)
		  Np.first, Np.nuc = (Np.first or lp), lp; 
		  set_attr_icflag_processed(lp); lp  = node_next(lp) 
		  while lp.id~=id_math do 
		     set_attr_icflag_processed(lp); lp  = node_next(lp) 
		  end
		  set_attr_icflag_processed(lp); 
		  Np.last, Np.id = lp, id_math;
		  return true, node_next(lp); 
	       end,
   discglue = function(lp)
		 Np.first, Np.nuc, Np.last = (Np.first or lp), lp, lp; 
		 Np.id = lp.id; set_attr_icflag_processed(lp); return true, node_next(lp)
	       end,
   [id_kern] = function(lp) 
		  Np.first = Np.first or lp
		  if lp.subtype==2 then
		     set_attr_icflag_processed(lp); lp = node_next(lp)
		     set_attr_icflag_processed(lp); lp = node_next(lp)
		     set_attr_icflag_processed(lp); lp = node_next(lp)
		     set_attr_icflag_processed(lp); Np.nuc = lp
		     Np.id = (lp.font == has_attr(lp, attr_curjfnt)) and id_jglyph or id_glyph
		     return true, check_next_ickern(node_next(lp)); 
		  else
		     Np.id = id_kern; set_attr_icflag_processed(lp);
		     Np.last = lp; return true, node_next(lp)
		  end
	       end,
   [id_penalty] = function(lp)
		     Bp[#Bp+1] = lp; set_attr_icflag_processed(lp); 
		     return false, node_next(lp)
		  end,
}
calc_np_auxtable[id_vlist]  = calc_np_auxtable.box_like
calc_np_auxtable[id_rule]   = calc_np_auxtable.box_like
calc_np_auxtable[13]        = calc_np_auxtable.box_like
calc_np_auxtable[id_ins]    = calc_np_auxtable.skip
calc_np_auxtable[id_mark]   = calc_np_auxtable.skip
calc_np_auxtable[id_adjust] = calc_np_auxtable.skip
calc_np_auxtable[id_disc]   = calc_np_auxtable.discglue
calc_np_auxtable[id_glue]   = calc_np_auxtable.discglue

local pairs = pairs
function calc_np(lp, last)
   local k 
   -- We assume lp = node_next(Np.last)
   Np, Nq, ihb_flag = Nq, Np, false
   for k in pairs(Np) do Np[k] = nil end
   for k = 1,#Bp do Bp[k] = nil end
   while lp ~= last do
      local lpa = has_attr(lp, attr_icflag) or 0
      -- unbox 由来ノードの検出
      if lpa>=PACKED then
         if lpa == BOXBDD then
	    local lq = node_next(lp) 
            head = node.remove(head, lp); node.free(lp); lp = lq
         else return calc_np_pbox(lp, last)
         end -- id_pbox
      else
	 k, lp = calc_np_auxtable[lp.id](lp)
	 if k then return lp end
      end
   end
   Np = nil; return lp
end

end
local calc_np = calc_np

-- extract informations from Np
-- We think that "Np is a Japanese character" if Np.met~=nil,
--            "Np is an alphabetic character" if Np.pre~=nil,
--            "Np is not a character" otherwise.
do

-- 和文文字のデータを取得
   local attr_jchar_class = luatexbase.attributes['ltj@charclass']
   function set_np_xspc_jachar(Nx, x)
      local m = ltjf_font_metric_table[x.font]
      local c = has_attr(x, attr_orig_char)
      local cls = ltjf_find_char_class(x.char, m)
      if c ~= x.char and  cls==0 then cls = ltjf_find_char_class(-c, m) end
      Nx.class = cls; set_attr(x, attr_jchar_class, cls)
      Nx.lend = m.size_cache.char_type[cls].kern[fast_find_char_class('lineend', m)] or 0
      Nx.met, Nx.var, Nx.char = m, m.var, c
      Nx.pre = ltjs_fast_get_penalty_table('pre', c, 0)
      Nx.post = ltjs_fast_get_penalty_table('post', c, 0)
      local y = ltjs_fast_get_penalty_table('xsp', c, 3)
      Nx.xspc_before, Nx.xspc_after = (y%2==1), (y>=2)
      Nx.auto_kspc, Nx.auto_xspc = (has_attr(x, attr_autospc)==1), (has_attr(x, attr_autoxspc)==1)
   end
   local set_np_xspc_jachar = set_np_xspc_jachar

-- 欧文文字のデータを取得
   local floor = math.floor
   function set_np_xspc_alchar(Nx, c,x, lig)
      if c~=-1 then
	 if lig == ligature_head then
	    while x.components and x.subtype and math.floor(x.subtype*0.5)%2==1 do
	       x = x.components; c = x.char
	    end
	 else
	    while x.components and x.subtype and math.floor(x.subtype*0.5)%2==1 do
	       x = node.tail(x.components); c = x.char
	    end
	 end
	 Nx.pre = ltjs_fast_get_penalty_table('pre', c, 0)
	 Nx.post = ltjs_fast_get_penalty_table('post', c, 0)
	 Nx.char = 'jcharbdd'
      else
	 Nx.pre, Nx.post, Nx.char = 0, 0, -1
      end
      Nx.met = nil
      local y = ltjs_fast_get_penalty_table('xsp', c, 3)
      Nx.xspc_before, Nx.xspc_after = (y%2==1), (y>=2)
      Nx.auto_xspc = (has_attr(x, attr_autoxspc)==1)
   end
   local set_np_xspc_alchar = set_np_xspc_alchar

-- Np の情報取得メインルーチン
   function extract_np()
      local x, i = Np.nuc, Np.id;
      if i ==  id_jglyph then return set_np_xspc_jachar(Np, x)
      elseif i == id_glyph then return set_np_xspc_alchar(Np, x.char, x, ligature_head)
      elseif i == id_hlist then Np.last_char = check_box_high(Np, x.head, nil)
      elseif i == id_pbox then Np.last_char = check_box_high(Np, Np.first, node_next(Np.last))
      elseif i == id_disc then Np.last_char = check_box_high(Np, x.replace, nil)
      elseif i == id_math then return set_np_xspc_alchar(Np, -1, x)
      end
   end
   
   -- change the information for the next loop
   -- (will be done if Nx is an alphabetic character or a hlist)
   function after_hlist(Nx)
      local s = Nx.last_char
      if s then
	 if s.font == has_attr(s, attr_curjfnt) then 
	    set_np_xspc_jachar(Nx, s)
	 else
	    set_np_xspc_alchar(Nx, s.char, s, ligature_tail)
	 end
      else
	 Nx.pre, Nx.met = nil, nil
      end
   end
   
   function after_alchar(Nx)
      local x = Nx.nuc
      return set_np_xspc_alchar(Nx, x.char,x, ligature_tail)
   end

end
local after_hlist, after_alchar, extract_np = after_hlist, after_alchar, extract_np

-------------------- 最下層の処理

local function lineend_fix(g)
   if g and g.id==id_kern then 
      Nq.lend = 0
   elseif Nq.lend~=0 then
      if not g then
	 g = node_new(id_kern); --copy_attr(g, Nq.nuc); 
         g.subtype = 1; g.kern = -Nq.lend;
	 set_attr(g, attr_icflag, LINEEND)
	 --set_attr(g, attr_uniqid, uniq_id) 
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
	 local p = node_new(id_penalty); --copy_attr(p, Nq.nuc)
	 if a<-10000 then a = -10000 elseif a>10000 then a = 10000 end
	 p.penalty = a
	 head = insert_before(head, Np.first, p)
	 Bp[1]=p; 
	 set_attr(p, attr_icflag, KINSOKU)
	 --set_attr(p, attr_uniqid, uniq_id) 
      end
   --else for _, v in pairs(Bp) do v.penalty = v.penalty + a end
   else for _, v in pairs(Bp) do add_penalty(v,a) end
   end
end

local function handle_penalty_always(post, pre, g)
   local a = (pre or 0) + (post or 0)
   if #Bp == 0 then
      if not (g and g.id==id_glue) or Nq.lend~=0 then
	 local p = node_new(id_penalty); --copy_attr(p, Nq.nuc)
	 if a<-10000 then a = -10000 elseif a>10000 then a = 10000 end
	 p.penalty = a
	 head = insert_before(head, Np.first, p)
	 Bp[1]=p
     set_attr(p, attr_icflag, KINSOKU)
     --set_attr(p, attr_uniqid, uniq_id) 
      end
   else for _, v in pairs(Bp) do add_penalty(v,a) end
   end
end

local function handle_penalty_suppress(post, pre, g)
   local a = (pre or 0) + (post or 0)
   if #Bp == 0 then
      if g and g.id==id_glue then
	 local p = node_new(id_penalty); --copy_attr(p, Nq.nuc)
	 p.penalty = 10000; head = insert_before(head, Np.first, p)
	 Bp[1]=p
     set_attr(p, attr_icflag, KINSOKU)
     --set_attr(p, attr_uniqid, uniq_id) 
      end
   else for _, v in pairs(Bp) do add_penalty(v,a) end
   end
end

-- 和文文字間の JFM glue を node 化
local function new_jfm_glue(Nn, bc, ac)
-- bc, ac: char classes
   local z = Nn.met.size_cache.char_type[bc]
   local g = z.glue[ac]
   if g then
      g = node_copy(g); g.spec = node.copy(g.spec);
      --set_attr(g, attr_uniqid, uniq_id)
   elseif z.kern[ac] then
      g = node_new(id_kern); --copy_attr(g, Nn.nuc)
      g.subtype = 1; g.kern = z.kern[ac]
      set_attr(g, attr_icflag, FROM_JFM); --set_attr(g, attr_uniqid, uniq_id)
   end
   return g
end

-- Nq.last (kern w) .... (glue/kern g) Np.first
local function real_insert(w, g)
   if w~=0 then
      local h = node_new(id_kern); --copy_attr(h, Nq.nuc)
      set_attr(h, attr_icflag, LINE_END)
      --set_attr(h, attr_uniqid, uniq_id) 
      h.kern = w; h.subtype = 1
      head = node.insert_after(head, Nq.last, h)
   end
   if g then
      head  = insert_before(head, Np.first, g)
      Np.first = g
   end
end


-------------------- 和文文字間空白量の決定

-- get kanjiskip
local get_kanjiskip

local function get_kanjiskip_normal()
   local g = node_new(id_glue); --copy_attr(g, Nq.nuc)
   g.spec = (Np.auto_kspc or Nq.auto_kspc) and node_copy(kanji_skip) or get_zero_spec()
   set_attr(g, attr_icflag, KANJI_SKIP)
   --set_attr(g, attr_uniqid, uniq_id) 
   return g
end
local function get_kanjiskip_jfm()
   local g = node_new(id_glue); --copy_attr(g, Nq.nuc)
   if Np.auto_kspc or Nq.auto_kspc then
	 local gx = node_new(id_glue_spec);
	 gx.stretch_order, gx.shrink_order = 0, 0
	 local bk = Nq.met.size_cache.kanjiskip
	 local ak
	 if (Np.met.size_cache==Nq.met.size_cache) and (Nq.var==Np.var) then
	    ak = nil
	 else
	    ak = Np.met.size_cache.kanjiskip
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
	 else 
            gx.width, gx.stretch, gx.shrink = 0, 0, 0
	 end
	 g.spec = gx
   else
      g.spec =  get_zero_spec()
   end
   set_attr(g, attr_icflag, KANJI_SKIP)
   --set_attr(g, attr_uniqid, uniq_id) 
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
	 node.free(ga)
	 return gb
      elseif k == 'kernkern' then
	 -- 両方とも kern．
	 gb.kern = round(diffmet_rule(gb.kern, ga.kern))
	 node.free(ga)
	 return gb
      elseif k == 'kernglue' then 
	 -- gb: kern, ga: glue
	 ga.spec.width   = round(diffmet_rule(gb.kern,ga.spec.width))
	 ga.spec.stretch = round(diffmet_rule(ga.spec.stretch, 0))
	 ga.spec.shrink  = -round(diffmet_rule(-ga.spec.shrink, 0))
	 node.free(gb)
	 return ga
      else
	 -- gb: glue, ga: kern
	 gb.spec.width   = round(diffmet_rule(ga.kern, gb.spec.width))
	 gb.spec.stretch = round(diffmet_rule(gb.spec.stretch, 0))
	 gb.spec.shrink  = -round(diffmet_rule(-gb.spec.shrink, 0))
	 node.free(ga)
	 return gb
      end
   end
end

local function calc_ja_ja_glue()
   if  ihb_flag then return nil
   elseif (Nq.met.size_cache==Np.met.size_cache) and (Nq.var==Np.var) then
      return new_jfm_glue(Nq, Nq.class, Np.class)
   else
      return calc_ja_ja_aux(new_jfm_glue(Nq, Nq.class, fast_find_char_class('diffmet',Nq.met)),
			    new_jfm_glue(Np, fast_find_char_class('diffmet',Np.met), Np.class))
   end
end

-------------------- 和欧文間空白量の決定

-- get xkanjiskip
local get_xkanjiskip
local function get_xkanjiskip_normal(Nn)
   local g = node_new(id_glue); --copy_attr(g, Nn.nuc)
   local gx = node_new(id_glue_spec); g.spec = gx
   if Nq.xspc_after and Np.xspc_before and (Nq.auto_xspc or Np.auto_xspc) then
      g.spec = node_copy(xkanji_skip)
   else
      g.spec = get_zero_spec()
   end
   set_attr(g, attr_icflag, XKANJI_SKIP)
   --set_attr(g, attr_uniqid, uniq_id) 
   return g
end
local function get_xkanjiskip_jfm(Nn)
   local g = node_new(id_glue); --copy_attr(g, Nn.nuc)
   if Nq.xspc_after and Np.xspc_before and (Nq.auto_xspc or Np.auto_xspc) then
      local gx = node_new(id_glue_spec);
      gx.stretch_order, gx.shrink_order = 0, 0
      local bk = Nn.met.size_cache.xkanjiskip
      if bk then
         gx.width = bk[1]; gx.stretch = bk[2]; gx.shrink = bk[3]
      else 
         gx.width, gx.stretch, gx.shrink = 0, 0, 0
      end
      g.spec = gx
   else
      g.spec = get_zero_spec()
   end
   set_attr(g, attr_icflag, XKANJI_SKIP)
   --set_attr(g, attr_uniqid, uniq_id) 
   return g
end



-------------------- 隣接した「塊」間の処理

local function get_OA_skip()
   if not ihb_flag then
      return new_jfm_glue(Np, 
        fast_find_char_class(((Nq.id == id_math and -1) or 'jcharbdd'), Np.met), Np.class)
   else return nil
   end
end
local function get_OB_skip()
   if not ihb_flag then
      return new_jfm_glue(Nq, Nq.class, 
        fast_find_char_class(((Np.id == id_math and -1) or'jcharbdd'), Nq.met))
   else return nil
   end
end

-- (anything) .. jachar
local function handle_np_jachar(mode)
   if Nq.id==id_jglyph or ((Nq.id==id_pbox or Nq.id==id_pbox_w) and Nq.met) then 
      local g = lineend_fix(calc_ja_ja_glue() or get_kanjiskip()) -- M->K
      handle_penalty_normal(Nq.post, Np.pre, g); real_insert(Nq.lend, g)
   elseif Nq.met then  -- Nq.id==id_hlist
      local g = get_OA_skip() or get_kanjiskip() -- O_A->K
      handle_penalty_normal(0, Np.pre, g); real_insert(0, g)
   elseif Nq.pre then 
      local g = get_OA_skip() or get_xkanjiskip(Np) -- O_A->X
      if Nq.id==id_hlist then Nq.post = 0 end
      handle_penalty_normal(Nq.post, Np.pre, g); real_insert(0, g)
   else
      local g = get_OA_skip() -- O_A
      if Nq.id==id_glue then handle_penalty_normal(0, Np.pre, g)
      elseif Nq.id==id_kern then handle_penalty_suppress(0, Np.pre, g)
      else handle_penalty_always(0, Np.pre, g)
      end
      real_insert(0, g)
   end
   if mode and ltjs_fast_get_penalty_table('kcat', Np.char, 0)%2~=1 then
      widow_Np.first, widow_Bp, Bp = Np.first, Bp, widow_Bp
   end
end


-- jachar .. (anything)
local function handle_nq_jachar()
    if Np.pre then 
      if Np.id==id_hlist then Np.pre = 0 end
      local g = lineend_fix(get_OB_skip() or get_xkanjiskip(Nq)) -- O_B->X
      handle_penalty_normal(Nq.post, Np.pre, g); real_insert(Nq.lend, g)
   else
      local g = lineend_fix(get_OB_skip()) -- O_B
      if Np.id==id_glue then handle_penalty_normal(Nq.post, 0, g)
      elseif Np.id==id_kern then handle_penalty_suppress(Nq.post, 0, g)
      else handle_penalty_always(Nq.post, 0, g)
      end
      real_insert(Nq.lend, g)
   end
end

-- (anything) .. (和文文字で始まる hlist)
local function handle_np_ja_hlist()
   if Nq.id==id_jglyph or ((Nq.id==id_pbox or Nq.id == id_pbox_w) and Nq.met) then 
      local g = lineend_fix(get_OB_skip() or get_kanjiskip()) -- O_B->K
      handle_penalty_normal(Nq.post, 0, g); real_insert(Nq.lend, g)
   elseif Nq.met then  -- Nq.id==id_hlist
      local g = get_kanjiskip() -- K
      handle_penalty_suppress(0, 0, g); real_insert(0, g)
   elseif Nq.pre then 
      local g = get_xkanjiskip(Np) -- X
      handle_penalty_suppress(0, 0, g); real_insert(0, g)
   end
end

-- (和文文字で終わる hlist) .. (anything)
local function handle_nq_ja_hlist()
   if Np.pre then 
      local g = get_xkanjiskip(Nq) -- X
      handle_penalty_suppress(0, 0, g); real_insert(0, g)
   end
end

-- Nq が前側のクラスタとなることによる修正
local function adjust_nq()
   if Nq.id==id_glyph then after_alchar(Nq)
   elseif Nq.id==id_hlist or Nq.id==id_pbox or Nq.id==id_disc then after_hlist(Nq)
   elseif Nq.id == id_pbox_w then 
      luatexbase.call_callback("luatexja.jfmglue.whatsit_after",
			       false, Nq, Np)
   end
end

-------------------- 開始・終了時の処理

-- リスト末尾の処理
local function handle_list_tail(mode)
   adjust_nq(); Np = Nq
   if mode then
      -- the current list is to be line-breaked:
      if Np.id == id_jglyph or (Np.id==id_pbox and Np.met) then 
	 if Np.lend~=0 then
	    g = node_new(id_kern); g.subtype = 0; g.kern = Np.lend
            --copy_attr(g, Np.nuc); 
            set_attr(g, attr_icflag, BOXBDD)
	    node.insert_after(head, Np.last, g)
	 end
      end
      -- Insert \jcharwidowpenalty
      Bp = widow_Bp; Np = widow_Np; Nq.lend = 0
      if Np.first then
	 handle_penalty_normal(0,
			       ltjs_fast_get_penalty_table('jwp', 0, 0))
      end
   else
      -- the current list is the contents of a hbox
      if Np.id == id_jglyph or (Np.id==id_pbox and Np.met) then 
	 local g = new_jfm_glue(Np, Np.class, fast_find_char_class('boxbdd',Np.met))
	 if g then
	    set_attr(g, attr_icflag, BOXBDD)
	    head = node.insert_after(head, Np.last, g)
	 end
      end
   end
end

-- リスト先頭の処理
local function handle_list_head(par_indented)
   if Np.id ==  id_jglyph or (Np.id==id_pbox and Np.met) then 
      if not ihb_flag then
	 local g = new_jfm_glue(Np, fast_find_char_class(par_indented, Np.met), Np.class)
	 if g then
	    set_attr(g, attr_icflag, BOXBDD)
	    if g.id==id_glue and #Bp==0 then
	       local h = node_new(id_penalty); --copy_attr(h, Np.nuc)
	       h.penalty = 10000; set_attr(h, attr_icflag, BOXBDD)
	    end
	    head = insert_before(head, Np.first, g)
	 end
      end
   end
end

-- initialize
-- return value: (the initial cursor lp), (last node)
local function init_var(mode)
   uniq_id = uniq_id +1
   if uniq_id == 0x7FFFFFF then uniq_id = 0 end
   Bp, widow_Bp, widow_Np = {}, {}, {first = nil}
   kanji_skip=skip_table_to_spec('kanjiskip')
   get_kanjiskip = (kanji_skip.width == max_dimen)
      and get_kanjiskip_jfm or get_kanjiskip_normal
   xkanji_skip=skip_table_to_spec('xkanjiskip')
   get_xkanjiskip = (xkanji_skip.width == max_dimen) 
      and get_xkanjiskip_jfm or get_xkanjiskip_normal
   Np = {
      auto_kspc=nil, auto_xspc=nil, char=nil, class=nil, 
      first=nil, id=nil, last=nil, lend=0, met=nil, nuc=nil, 
      post=nil, pre=nil, xspc_after=nil, xspc_before=nil, 
   }
   Nq = {
      auto_kspc=nil, auto_xspc=nil, char=nil, class=nil, 
      first=nil, id=nil, last=nil, lend=0, met=nil, nuc=nil, 
      post=nil, pre=nil, xspc_after=nil, xspc_before=nil, 
   }
   if mode then 
      -- the current list is to be line-breaked:
      -- hbox from \parindent is skipped.
      local lp, par_indented  = head, 'boxbdd'
      while lp and ((lp.id==id_whatsit and lp.subtype~=sid_user) 
		 or ((lp.id==id_hlist) and (lp.subtype==3))) do
	 if (lp.id==id_hlist) and (lp.subtype==3) then par_indented = 'parbdd' end
	 lp=node_next(lp) end
     return lp, node.tail(head), par_indented
   else 
      -- the current list is the contents of a hbox:
      -- insert a sentinel
      local g = node_new(id_kern)
      node.insert_after(head, node.tail(head), g); last = g
      return head, g, 'boxbdd'
   end
end

local function cleanup(mode, last)
   -- adjust attr_icflag for avoiding error
   tex.setattribute('global', attr_icflag, 0)
   node.free(kanji_skip); node.free(xkanji_skip)
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
      head = node.remove(head, last); node.free(last);-- remove the sentinel
      set_attr(head, attr_icflag, 
               get_attr_icflag(head) + PROCESSED_BEGIN_FLAG);
      return head
   end
end
-------------------- 外部から呼ばれる関数

-- main interface
function main(ahead, mode)
   if not ahead then return ahead end
   head = ahead;
   local lp, last, par_indented = init_var(mode); 
   lp = calc_np(lp, last)
   if Np then 
      extract_np(); handle_list_head(par_indented)
   else
      return cleanup(mode, last)
   end
   lp = calc_np(lp, last)
   while Np do
      extract_np(); adjust_nq()
      -- 挿入部
      if Np.id == id_jglyph then 
         handle_np_jachar(mode)
      elseif Np.met then 
         if Np.id==id_hlist then handle_np_ja_hlist()
         else handle_np_jachar() end
      elseif Nq.met then 
         if Nq.id==id_hlist then handle_nq_ja_hlist()
         else handle_nq_jachar() end
      end
      lp = calc_np(lp, last)
   end
   handle_list_tail(mode)
   return cleanup(mode, last)
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

do

local function whatsit_callback(Np, lp, Nq)
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
local function whatsit_after_callback(s, Nq, Np)
   if not s and Nq.nuc.user_id == 30114 then
      local x, y = node.prev(Nq.nuc), Nq.nuc
      Nq.first, Nq.nuc, Nq.last = x, x, x
      head = node.remove(head, y)
   end
   return s
end

luatexbase.add_to_callback("luatexja.jfmglue.whatsit_getinfo", whatsit_callback,
                           "luatexja.beginpar.np_info", 1)
luatexbase.add_to_callback("luatexja.jfmglue.whatsit_after", whatsit_after_callback,
                           "luatexja.beginpar.np_info_after", 1)

end