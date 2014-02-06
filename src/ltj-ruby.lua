--
-- ltj-ruby.lua
--
luatexbase.provides_module({
  name = 'luatexja.ruby',
  date = '2012/04/21',
  version = '0.1',
  description = 'Ruby',
})
module('luatexja.ruby', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

local id_hlist = node.id('hlist')
local id_vlist = node.id('vlist')
local id_rule = node.id('rule')
local id_whatsit = node.id('whatsit')
local id_glue = node.id('glue')
local id_kern = node.id('kern')
local id_glue_spec = node.id('glue_spec')
local sid_user = node.subtype('user_defined')
local ltjs_get_penalty_table = luatexja.stack.get_penalty_table
local id_pbox_w = node.id('hlist') + 513      -- cluster which consists of a whatsit

local attr_icflag = luatexbase.attributes['ltj@icflag']
-- ルビ処理用の attribute は他のやつの流用なので注意！
-- 進入許容量 (sp)
local attr_ruby_maxprep = luatexbase.attributes['ltj@charclass']
local attr_ruby_maxpostp = luatexbase.attributes['ltj@kcat0']
local attr_ruby_maxmargin = luatexbase.attributes['ltj@kcat1']

local attr_ruby_stretch = luatexbase.attributes['ltj@kcat2']
local attr_ruby_mode = luatexbase.attributes['ltj@kcat3']
local attr_ruby = luatexbase.attributes['ltj@rubyattr']
-- ルビ内部処理用
-- jfmglue 中では「2つ前のクラスタもルビ」のフラグ（true = 1）
-- (whatsit).value node ではルビ全角の値（sp単位）
-- 行分割前後では，「何番目のルビ関連ノード」か

local round = tex.round
local floor = math.floor
local min = math.min
local max = math.max
--local node_type = node.type
local node_new = node.new
local node_remove = node.remove
-- local node_prev = node.prev
local node_next = node.next
local node_copy = node.copy
local node_tail = node.tail
local node_free = node.free
local has_attr = node.has_attribute
local set_attr = node.set_attribute
local node_insert_before = node.insert_before
local node_insert_after = node.insert_after

local FROM_JFM = 4
local KANJI_SKIP = 6
local XKANJI_SKIP = 7
local PROCESSED = 8

local uid_ruby_pre = 30120
local uid_ruby_post = 30121

local box_stack_level

----------------------------------------------------------------
-- 補助関数群 1
----------------------------------------------------------------

local function gauss(coef)
   -- #coef 式，#coef 変数の連立1次方程式系を掃きだし法で解く．
   local deg = #coef
   for i = 1, deg do
      if coef[i][i]==0 then
	 for j = i+1, deg do 
	    if coef[j][i]~=0 then 
	       local tmp = coef[i]; coef[i] = coef[j]; coef[j] = tmp
	       break
	    end
	 end
      end
      for j = 1,deg do 
	 local d = coef[i][i];
	 if j~=i then
	    local e = coef[j][i]
	    for k = 1, deg+1 do coef[j][k] = coef[j][k] - e*coef[i][k]/d end
	 else
	    for k = 1, deg+1 do coef[i][k] = coef[i][k]/d end
	 end
      end
   end
end

-- 実行回数 + ルビ中身 から uniq_id を作る関数
-- 未実装．これを使えば 2 回目以降の組版に 1 回目の情報が使える


-- concatenation of boxes: reusing nodes
-- ルビ組版が行われている段落/hboxでの設定が使われる．
-- ルビ文字を格納しているボックスでの設定ではない！
local function concat(f, b)
   local r
   if f then
      if b then
         local h = f.head
         node_tail(h).next = b.head
	 f.head = nil; b.head = nil
	 node_free(f); node_free(b)
	 r = node.hpack(luatexja.jfmglue.main(h,false))
      else 
	 r = f
      end
   elseif b then
      r = b
   else
      local h = node_new(id_hlist)
      h.subtype = 0; h.width = 0; h.height = 0; h.depth = 0;
      h.head = nil; h.glue_set = 0; h.glue_order = 0
      r = h
   end
   return r
end

local function expand_3bits(num)
   local t = {}; local a = num
   for i = 1, 10 do
      table.insert(t,a%8); a = floor(a/8)
   end
   return t
end
----------------------------------------------------------------
-- 補助関数群 2
----------------------------------------------------------------

-- box の中身のノードは再利用される
local function enlarge(box, new_width, pre, middle, post, prenw, postnw)
   -- pre, middle, post: 伸縮比率
   -- prenw, postnw: 前後の自然長 (sp)
   local h = box.head; local hh = box.height; local hd = box.depth
   local hx = h
   while hx do
      if has_attr(hx, attr_icflag) == KANJI_SKIP
         or has_attr(hx, attr_icflag) == XKANJI_SKIP
         or has_attr(hx, attr_icflag) == FROM_JFM then
	 -- この 3 種類の空白をのばす
         if hx.id == id_kern then
            local k = node_new(id_glue);
            local ks = node_new(id_glue_spec);
            ks.width = hx.kern; 
            ks.stretch_order = 2; ks.stretch = round(middle*65536);
            ks.shrink_order = 0; ks.shrink = 0; 
            k.subtype = 0; k.spec = ks
            h = node_insert_after(h, hx, k);
            h = node_remove(h, hx); node_free(hx); hx = k;
         else -- glue
            hx.spec = node_copy(hx.spec);
            hx.spec.stretch_order=2; hx.spec.stretch = round(middle*65536);
            hx.spec.shrink_order=0; hx.spec.shrink = 0;
         end
      end
      hx = node_next(hx)
   end
   -- 先頭と末尾の空白を挿入
   local k = node_new(id_glue);
   local ks = node_new(id_glue_spec);
   ks.width = prenw; ks.stretch_order = 2; ks.stretch = round(pre*65536);
   ks.shrink_order = 0; ks.shrink = 0;
   k.subtype = 0; k.spec = ks; h = node_insert_before(h, h, k);
   local k = node_new(id_glue);
   local ks = node_new(id_glue_spec);
   ks.width = postnw; ks.stretch_order = 2; ks.stretch = round(post*65536);
   ks.shrink_order = 0; ks.shrink = 0;
   k.subtype = 0; k.spec = ks; node_insert_after(h, node_tail(h), k);
   -- hpack
   box.head = nil; node_free(box);
   box = node.hpack(h, new_width, 'exactly')
   box.height = hh; box.depth = hd; return box
end

----------------------------------------------------------------
-- TeX interface
----------------------------------------------------------------

local function texiface_low(rst, rtlr, rtlp)
   local w = node_new(id_whatsit, sid_user)
   w.type = 110; w.user_id = uid_ruby_pre;
   w.value = node_new(id_whatsit, sid_user)
   w.value.type = 100; w.value.value = floor(#rtlr)
   set_attr(w.value, attr_ruby, rst.rubyzw)
   set_attr(w.value, attr_ruby_maxmargin, rst.maxmargin)
   set_attr(w.value, attr_ruby_maxprep, rst.intrusionpre)
   set_attr(w.value, attr_ruby_maxpostp, rst.intrusionpost)
   set_attr(w.value, attr_ruby_stretch, rst.stretch)
   set_attr(w.value, attr_ruby_mode, rst.mode)
   local m = w.value
   for i = 1, #rtlr do
      local n = rtlr[i]; m.next = n; m = rtlp[i]; n.next = m
   end
   -- w.value: (whatsit) .. r1 .. p1 .. r2 .. p2
   node.write(w)
end

-- rst: table
function texiface(rst, rtlr, rtlp)
   if #rtlr ~= #rtlp then
      for i,v in pairs(rtlr) do node_free(v) end
      for i,v in pairs(rtlp) do node_free(v) end
      luatexja.base.package_error('luatexja-ruby',
				  'Group count mismatch between the ruby and\n' ..
				     'the body (' .. #rtlr .. ' != ' .. #rtlp .. ').',
				  '')
   else
      local f = true
      for i = 1,#rtlr do
	 if rtlr[i].width > rtlp[i].width then f = false; break end
      end
      if f then -- モノルビ * n
	 local r,p = {true}, {true}
	 for i = 1,#rtlr do
	    r[1] = rtlr[i]; p[1] = rtlp[i]; texiface_low(rst, r, p)
	 end
      else
	 texiface_low(rst, rtlr, rtlp)
      end
   end
end


----------------------------------------------------------------
-- pre_line_break
----------------------------------------------------------------

-- r, p の中身のノードは再利用される
local function enlarge_parent(r, p, ppre, pmid, ppost, mapre, mapost, intmode)
   local sumprot = r.width  - p.width -- >0
   local pre_intrusion, post_intrusion
   if intmode == 0 then --  とりあえず組んでから決める
      p = enlarge(p, r.width, ppre, pmid, ppost, 0, 0) 
      pre_intrusion = min(mapre, round(ppre*p.glue_set*65536))
      post_intrusion = min(mapost, round(ppost*p.glue_set*65536))
   elseif intmode == 1 then
      pre_intrusion = min(mapre, sumprot); 
      post_intrusion = min(mapost, max(sumprot-pre_intrusion, 0))
      p = enlarge(p, r.width, ppre, pmid, ppost, pre_intrusion, post_intrusion)
   elseif intmode == 2 then
      post_intrusion = min(mapost, sumprot); 
      pre_intrusion = min(mapre, max(sumprot-post_intrusion, 0))
      p = enlarge(p, r.width, ppre, pmid, ppost, pre_intrusion, post_intrusion) 
   else --  intmode == 3
      local n = min(mapre, mapost)*2
      if n < sumprot then
	 pre_intrusion = n/2; post_intrusion = n/2
      else
	 pre_intrusion = floor(sumprot/2); post_intrusion = sumprot - pre_intrusion
      end
      p = enlarge(p, r.width, ppre, pmid, ppost, pre_intrusion, post_intrusion) 
      pre_intrusion = min(mapre, pre_intrusion + round(ppre*p.glue_set*65536))
      post_intrusion = min(mapost, post_intrusion + round(ppost*p.glue_set*65536))
   end
      r.shift = -pre_intrusion
      r.width = r.width - pre_intrusion - post_intrusion
      p.width = r.width
      p.head.spec.width = p.head.spec.width - pre_intrusion
   return r, p, post_intrusion
end

-- ルビボックスの生成（単一グループ）
-- returned value: <new box>, <ruby width>, <post_intrusion>
local max_margin
local function new_ruby_box(r, p, ppre, pmid, ppost, 
			    rpre, rmid, rpost, mapre, mapost, intmode)
   local post_intrusion = 0
   if r.width > p.width then  -- change the width of p
      r, p, post_intrusion  = enlarge_parent(r, p, ppre, pmid, ppost, mapre, mapost, intmode) 
   elseif r.width < p.width then -- change the width of r
      r = enlarge(r, p.width, rpre, rmid, rpost, 0, 0) 
      post_intrusion = 0
      local need_repack = false
      -- margin が大きくなりすぎた時の処理
      if round(rpre*r.glue_set*65536) > max_margin then
	 local sp = r.head.spec; need_repack = true
	 sp.width = max_margin; sp.stretch = 1 -- 全く伸縮しないのも困る
      end
      if round(rpost*r.glue_set*65536) > max_margin then
	 local sp = node_tail(r.head).spec; need_repack = true
	 sp.width = max_margin; sp.stretch = 1 -- 全く伸縮しないのも困る
      end
      if need_repack then
	 local rt = r
	 r = node.hpack(r.head, r.width, 'exactly')
	 rt.head = nil; node_free(rt);
      end
   end
   local a = node_new(id_rule); a.width = 0; a.height = 0; a.depth = 0
   node_insert_after(r, r, a); node_insert_after(r, a, p); p.next = nil
   a = node.vpack(r); a.height = p.height; a.depth = p.depth;
   a.shift = -(r.height+r.depth)
   return a, r.width, post_intrusion
end


-- High-level routine in pre_linebreak_filter
local max_post_intrusion_backup
local max_allow_pre, max_allow_post


-- 中付き熟語ルビ，cmp containers
-- 「文字の構成を考えた」やつはどうしよう
local function pre_low_cal_box(w, cmp)
   local rb = {}
   local pb = {}
   local kf = {}
   -- kf[i] : container 1--i からなる行末形
   -- kf[cmp+i] : container i--cmp からなる行頭形
   -- kf[2cmp+1] : 行中形
   local nt, nta, ntb, mdt -- nt*: node temp
   local coef = {} -- 連立一次方程式の拡大係数行列
   local rtb = expand_3bits(has_attr(w.value, attr_ruby_stretch))
   local rtc = expand_3bits(has_attr(w.value, attr_ruby_mode))
   local intmode = floor(has_attr(w.value, attr_ruby_mode)/4)%4

   -- node list 展開・行末形の計算
   nta = nil; ntb = nil; nt = w.value
   for i = 1, cmp do
      nt = nt.next; rb[i] = nt; nta = concat(nta, node_copy(nt))
      nt = nt.next; pb[i] = nt; ntb = concat(ntb, node_copy(nt))
      coef[i] = {}
      for j = 1, 2*i do coef[i][j] = 1 end
      for j = 2*i+1, 2*cmp+1 do coef[i][j] = 0 end
      kf[i], coef[i][2*cmp+2]
	 = new_ruby_box(node_copy(nta), node_copy(ntb), 
			rtb[6], rtb[5], rtb[4], rtc[10], rtc[9], rtc[8], 
			max_allow_pre, 0, intmode)
   end
   node.free(nta); node.free(ntb)

   -- 行頭形の計算
   nta = nil; ntb = nil
   for i = cmp,1,-1 do
      coef[cmp+i] = {}
      for j = 1, 2*i-1 do coef[cmp+i][j] = 0 end
      for j = 2*i, 2*cmp+1 do coef[cmp+i][j] = 1 end
      nta = concat(node_copy(rb[i]), nta); ntb = concat(node_copy(pb[i]), ntb)
      kf[cmp+i], coef[cmp+i][2*cmp+2], mdt
	 = new_ruby_box(node_copy(nta), node_copy(ntb), 
			rtb[9], rtb[8], rtb[7], rtc[10], rtc[9], rtc[8], 
			0, max_allow_post, intmode)
      if max_post_intrusion_backup < mdt then max_post_intrusion_backup = mdt end
   end

   -- ここで，nta, ntb には全 container を連結した box が入っているので
   -- それを使って行中形を計算する．
   coef[2*cmp+1] = {}
   for j = 1, 2*cmp+1 do coef[2*cmp+1][j] = 1 end
   kf[2*cmp+1], coef[2*cmp+1][2*cmp+2], mdt
      = new_ruby_box(nta, ntb,
		     rtb[3], rtb[2], rtb[1], rtc[10], rtc[9], rtc[8], 
		     max_allow_pre, max_allow_post, intmode)
   if max_post_intrusion_backup < mdt then max_post_intrusion_backup = mdt end

   -- w.value の node list 更新．
   nt = w.value
   node.flush_list(nt.next)
   for i = 1, 2*cmp+1 do nt.next = kf[i]; nt = kf[i]  end

   gauss(coef) -- 掃きだし法で連立方程式形 coef を解く
   return coef
end

-- ノード追加
local function pre_low_app_node(head, w, cmp, coef, ht, dp)
   local nt, nta, ntb
   -- メインの node list 更新
   nt = node_new(id_glue); ntb = node_new(id_glue_spec);
   ntb.width = coef[1][2*cmp+2]; ntb.stretch_order = 0; ntb.stretch = 0;
   ntb.shrink_order = 0; ntb.shrink = 0; nt.subtype = 0; nt.spec = ntb; 
   head = node_insert_before(head, w, nt)
   set_attr(nt, attr_ruby, 1)
   set_attr(w, attr_ruby, 2); nt = w
   for i = 1, cmp do
      -- rule
      nta = node_new(id_rule); nta.width = coef[i*2][2*cmp+2]; 
      nta.height = ht; nta.depth =dp; nta.subtype = 0
      node_insert_after(head, nt, nta); set_attr(nta, attr_ruby, 2*i+1)
      -- glue
      nt = node_new(id_glue); ntb = node_new(id_glue_spec);
      ntb.width = coef[i*2+1][2*cmp+2]; ntb.stretch_order = 0; ntb.stretch = 0;
      ntb.shrink_order = 0; ntb.shrink = 0; nt.subtype = 0; nt.spec = ntb; 
      head = node_insert_after(head, nta, nt); set_attr(nt, attr_ruby, 2*i+2)
   end
   tex.setattribute(attr_ruby, -0x7FFFFFFF);
   w.user_id = uid_ruby_post;
   return head, node_next(nt)
end

local function pre_high(head)
   local n = head; max_post_intrusion_backup = 0
   if not n then return head end
   while n do
      if n.id == id_whatsit then
         if n.subtype == sid_user and n.user_id == uid_ruby_pre then
            max_allow_pre = has_attr(n.value, attr_ruby_maxprep) or 0
	    if has_attr(n, attr_ruby) == 1 then 
	       -- 直前のルビで intrusion がおこる可能性あり．安全策をとる．
	       max_allow_pre = max(0, max_allow_pre - max_post_intrusion_backup)
	    end
	    max_post_intrusion_backup = 0
            max_allow_post = has_attr(n.value, attr_ruby_maxpostp) or 0
            max_margin = has_attr(n.value, attr_ruby_maxmargin) or 0
	    local coef = pre_low_cal_box(n, n.value.value)
	    local s = node_tail(n.value) --ルビ文字
	    head, n = pre_low_app_node(
	       head, n, n.value.value, coef, s.height, s.depth
	    )
         else 
            n = n.next
         end
      else
         n = n.next
      end
   end
   return head
end 
luatexbase.add_to_callback('pre_linebreak_filter', pre_high, 'ltj.ruby.pre', 100)
luatexbase.add_to_callback('hpack_filter', pre_high, 'ltj.ruby.pre', 100)

----------------------------------------------------------------
-- post_line_break
----------------------------------------------------------------

local function post_lown(rs, rw, ch)
-- ch: the head of `current' hlist
   if #rs ==0 or not rw then return ch end
   local hn = has_attr(rs[1],attr_ruby)
   local fn = has_attr(rs[#rs],attr_ruby)
   local cmp = rw.value.value
   if hn==1 then 
      if fn==2*cmp+2 then
	 hn = node_tail(rw.value); node_remove(rw.value, hn)
	 node_insert_after(ch, rs[#rs], hn)
         set_attr(hn, attr_icflag,  PROCESSED)
      else
	 local deg = (fn-1)/2
         hn = rw.value; for i = 1, deg do hn = hn.next end; 
	 node_remove(rw.value, hn); hn.next = nil;
         node_insert_after(ch, rs[#rs], hn)
         set_attr(hn, attr_icflag,  PROCESSED)
     end
   else
      local deg = (hn-1)/2; 
      if deg == 1 then deg = 2 end
      hn = rw.value; for i = 1, cmp+deg-1 do hn = hn.next end
      -- -1 is needed except the case hn = 3, 
      --   because a ending-line form is removed already from the list
      node_remove(rw.value, hn); hn.next = nil
      node_insert_after(ch, rs[#rs], hn)
      set_attr(hn, attr_icflag,  PROCESSED)
   end
   for i, v in ipairs(rs) do ch = node_remove(ch, v); node_free(v) end
   if fn >= 2*cmp+1 then
      rw.next = nil; node_free(rw); 
   end
   return ch;
end


local function post_high_break(head)
   local h = head; 
   local rs = {};  -- rs: sequence of ruby_nodes, 
   local rw = nil; -- rw: main whatsit
   while h do 
      if h.id == id_hlist then
         local ha = h.head; rs = {}
         while ha do
            local i = (((ha.id == id_glue and ha.subtype==0) 
                 or (ha.id == id_rule and ha.subtype==0)
                 or (ha.id == id_whatsit and ha.subtype==sid_user 
		     and ha.user_id==uid_ruby_post))
		    and has_attr(ha, attr_ruby)) or 0
            if i==1 then 
               h.head = post_lown(rs, rw, h.head); rs = {}; rw = nil
               table.insert(rs, ha); ha = node_next(ha)
            elseif i>=3 then 
               table.insert(rs, ha); ha = node_next(ha)
            elseif i==2 then 
               rw = ha; h.head, ha = node_remove(h.head, rw); 
            else
               ha = node_next(ha)
            end
         end
         h.head = post_lown(rs, rw, h.head);
      end
      h = node_next(h)
   end
   return head
end 

local function post_high_hbox(head)
   local ha = head; 
   local rs = {};  -- rs: sequence of ruby_nodes, 
   local rw = nil; -- rw: main whatsit
   while ha do
      local i = (((ha.id == id_glue and ha.subtype==0) 
               or (ha.id == id_rule and ha.subtype==0)
               or (ha.id == id_whatsit and ha.subtype==sid_user 
                    and ha.user_id==uid_ruby_post))
               and has_attr(ha, attr_ruby)) or 0
      if i==1 then 
         head = post_lown(rs, rw, head); rs = {}; rw = nil
         table.insert(rs, ha); ha = node_next(ha)
      elseif i>=3 then 
         table.insert(rs, ha); ha = node_next(ha)
      elseif i==2 then 
         rw = ha; head, ha = node_remove(head, rw); 
      else
         ha = node_next(ha)
      end
   end
   return post_lown(rs, rw, head);
end

luatexbase.add_to_callback('post_linebreak_filter', post_high_break, 'ltj.ruby.post_break', 100)
luatexbase.add_to_callback('hpack_filter', post_high_hbox, 'ltj.ruby.post_hbox', 101)


----------------------------------------------------------------
-- for jfmglue callbacks
----------------------------------------------------------------
function whatsit_callback(Np, lp, Nq, bsl) 
   if Np.nuc then return Np 
   elseif lp.user_id == uid_ruby_pre then
      Np.first = lp; Np.nuc = lp; Np.last = lp
      local x = lp.value.next.next
      Np.last_char = luatexja.jfmglue.check_box_high(Np, x.head, nil)
      if Nq.id ~=id_pbox_w and  Nq.char then
	 if has_attr(lp.value, attr_ruby_maxprep) < 0 then -- auto
	    local p = round(ltjs_get_penalty_table('ripre', Nq.char, 0, bsl)
			 *has_attr(lp.value, attr_ruby))
	    if has_attr(lp.value, attr_ruby_mode)%2 == 0 then -- intrusion 無効
	       p = 0
	    end
	    set_attr(lp.value, attr_ruby_maxprep, p)
	 end
	 if Nq.prev_ruby then 
	    set_attr(lp, attr_ruby, 1)
	 end
      else
	 set_attr(lp.value, attr_ruby_maxprep, 0)
      end
      return Np
   end
end
function whatsit_after_callback(s, Nq, Np, bsl)
   if not s and Nq.nuc.user_id == uid_ruby_pre then
      local x = Nq.nuc.value.next.next
      for i = 2, Nq.nuc.value.value do x = x.next.next end
      Nq.last_char = luatexja.jfmglue.check_box_high(Nq, x.head, nil)
      luatexja.jfmglue.after_hlist(Nq)
      s = true
      if Np and Np.id ~=id_pbox_w and  Np.char then
         if has_attr(Nq.nuc.value, attr_ruby_maxpostp) < 0 then -- auto
            local p = floor(ltjs_get_penalty_table('ripost', Np.char, 0, bsl)
                         *has_attr(Nq.nuc.value, attr_ruby))
            if has_attr(Nq.nuc.value, attr_ruby_mode)%2 == 0 then -- intrusion 無効
               p = 0
            end
            if has_attr(Nq.nuc.value, attr_ruby_mode)%4 >= 2 then
               local q = has_attr(Nq.nuc.value, attr_ruby_maxprep)
               if q < p then p = q
               elseif q > p then
                  set_attr(Nq.nuc.value, attr_ruby_maxprep, p)
               end
            end
            set_attr(Nq.nuc.value, attr_ruby_maxpostp, p)
         end
         Np.prev_ruby = true -- 前のクラスタがルビであったことのフラグ
      else -- 直前が文字以外なら intrusion なし
         set_attr(Nq.nuc.value, attr_ruby_maxpostp, 0)
         if has_attr(Nq.nuc.value, attr_ruby_mode)%4 >= 2 then
            set_attr(Nq.nuc.value, attr_ruby_maxprep, 0)
         end
         if Np and Np.id == id_pbox_w then
            set_attr(Np.nuc.value, attr_ruby_maxprep, 0)
         end
      end
   end
   return s
end

luatexbase.add_to_callback("luatexja.jfmglue.whatsit_getinfo", whatsit_callback,
                           "luatexja.ruby.np_info", 1)
luatexbase.add_to_callback("luatexja.jfmglue.whatsit_after", whatsit_after_callback,
                           "luatexja.ruby.np_info_after", 1)

