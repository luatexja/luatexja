--
-- luatexja/ltj-jfmglue.lua
--
luatexbase.provides_module({
  name = 'luatexja.jfmglue',
  date = '2013/04/27',
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
local id_jglyph    = 512 -- Japanese character
local id_box_like  = 256 -- vbox, shifted hbox
local id_pbox      = 257 -- already processed nodes (by \unhbox)
local id_pbox_w    = 258 -- cluster which consists of a whatsit
local sid_user = node.subtype('user_defined')

local sid_start_link = node.subtype('pdf_start_link')
local sid_start_thread = node.subtype('pdf_start_thread')
local sid_end_link = node.subtype('pdf_end_link')
local sid_end_thread = node.subtype('pdf_end_thread')

local ITALIC       = luatexja.icflag_table.ITALIC
local PACKED       = luatexja.icflag_table.PACKED
local KINSOKU      = luatexja.icflag_table.KINSOKU
local FROM_JFM     = luatexja.icflag_table.FROM_JFM
local KANJI_SKIP   = luatexja.icflag_table.KANJI_SKIP
local XKANJI_SKIP  = luatexja.icflag_table.XKANJI_SKIP
local PROCESSED    = luatexja.icflag_table.PROCESSED
local IC_PROCESSED = luatexja.icflag_table.IC_PROCESSED
local BOXBDD       = luatexja.icflag_table.BOXBDD
local PROCESSED_BEGIN_FLAG = luatexja.icflag_table.PROCESSED_BEGIN_FLAG
local kanji_skip
local xkanji_skip
local table_current_stack

local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_icflag = luatexbase.attributes['ltj@icflag']

local function get_attr_icflag(p)
   return (has_attr(p, attr_icflag) or 0)%PROCESSED_BEGIN_FLAG
end

-------------------- Helper functions

local function copy_attr(new, old) 
  -- 仕様が決まるまで off にしておく
end

-- This function is called only for acquiring `special' characters.
local function fast_find_char_class(c,m)
   return m.chars[c] or 0
end

-- 文字クラスの決定
local function slow_find_char_class(c, m, oc)
   local xc = c or oc
   local cls = ltjf_find_char_class(oc, m)
   if xc ~= oc and  cls==0 then cls = ltjf_find_char_class(-xc, m) end
   return cls, xc
end

local zero_glue = node_new(id_glue)
spec_zero_glue = node_new(id_glue_spec) -- must be public, since mentioned from other sources
local spec_zero_glue = spec_zero_glue
   spec_zero_glue.width = 0; spec_zero_glue.stretch_order = 0; spec_zero_glue.stretch = 0
   spec_zero_glue.shrink_order = 0; spec_zero_glue.shrink = 0
   zero_glue.spec = spec_zero_glue

local function skip_table_to_spec(n)
   local g, st = node_new(id_glue_spec), ltjs.fast_get_skip_table(n)
   g.width = st.width; g.stretch = st.stretch; g.shrink = st.shrink
   g.stretch_order = st.stretch_order; g.shrink_order = st.shrink_order
   return g
end


-- penalty 値の計算
local function add_penalty(p,e)
   local pp = p.penalty
   if pp>=10000 then
      if e<=-10000 then pp = 0 end
   elseif pp<=-10000 then
      if e>=10000 then pp = 0 end
   else
      pp = pp + e
      if pp>=10000 then      p.penalty = 10000
      elseif pp<=-10000 then p.penalty = -10000 
      else                   p.penalty = pp end
   end
   return
end

-- 「異なる JFM」の間の調整方法
diffmet_rule = math.two_paverage
function math.two_add(a,b) return a+b end
function math.two_average(a,b) return (a+b)*0.5 end
function math.two_paverage(a,b) return (a+b)*0.5 end
function math.two_pleft(a,b) return a end
function math.two_pright(a,b) return b end

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
      find_first_char = false; last_char = nil
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
	    if (not p) or p==box_end then 
               return found_visible_node 
            end
	 until p.id~=id_glyph
	 pid = p.id -- p must be non-nil
      end
      if pid==id_kern then
	 if get_attr_icflag(p)==IC_PROCESSED then
	    -- do nothing
	 elseif p.subtype==2 then
	    p = node_next(node_next(p)); 
	    -- Note that another node_next will be executed outside this if-statement.
	 else
	    found_visible_node = true
	    if find_first_char then 
	       find_first_char = false
	    else 
	       last_char = nil
	    end
	 end
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
      elseif pid==id_math then
	 if find_first_char then 
	    first_char = p; find_first_char = false
	 end
	 last_char = p; found_visible_node = true
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
      local first_char = first_char
      if first_char then
         if first_char.id==id_glyph then
	    if first_char.font == (has_attr(first_char, attr_curjfnt) or -1) then 
	       set_np_xspc_jachar(Nx, first_char)
	    else
	       set_np_xspc_alchar(Nx, first_char.char,first_char, ligature_head)
	    end
	 else -- math_node
	    set_np_xspc_alchar(Nx, -1,first_char)
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
      set_attr(p, attr_icflag, PROCESSED) 
   end
end

local function check_next_ickern(lp)
   if lp.id == id_kern and ITALIC == get_attr_icflag(lp) then
      set_attr(lp, attr_icflag, IC_PROCESSED)
      Np.last = lp; return node_next(lp)
   else 
      Np.last = Np.nuc; return lp
   end
end

local function calc_np_pbox(lp, last)
   Np.first = Np.first or lp; Np.id = id_pbox
   local lpa = KINSOKU -- dummy=
   set_attr(lp, attr_icflag, get_attr_icflag(lp));
   while lp~=last and lpa>=PACKED and lpa<BOXBDD do
      Np.nuc = lp;
      lp = node_next(lp); lpa = has_attr(lp, attr_icflag) or 0
      -- get_attr_icflag() ではいけない！
   end
   return check_next_ickern(lp)
end


local calc_np_auxtable = {
   [id_glyph] = function (lp)
		   Np.first, Np.nuc = (Np.first or lp), lp;
		   Np.id = (lp.font == (has_attr(lp, attr_curjfnt) or -1)) and id_jglyph or id_glyph
		   --set_attr_icflag_processed(lp) treated in ltj-setwidth.lua
		   return true, check_next_ickern(node_next(lp)); 
		end,
   [id_hlist] = function(lp) 
		   Np.first = Np.first or lp; Np.last = lp; Np.nuc = lp; 
		   set_attr(lp, attr_icflag, PROCESSED)
		   --set_attr_icflag_processed(lp)
		   Np.id = (lp.shift~=0) and id_box_like or id_hlist
		   return true, node_next(lp)
		end,
   box_like = function(lp)
		 Np.first = Np.first or lp; Np.nuc = lp; Np.last = lp;
		 Np.id = id_box_like; set_attr(lp, attr_icflag, PROCESSED)
		 -- set_attr_icflag_processed(lp); 
		 return true, node_next(lp);
	      end,
   skip = function(lp) 
	     set_attr(lp, attr_icflag, PROCESSED) 
	     -- set_attr_icflag_processed(lp); 
	     return false, node_next(lp)
	  end,
   [id_whatsit] = function(lp) 
		  if lp.subtype==sid_user then
		     if lp.user_id==luatexja.userid_table.IHB then
			local lq = node_next(lp); 
			head = node.remove(head, lp); node.free(lp); ihb_flag = true
			return false, lq;
		     else
			set_attr(lp, attr_icflag, PROCESSED)
			-- set_attr_icflag_processed(lp)
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
		     set_attr(lp, attr_icflag, PROCESSED)
		     -- set_attr_icflag_processed(lp); 
		     return false, node_next(lp)
		  end
		  end,
   [id_math] = function(lp)
		  Np.first, Np.nuc = (Np.first or lp), lp; 
		  set_attr(lp, attr_icflag, PROCESSED) -- set_attr_icflag_processed(lp); 
		  lp  = node_next(lp) 
		  while lp.id~=id_math do 
		     set_attr(lp, attr_icflag, PROCESSED) -- set_attr_icflag_processed(lp);
		     lp  = node_next(lp) 
		  end
		  set_attr(lp, attr_icflag, PROCESSED) -- set_attr_icflag_processed(lp); 
		  Np.last, Np.id = lp, id_math;
		  return true, node_next(lp); 
	       end,
   discglue = function(lp)
		 Np.first, Np.nuc, Np.last = (Np.first or lp), lp, lp; 
		 Np.id = lp.id; set_attr(lp, attr_icflag, PROCESSED) -- set_attr_icflag_processed(lp); 
		 return true, node_next(lp)
	       end,
   [id_kern] = function(lp) 
		  Np.first = Np.first or lp
		  if lp.subtype==2 then
		     set_attr(lp, attr_icflag, PROCESSED); lp = node_next(lp)
		     set_attr(lp, attr_icflag, PROCESSED); lp = node_next(lp)
		     set_attr(lp, attr_icflag, PROCESSED); lp = node_next(lp)
		     set_attr(lp, attr_icflag, PROCESSED); Np.nuc = lp
		     Np.id = (lp.font == (has_attr(lp, attr_curjfnt) or -1)) and id_jglyph or id_glyph
		     return true, check_next_ickern(node_next(lp)); 
		  else
		     Np.id = id_kern; set_attr(lp, attr_icflag, PROCESSED); -- set_attr_icflag_processed(lp);
		     Np.last = lp; return true, node_next(lp)
		  end
	       end,
   [id_penalty] = function(lp)
		     Bp[#Bp+1] = lp; set_attr(lp, attr_icflag, PROCESSED); -- set_attr_icflag_processed(lp); 
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
   Np, Nq, ihb_flag = Nq, Np, nil
   -- We clear `predefined' entries of Np before pairs() loop,
   -- because using only pairs() loop is slower.
   Np.post, Np.pre, Np.xspc = nil, nil, nil
   Np.first, Np.id, Np.last, Np.met = nil, nil, nil
   Np.auto_kspc, Np.auto_xspc, Np.char, Np.class, Np.nuc = nil, nil, nil, nil, nil
   for k in pairs(Np) do Np[k] = nil end

   for k = 1,#Bp do Bp[k] = nil end
   while lp ~= last do
      local lpa = has_attr(lp, attr_icflag) or 0
       -- unbox 由来ノードの検出
      if lpa>=PACKED then
         if lpa%PROCESSED_BEGIN_FLAG == BOXBDD then
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
  local PRE  = luatexja.stack_table_index.PRE
  local POST = luatexja.stack_table_index.POST
  local KCAT = luatexja.stack_table_index.KCAT
  local XSP  = luatexja.stack_table_index.XSP

-- 和文文字のデータを取得
   local attr_jchar_class = luatexbase.attributes['ltj@charclass']
   local attr_orig_char = luatexbase.attributes['ltj@origchar']
   local attr_autospc = luatexbase.attributes['ltj@autospc']
   local attr_autoxspc = luatexbase.attributes['ltj@autoxspc']
   function set_np_xspc_jachar(Nx, x)
      local m = ltjf_font_metric_table[x.font]
      local cls, c = slow_find_char_class(has_attr(x, attr_orig_char), m, x.char)
      Nx.class = cls; set_attr(x, attr_jchar_class, cls)
      Nx.met, Nx.char = m, c
      Nx.pre  = table_current_stack[PRE + c]  or 0
      Nx.post = table_current_stack[POST + c] or 0
      Nx.xspc = table_current_stack[XSP  + c] or 3
      Nx.kcat = table_current_stack[KCAT + c] or 0
      Nx.auto_kspc, Nx.auto_xspc = (has_attr(x, attr_autospc)==1), (has_attr(x, attr_autoxspc)==1)
   end 
   local set_np_xspc_jachar = set_np_xspc_jachar

-- 欧文文字のデータを取得
   local floor = math.floor
   function set_np_xspc_alchar(Nx, c,x, lig)
      if c~=-1 then
         local xc, xs = x.components, x.subtype
	 if lig == 1 then
	    while xc and xs and xs%4>=2 do
	       x = xc; xc, xs = x.components, x.subtype
	    end
            c = x.char
	 else
	    while xc and xs and xs%4>=2 do
	       x = node.tail(xc); xc, xs = x.components, x.subtype
	    end
            c = x.char
	 end
      Nx.pre  = table_current_stack[PRE + c]  or 0
      Nx.post = table_current_stack[POST + c] or 0
      Nx.xspc = table_current_stack[XSP  + c] or 3
      Nx.char = 'jcharbdd'
      else
	 Nx.pre, Nx.post, Nx.char = 0, 0, -1
         Nx.xspc = table_current_stack[XSP - 1] or 3
      end
      Nx.met = nil
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
	 if s.id==id_glyph then
	    if s.font == (has_attr(s, attr_curjfnt) or -1) then 
	       set_np_xspc_jachar(Nx, s)
	    else
	       set_np_xspc_alchar(Nx, s.char, s, ligature_tail)
	    end
	 else
	    set_np_xspc_alchar(Nx, -1, s)
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

-- change penalties (or create a new penalty, if needed)
local function handle_penalty_normal(post, pre, g)
   local a = (pre or 0) + (post or 0)
   if #Bp == 0 then
      if (a~=0 and not(g and g.id==id_kern)) then
	 local p = node_new(id_penalty); --copy_attr(p, Nq.nuc)
	 if a<-10000 then a = -10000 elseif a>10000 then a = 10000 end
	 p.penalty = a
	 head = insert_before(head, Np.first, p)
	 Bp[1]=p; 
	 set_attr(p, attr_icflag, KINSOKU)
      end
   else for _, v in pairs(Bp) do add_penalty(v,a) end
   end
end

local function handle_penalty_always(post, pre, g)
   local a = (pre or 0) + (post or 0)
   if #Bp == 0 then
      if not (g and g.id==id_glue) then
	 local p = node_new(id_penalty); --copy_attr(p, Nq.nuc)
	 if a<-10000 then a = -10000 elseif a>10000 then a = 10000 end
	 p.penalty = a
	 head = insert_before(head, Np.first, p)
	 Bp[1]=p
         set_attr(p, attr_icflag, KINSOKU)
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
      end
   else for _, v in pairs(Bp) do add_penalty(v,a) end
   end
end

-- 和文文字間の JFM glue を node 化
local function new_jfm_glue(m, bc, ac)
-- bc, ac: char classes
   local z = m.char_type[bc]
   local g, d = z.glue[ac], 0 
   if g then
      g,d = node_copy(g[1]), g[2]; 
      g.spec = node_copy(g.spec); -- node_copy は spec をコピーする
   else
      local k = z.kern[ac]
      if k then
         g = node_new(id_kern); --copy_attr(g, Nn.nuc)
         g.subtype = 1; g.kern, d = k[1], k[2]
         set_attr(g, attr_icflag, FROM_JFM);
      end
   end
   return g, d
end

-- Nq.last (kern w) .... (glue/kern g) Np.first
local function real_insert(g)
   if g then
      head  = insert_before(head, Np.first, g)
      Np.first = g
   end
end


-------------------- 和文文字間空白量の決定

-- get kanjiskip
local get_kanjiskip

local function get_kanjiskip_normal()
   if Np.auto_kspc or Nq.auto_kspc then
      return node_copy(kanji_skip)
   else
      local g = node_copy(zero_glue)
      set_attr(g, attr_icflag, KANJI_SKIP)
      return g
   end
end
local function get_kanjiskip_jfm()
   local g
   if Np.auto_kspc or Nq.auto_kspc then
      g = node_new(id_glue); --copy_attr(g, Nq.nuc)
      local gx = node_new(id_glue_spec);
      gx.stretch_order, gx.shrink_order = 0, 0
      local pm, qm = Np.met, Nq.met
      local bk = qm.kanjiskip or {0, 0, 0}
      if (pm.char_type==qm.char_type) and (qm.var==pm.var) then
         gx.width = bk[1]; gx.stretch = bk[2]; gx.shrink = bk[3]
      else
         local ak = pm.kanjiskip or {0, 0, 0}
         gx.width = round(diffmet_rule(bk[1], ak[1]))
         gx.stretch = round(diffmet_rule(bk[2], ak[2]))
         gx.shrink = -round(diffmet_rule(-bk[3], -ak[3]))
      end
      g.spec = gx
   else
      g =  node_copy(zero_glue)
   end
   set_attr(g, attr_icflag, KANJI_SKIP)
   return g
end

local function calc_ja_ja_aux(gb,ga, db, da)
   local rbb, rab = (1-db)/2, (1-da)/2 -- 「前の文字」由来のグルーの割合
   local rba, raa = (1+db)/2, (1+da)/2 -- 「前の文字」由来のグルーの割合
   if diffmet_rule ~= math.two_pleft and diffmet_rule ~= math.two_pright 
      and diffmet_rule ~= math.two_paverage then
      rbb, rab, rba, raa = 1,0,0,1
   end
   if not gb then 
      if ga then gb = node_new(id_kern); gb.kern = 0 else return nil end
   elseif not ga then 
      ga = node_new(id_kern); ga.kern = 0
   end

   local k = node.type(gb.id) .. node.type(ga.id)
   if k == 'glueglue' then 
      -- 両方とも glue．
      gb.spec.width   = round(diffmet_rule(
                                 rbb*gb.spec.width + rba*ga.spec.width,
                                 rab*gb.spec.width + raa*ga.spec.width ))
      gb.spec.stretch = round(diffmet_rule(
                                 rbb*gb.spec.stretch + rba*ga.spec.stretch,
                                 rab*gb.spec.stretch + raa*ga.spec.stretch ))
      gb.spec.shrink  = -round(diffmet_rule(
                                  -rbb*gb.spec.shrink - rba*ga.spec.shrink,
                                  -rab*gb.spec.shrink - raa*ga.spec.shrink ))
      node.free(ga)
      return gb
   elseif k == 'kernkern' then
      -- 両方とも kern．
      gb.kern   = round(diffmet_rule(
                                 rbb*gb.kern + rba*ga.kern,
                                 rab*gb.kern + raa*ga.kern ))
      node.free(ga)
      return gb
   elseif k == 'kernglue' then 
      -- gb: kern, ga: glue
      ga.spec.width   = round(diffmet_rule(
                                 rbb*gb.kern + rba*ga.spec.width,
                                 rab*gb.kern + raa*ga.spec.width ))
      ga.spec.stretch = round(diffmet_rule(
                                 rba*ga.spec.stretch, raa*ga.spec.stretch ))
      ga.spec.shrink  = -round(diffmet_rule(
                                  -rba*ga.spec.shrink,-raa*ga.spec.shrink ))
      node.free(gb)
      return ga
   else
      -- gb: glue, ga: kern
      gb.spec.width   = round(diffmet_rule(
                                 rba*ga.kern + rbb*gb.spec.width,
                                 raa*ga.kern + rab*gb.spec.width ))
      gb.spec.stretch = round(diffmet_rule(
                                 rbb*gb.spec.stretch, rab*gb.spec.stretch ))
      gb.spec.shrink  = -round(diffmet_rule(
                                  -rbb*gb.spec.shrink,-rab*gb.spec.shrink ))
      node.free(ga)
      return gb
   end
end

local function calc_ja_ja_glue()
   if  ihb_flag then return nil
   else
      local qm, pm = Nq.met, Np.met
      if (qm.char_type==pm.char_type) and (qm.var==pm.var) then
         return new_jfm_glue(qm, Nq.class, Np.class)
      else
         local npn, nqn = Np.nuc, Nq.nuc
         local gb, db = new_jfm_glue(qm, Nq.class,
                               slow_find_char_class(has_attr(npn, attr_orig_char), qm, npn.char))
         local ga, da = new_jfm_glue(pm, 
                               slow_find_char_class(has_attr(nqn, attr_orig_char), pm, nqn.char),
                               Np.class)
         return calc_ja_ja_aux(gb, ga, db, da); 
      end
   end
end

-------------------- 和欧文間空白量の決定

-- get xkanjiskip
local get_xkanjiskip
local function get_xkanjiskip_normal(Nn)
   if (Nq.xspc>=2) and (Np.xspc%2==1) and (Nq.auto_xspc or Np.auto_xspc) then
      return node_copy(xkanji_skip)
   else
      local g = node_copy(zero_glue)
      set_attr(g, attr_icflag, XKANJI_SKIP)
      return g
   end
end
local function get_xkanjiskip_jfm(Nn)
   local g
   if (Nq.xspc>=2) and (Np.xspc%2==1) and (Nq.auto_xspc or Np.auto_xspc) then
      g =  node_new(id_glue); --copy_attr(g, Nn.nuc)
      local gx = node_new(id_glue_spec);
      gx.stretch_order, gx.shrink_order = 0, 0
      local bk = Nn.met.xkanjiskip or {0, 0, 0}
      gx.width = bk[1]; gx.stretch = bk[2]; gx.shrink = bk[3]
      g.spec = gx
   else
      g = node_copy(zero_glue)
   end
   set_attr(g, attr_icflag, XKANJI_SKIP)
   return g
end



-------------------- 隣接した「塊」間の処理

local function get_OA_skip()
   if not ihb_flag then
      local pm = Np.met
      return new_jfm_glue(pm, 
        fast_find_char_class(((Nq.id == id_math and -1) or (type(Nq.char)=='string' and Nq.char or 'jcharbdd')), pm), Np.class)
   else return nil
   end
end
local function get_OB_skip()
   if not ihb_flag then
      local qm = Nq.met
      return new_jfm_glue(qm, Nq.class, 
        fast_find_char_class(((Np.id == id_math and -1) or'jcharbdd'), qm))
   else return nil
   end
end

-- (anything) .. jachar
local function handle_np_jachar(mode)
   local qid = Nq.id
   if qid==id_jglyph or ((qid==id_pbox or qid==id_pbox_w) and Nq.met) then 
      local g = calc_ja_ja_glue() or get_kanjiskip() -- M->K
      handle_penalty_normal(Nq.post, Np.pre, g); real_insert(g)
   elseif Nq.met then  -- qid==id_hlist
      local g = get_OA_skip() or get_kanjiskip() -- O_A->K
      handle_penalty_normal(0, Np.pre, g); real_insert(g)
   elseif Nq.pre then 
     local g = get_OA_skip() or get_xkanjiskip(Np) -- O_A->X
      handle_penalty_normal((qid==id_hlist and 0 or Nq.post), Np.pre, g); real_insert(g)
   else
      local g = get_OA_skip() -- O_A
      if qid==id_glue then handle_penalty_normal(0, Np.pre, g)
      elseif qid==id_kern then handle_penalty_suppress(0, Np.pre, g)
      else handle_penalty_always(0, Np.pre, g)
      end
      real_insert(g)
   end
   if mode and Np.kcat%2~=1 then
      widow_Np.first, widow_Bp, Bp = Np.first, Bp, widow_Bp
   end
end


-- jachar .. (anything)
local function handle_nq_jachar()
    if Np.pre then 
      local g = get_OB_skip() or get_xkanjiskip(Nq) -- O_B->X
      handle_penalty_normal(Nq.post, (Np.id==id_hlist and 0 or Np.pre), g); real_insert(g)
   else
      local g = get_OB_skip() -- O_B
      if Np.id==id_glue then handle_penalty_normal(Nq.post, 0, g)
      elseif Np.id==id_kern then handle_penalty_suppress(Nq.post, 0, g)
      else handle_penalty_always(Nq.post, 0, g)
      end
      real_insert(g)
   end
end

-- (anything) .. (和文文字で始まる hlist)
local function handle_np_ja_hlist()
   local qid = Nq.id
   if qid==id_jglyph or ((qid==id_pbox or Nq.id == id_pbox_w) and Nq.met) then 
      local g = get_OB_skip() or get_kanjiskip() -- O_B->K
      handle_penalty_normal(Nq.post, 0, g); real_insert(g)
   elseif Nq.met then  -- Nq.id==id_hlist
      local g = get_kanjiskip() -- K
      handle_penalty_suppress(0, 0, g); real_insert(g)
   elseif Nq.pre then 
      local g = get_xkanjiskip(Np) -- X
      handle_penalty_suppress(0, 0, g); real_insert(g)
   end
end

-- (和文文字で終わる hlist) .. (anything)
local function handle_nq_ja_hlist()
   if Np.pre then 
      local g = get_xkanjiskip(Nq) -- X
      handle_penalty_suppress(0, 0, g); real_insert(g)
   end
end


-- Nq が前側のクラスタとなることによる修正
do
   local adjust_nq_aux = {
      [id_glyph] = function() 
		      local x = Nq.nuc
		      return set_np_xspc_alchar(Nq, x.char,x, 2)
		   end, -- after_alchar(Nq)
      [id_hlist]  = function() after_hlist(Nq) end,
      [id_pbox]  = function() after_hlist(Nq) end,
      [id_disc]  = function() after_hlist(Nq) end,
      [id_pbox_w]  = function() 
			luatexbase.call_callback("luatexja.jfmglue.whatsit_after",
						 false, Nq, Np) 
		     end,
   }

   function adjust_nq()
      local x = adjust_nq_aux[Nq.id]
      if x then x()  end
   end
end


-------------------- 開始・終了時の処理

-- リスト末尾の処理
local JWP  = luatexja.stack_table_index.JWP
local function handle_list_tail(mode)
   adjust_nq(); Np = Nq
   if mode then
      -- the current list is to be line-breaked.
      -- Insert \jcharwidowpenalty
      Bp = widow_Bp; Np = widow_Np
      if Np.first then
	 handle_penalty_normal(0,
			       table_current_stack[JWP] or 0)
      end
   else
      -- the current list is the contents of a hbox
      local npi, pm = Np.id, Np.met
      if npi == id_jglyph or (npi==id_pbox and pm) then 
	 local g = new_jfm_glue(pm, Np.class, fast_find_char_class('boxbdd', pm))
	 if g then
	    set_attr(g, attr_icflag, BOXBDD)
	    head = node.insert_after(head, Np.last, g)
	 end
      end
   end
end

-- リスト先頭の処理
local function handle_list_head(par_indented)
   local npi, pm = Np.id, Np.met
   if npi ==  id_jglyph or (npi==id_pbox and pm) then 
      if not ihb_flag then
	 local g = new_jfm_glue(pm, fast_find_char_class(par_indented, pm), Np.class)
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
   -- 1073741823: max_dimen
   Bp, widow_Bp, widow_Np = {}, {}, {first = nil}
   table_current_stack = ltjs.table_current_stack

   kanji_skip = node_new(id_glue)
   kanji_skip.spec = skip_table_to_spec('kanjiskip')
   set_attr(kanji_skip, attr_icflag, KANJI_SKIP)
   get_kanjiskip = (kanji_skip.spec.width == 1073741823)
      and get_kanjiskip_jfm or get_kanjiskip_normal

   xkanji_skip = node_new(id_glue)
   xkanji_skip.spec = skip_table_to_spec('xkanjiskip')
   set_attr(xkanji_skip, attr_icflag, XKANJI_SKIP)
   get_xkanjiskip = (xkanji_skip.spec.width == 1073741823) 
      and get_xkanjiskip_jfm or get_xkanjiskip_normal

   Np = {
      auto_kspc=nil, auto_xspc=nil, char=nil, class=nil, 
      first=nil, id=nil, last=nil, met=nil, nuc=nil, 
      post=nil, pre=nil, xspc=nil, 
   }
   Nq = {
      auto_kspc=nil, auto_xspc=nil, char=nil, class=nil, 
      first=nil, id=nil, last=nil, met=nil, nuc=nil, 
      post=nil, pre=nil, xspc=nil, 
   }
   if mode then 
      -- the current list is to be line-breaked:
      -- hbox from \parindent is skipped.
      local lp, par_indented, lpi, lps  = head, 'boxbdd', head.id, head.subtype
      while lp and ((lpi==id_whatsit and lps~=sid_user) 
		 or ((lpi==id_hlist) and (lps==3))) do
	 if (lpi==id_hlist) and (lps==3) then par_indented = 'parbdd' end
	 lp=node_next(lp); lpi, lps = lp.id, lp.subtype end
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
      extract_np();
      adjust_nq(); 
      local pid, pm = Np.id, Np.met
      -- 挿入部
      if pid == id_jglyph then 
         handle_np_jachar(mode)
      elseif pm then 
         if pid==id_hlist then handle_np_ja_hlist()
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

do
   local IHB  = luatexja.userid_table.IHB
   local BPAR = luatexja.userid_table.BPAR

   -- \inhibitglue
   function create_inhibitglue_node()
      local tn = node_new(id_whatsit, sid_user)
      tn.user_id=IHB; tn.type=100; tn.value=1
      node.write(tn)
   end

   -- Node for indicating beginning of a paragraph
   -- (for ltjsclasses)
   function create_beginpar_node()
      local tn = node_new(id_whatsit, sid_user)
      tn.user_id=BPAR; tn.type=100; tn.value=1
      node.write(tn)
   end

   local function whatsit_callback(Np, lp, Nq)
      if Np and Np.nuc then return Np 
      elseif Np and lp.user_id == BPAR then
         Np.first = lp; Np.nuc = lp; Np.last = lp
         Np.char = 'parbdd'
         Np.met = nil
         Np.pre = 0; Np.post = 0
         Np.xspc = 0
         Np.auto_xspc = false
         return Np
      end
   end

   local function whatsit_after_callback(s, Nq, Np)
      if not s and Nq.nuc.user_id == BPAR then
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
