--
-- ltj-ruby.lua
--
luatexbase.provides_module({
  name = 'luatexja.ruby',
  date = '2014/02/06',
  description = 'Ruby',
})
module('luatexja.ruby', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

luatexja.load_module('stack');     local ltjs = luatexja.stack

local Dnode = node.direct or node

local nullfunc = function(n) return n end
local to_node = (Dnode ~= node) and Dnode.tonode or nullfunc
local to_direct = (Dnode ~= node) and Dnode.todirect or nullfunc

local setfield = (Dnode ~= node) and Dnode.setfield or function(n, i, c) n[i] = c end
local getfield = (Dnode ~= node) and Dnode.getfield or function(n, i) return n[i] end
local getid = (Dnode ~= node) and Dnode.getid or function(n) return n.id end
local getfont = (Dnode ~= node) and Dnode.getfont or function(n) return n.font end
local getlist = (Dnode ~= node) and Dnode.getlist or function(n) return n.head end
local getchar = (Dnode ~= node) and Dnode.getchar or function(n) return n.char end
local getsubtype = (Dnode ~= node) and Dnode.getsubtype or function(n) return n.subtype end

local node_new = Dnode.new
local node_remove = luatexja.Dnode_remove -- Dnode.remove
local node_next = (Dnode ~= node) and Dnode.getnext or node.next
local node_copy, node_free, node_tail = Dnode.copy, Dnode.free, Dnode.tail
local has_attr, set_attr = Dnode.has_attribute, Dnode.set_attribute
local insert_before, insert_after = Dnode.insert_before, Dnode.insert_after

local id_hlist = node.id('hlist')
local id_vlist = node.id('vlist')
local id_rule = node.id('rule')
local id_whatsit = node.id('whatsit')
local id_glue = node.id('glue')
local id_kern = node.id('kern')
local id_glue_spec = node.id('glue_spec')
local sid_user = node.subtype('user_defined')
local ltjs_get_stack_table = luatexja.stack.get_stack_table
local id_pbox_w = 258 -- cluster which consists of a whatsit

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

local round, floor = tex.round, math.floor
local min, max = math.min, math.max

local FROM_JFM       = luatexja.icflag_table.FROM_JFM
local PROCESSED      = luatexja.icflag_table.PROCESSED
local KANJI_SKIP     = luatexja.icflag_table.KANJI_SKIP
local KANJI_SKIP_JFM = luatexja.icflag_table.KANJI_SKIP_JFM
local XKANJI_SKIP    = luatexja.icflag_table.XKANJI_SKIP
local XKANJI_SKIP_JFM= luatexja.icflag_table.XKANJI_SKIP_JFM

luatexja.userid_table.RUBY_PRE = luatexbase.newuserwhatsitid('ruby_pre',  'luatexja')
luatexja.userid_table.RUBY_POST = luatexbase.newuserwhatsitid('ruby_post',  'luatexja')
local RUBY_PRE  = luatexja.userid_table.RUBY_PRE
local RUBY_POST = luatexja.userid_table.RUBY_POST

----------------------------------------------------------------
-- TeX interface 0
----------------------------------------------------------------
if Dnode ~= node then
   function cpbox() return node_copy(Dnode.getbox(0)) end
else
   function cpbox() return node.copy(tex.box[0]) end
end


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
               coef[i], coef[j] = coef[j], coef[i]; break
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
   if f then
      if b then
         local h = getlist(f)
         setfield(node_tail(h), 'next', getlist(b))
	 setfield(f, 'head', nil); node_free(f)
         setfield(b, 'head', nil); node_free(b)
	 return Dnode.hpack(luatexja.jfmglue.main(h,false))
      else 
	 return f
      end
   elseif b then
      return b
   else
      local h = node_new(id_hlist)
      setfield(h, 'subtype', 0)
      setfield(h, 'width', 0)
      setfield(h, 'height', 0)
      setfield(h, 'depth', 0)
      setfield(h, 'glue_set', 0)
      setfield(h, 'glue_order', 0)
      setfield(h, 'head', nil)
      return h
   end
end

local function expand_3bits(num)
   local t = {}; local a = num
   for i = 1, 10 do
      t[i] = a%8; a = floor(a/8)
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
   local h = getlist(box); local hh, hd = getfield(box, 'height'), getfield(box, 'depth')
   local hx = h
   while hx do
      if has_attr(hx, attr_icflag) == KANJI_SKIP
         or has_attr(hx, attr_icflag) == KANJI_SKIP_JFM
         or has_attr(hx, attr_icflag) == XKANJI_SKIP
         or has_attr(hx, attr_icflag) == XKANJI_SKIP_JFM
         or has_attr(hx, attr_icflag) == FROM_JFM then
	 -- この 5 種類の空白をのばす
            if getid(hx) == id_kern then
               local k = node_new(id_glue)
               local ks = node_new(id_glue_spec)
               setfield(ks, 'width', getfield(hx, 'kern'))
               setfield(ks, 'stretch_order', 2)
               setfield(ks, 'stretch', round(middle*65536))
               setfield(ks, 'shrink_order', 0)
               setfield(ks, 'shrink', 0)
               setfield(k, 'subtype', 0)
               setfield(k, 'spec', ks)
               h = insert_after(h, hx, k);
               h = node_remove(h, hx); node_free(hx); hx = k
         else -- glue
            local ks = node_copy(getfield(hx, 'spec'))
            setfield(ks, 'stretch_order', 2)
            setfield(ks, 'stretch', round(middle*65536))
            setfield(ks, 'shrink_order', 0)
            setfield(ks, 'shrink', 0)
            setfield(hx, 'spec', ks)
         end
      end
      hx = node_next(hx)
   end
   -- 先頭の空白を挿入
   local k = node_new(id_glue);
   local ks = node_new(id_glue_spec)
   setfield(ks, 'width', prenw)
   setfield(ks, 'stretch_order', 2)
   setfield(ks, 'stretch', round(pre*65536))
   setfield(ks, 'shrink_order', 0)
   setfield(ks, 'shrink', 0)
   setfield(k, 'subtype', 0)
   setfield(k, 'spec', ks)
   h = insert_before(h, h, k);
   -- 末尾の空白を挿入
   local k = node_new(id_glue);
   local ks = node_new(id_glue_spec);
   setfield(ks, 'width', postnw)
   setfield(ks, 'stretch_order', 2)
   setfield(ks, 'stretch', round(post*65536))
   setfield(ks, 'shrink_order', 0)
   setfield(ks, 'shrink', 0)
   setfield(k, 'subtype', 0)
   setfield(k, 'spec', ks)
   insert_after(h, node_tail(h), k);
   -- hpack
   setfield(box, 'head', nil); node_free(box)
   box = Dnode.hpack(h, new_width, 'exactly')
   setfield(box, 'height', hh)
   setfield(box, 'depth', hd)
   return box
end

----------------------------------------------------------------
-- TeX interface
----------------------------------------------------------------

-- rtlr: ルビ部分のボックスたち r1, r2, ...
-- rtlp: 親文字　のボックスたち p1, p2, ...
local function texiface_low(rst, rtlr, rtlp)
   local w = node_new(id_whatsit, sid_user)
   setfield(w, 'type', 110); setfield(w, 'user_id', RUBY_PRE)
   local wv = node_new(id_whatsit, sid_user)
   setfield(w, 'value', to_node(wv))
   setfield(wv, 'type', 100)
   setfield(wv, 'value', floor(#rtlr))
   set_attr(wv, attr_ruby, rst.rubyzw)
   set_attr(wv, attr_ruby_maxmargin, rst.maxmargin)
   set_attr(wv, attr_ruby_maxprep, rst.intrusionpre)
   set_attr(wv, attr_ruby_maxpostp, rst.intrusionpost)
   set_attr(wv, attr_ruby_stretch, rst.stretch)
   set_attr(wv, attr_ruby_mode, rst.mode)
   local n = wv
   for i = 1, #rtlr do
      _, n = insert_after(wv, n, rtlr[i])
      _, n = insert_after(wv, n, rtlp[i])
   end
   -- w.value: (whatsit) .. r1 .. p1 .. r2 .. p2
   Dnode.write(w)
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
	 if getfield(rtlr[i], 'width') > getfield(rtlp[i], 'width') then f = false; break end
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
   -- r: ルビ部分の格納された box，p: 同，親文字
   local rwidth = getfield(r, 'width')
   local sumprot = rwidth - getfield(p, 'width') -- >0
   local pre_intrusion, post_intrusion
   if intmode == 0 then --  とりあえず組んでから決める
      p = enlarge(p, rwidth, ppre, pmid, ppost, 0, 0) 
      pre_intrusion  = min(mapre, round(ppre*getfield(p, 'glue_set')*65536))
      post_intrusion = min(mapost, round(ppost*getfield(p, 'glue_set')*65536))
   elseif intmode == 1 then
      pre_intrusion = min(mapre, sumprot); 
      post_intrusion = min(mapost, max(sumprot-pre_intrusion, 0))
      p = enlarge(p, rwidth, ppre, pmid, ppost, pre_intrusion, post_intrusion)
   elseif intmode == 2 then
      post_intrusion = min(mapost, sumprot); 
      pre_intrusion = min(mapre, max(sumprot-post_intrusion, 0))
      p = enlarge(p, rwidth, ppre, pmid, ppost, pre_intrusion, post_intrusion) 
   else --  intmode == 3
      local n = min(mapre, mapost)*2
      if n < sumprot then
	 pre_intrusion = n/2; post_intrusion = n/2
      else
	 pre_intrusion = floor(sumprot/2); post_intrusion = sumprot - pre_intrusion
      end
      p = enlarge(p, rwidth, ppre, pmid, ppost, pre_intrusion, post_intrusion) 
      pre_intrusion = min(mapre, pre_intrusion + round(ppre*getfield(p, 'glue_set')*65536))
      post_intrusion = min(mapost, post_intrusion + round(ppost*getfield(p, 'glue_set')*65536))
   end
   setfield(r, 'shift', -pre_intrusion)
   local rwidth = rwidth - pre_intrusion - post_intrusion
   setfield(r, 'width', rwidth)
   setfield(p, 'width', rwidth)
   local ps = getfield(getlist(p), 'spec')
   setfield(ps, 'width', getfield(ps, 'width') - pre_intrusion)
   return r, p, post_intrusion
end

-- ルビボックスの生成（単一グループ）
-- returned value: <new box>, <ruby width>, <post_intrusion>
local max_margin
local function new_ruby_box(r, p, ppre, pmid, ppost, 
			    rpre, rmid, rpost, mapre, mapost, intmode)
   local post_intrusion = 0
   if getfield(r, 'width') > getfield(p, 'width') then  -- change the width of p
      r, p, post_intrusion  = enlarge_parent(r, p, ppre, pmid, ppost, mapre, mapost, intmode)
   elseif getfield(r, 'width') < getfield(p, 'width') then -- change the width of r
      r = enlarge(r, getfield(p, 'width'), rpre, rmid, rpost, 0, 0) 
      post_intrusion = 0
      local need_repack = false
      -- margin が大きくなりすぎた時の処理
      if round(rpre*getfield(r, 'glue_set')*65536) > max_margin then
	 local ps = getfield(getlist(r), 'spec'); need_repack = true
	 setfield(ps, 'width', max_margin)
         setfield(ps, 'stretch', 1) -- 全く伸縮しないのも困る
      end
      if round(rpost*getfield(r, 'glue_set')*65536) > max_margin then
	 local ps = getfield(node_tail(getlist(r)), 'spec'); need_repack = true
	 setfield(ps, 'width', max_margin)
         setfield(ps, 'stretch', 1) -- 全く伸縮しないのも困る
      end
      if need_repack then
	 local rt = r
	 r = Dnode.hpack(getlist(r), getfield(r, 'width'), 'exactly')
	 setfield(rt, 'head', nil); node_free(rt);
      end
   end
   local a = node_new(id_rule)
   setfield(a, 'width', 0)
   setfield(a, 'height', 0)
   setfield(a, 'depth', 0)
   insert_after(r, r, a); insert_after(r, a, p)
   setfield(p, 'next', nil)
   a = Dnode.vpack(r)
   setfield(a, 'height', getfield(p, 'height'))
   setfield(a, 'depth', getfield(p, 'depth'))
   setfield(a, 'shift', -(getfield(r, 'height')+getfield(r, 'depth')))
   return a, getfield(r, 'width'), post_intrusion
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
   local wv = getfield(w, 'value')
   local mdt -- nt*: node temp
   local coef = {} -- 連立一次方程式の拡大係数行列
   local rtb = expand_3bits(has_attr(wv, attr_ruby_stretch))
   local rtc = expand_3bits(has_attr(wv, attr_ruby_mode))
   local intmode = floor(has_attr(wv, attr_ruby_mode)/4)%4

   -- node list 展開・行末形の計算
   local nt, nta, ntb = wv, nil, nil -- nt*: node temp
   for i = 1, cmp do
      nt = node_next(nt); rb[i] = nt; nta = concat(nta, node_copy(nt))
      nt = node_next(nt); pb[i] = nt; ntb = concat(ntb, node_copy(nt))
      coef[i] = {}
      for j = 1, 2*i do coef[i][j] = 1 end
      for j = 2*i+1, 2*cmp+1 do coef[i][j] = 0 end
      kf[i], coef[i][2*cmp+2]
	 = new_ruby_box(node_copy(nta), node_copy(ntb), 
			rtb[6], rtb[5], rtb[4], rtc[10], rtc[9], rtc[8], 
			max_allow_pre, 0, intmode)
   end
   node_free(nta); node_free(ntb)

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
   local nt = wv
   Dnode.flush_list(node_next(wv))
   for i = 1, 2*cmp+1 do setfield(nt, 'next', kf[i]); nt = kf[i]  end

   gauss(coef) -- 掃きだし法で連立方程式形 coef を解く
   return coef
end

-- ノード追加
local function pre_low_app_node(head, w, cmp, coef, ht, dp)
   -- メインの node list 更新
   local nt, ntb = node_new(id_glue), node_new(id_glue_spec)
   setfield(ntb, 'width', coef[1][2*cmp+2])
   setfield(ntb, 'stretch_order', 0); setfield(ntb, 'stretch', 0)
   setfield(ntb, 'shrink_order', 0); setfield(ntb, 'shrink', 0)
   setfield(nt, 'subtype', 0); setfield(nt, 'spec', ntb)
   set_attr(nt, attr_ruby, 1); set_attr(w, attr_ruby, 2)
   head = insert_before(head, w, nt)
   nt = w
   for i = 1, cmp do
      -- rule
      local nta = node_new(id_rule); 
      setfield(nta, 'width', coef[i*2][2*cmp+2])
      setfield(nta, 'height', ht); setfield(nta, 'depth', dp)
      setfield(nta, 'subtype', 0)
      insert_after(head, nt, nta)
      set_attr(nta, attr_ruby, 2*i+1)
      -- glue
      nt = node_new(id_glue)
      local ntb = node_new(id_glue_spec);
      setfield(ntb, 'width', coef[i*2+1][2*cmp+2])
      setfield(ntb, 'stretch_order', 0); setfield(ntb, 'stretch', 0)
      setfield(ntb, 'shrink_order', 0); setfield(ntb, 'shrink', 0)
      setfield(nt, 'subtype', 0); setfield(nt, 'spec', ntb)
      set_attr(nt, attr_ruby, 2*i+2)
      insert_after(head, nta, nt)
   end
   tex.setattribute(attr_ruby, -0x7FFFFFFF)
   setfield(w, 'user_id', RUBY_POST)
   return head, node_next(nt)
end

local function pre_high(ahead)
   if not ahead then return ahead end
   local head = to_direct(ahead)
   max_post_intrusion_backup = 0
   local n = head
   while n do
      if getid(n) == id_whatsit then
         if getsubtype(n) == sid_user and getfield(n, 'user_id') == RUBY_PRE then
            local nv = getfield(n, 'value')
            max_allow_pre = has_attr(nv, attr_ruby_maxprep) or 0
	    if has_attr(n, attr_ruby) == 1 then 
	       -- 直前のルビで intrusion がおこる可能性あり．安全策をとる．
	       max_allow_pre = max(0, max_allow_pre - max_post_intrusion_backup)
	    end
	    max_post_intrusion_backup = 0
            max_allow_post = has_attr(nv, attr_ruby_maxpostp) or 0
            max_margin = has_attr(nv, attr_ruby_maxmargin) or 0
	    local coef = pre_low_cal_box(n, getfield(nv, 'value'))
	    local s = node_tail(nv) --ルビ文字
	    head, n = pre_low_app_node(
	       head, n, getfield(nv, 'value'), coef, 
               getfield(s, 'height'), getfield(s, 'depth')
	    )
         else 
            n = node_next(n)
         end
      else
         n = node_next(n)
      end
   end
   return to_node(head)
end 
luatexbase.add_to_callback('pre_linebreak_filter', pre_high, 'ltj.ruby.pre', 100)
luatexbase.add_to_callback('hpack_filter', pre_high, 'ltj.ruby.pre', 100)

----------------------------------------------------------------
-- post_line_break
----------------------------------------------------------------

local function post_lown(rs, rw, ch)
-- ch: the head of `current' hlist
   if #rs ==0 or not rw then return ch end
   local hn = has_attr(rs[1], attr_ruby)
   local fn = has_attr(rs[#rs], attr_ruby)
   local cmp = getfield(getfield(rw, 'value'), 'value')
   if hn==1 then 
      if fn==2*cmp+2 then
	 hn = node_tail(getfield(rw, 'value'))
         node_remove(getfield(rw, 'value'), hn)
	 insert_after(ch, rs[#rs], hn)
         set_attr(hn, attr_icflag,  PROCESSED)
      else
	 local deg = (fn-1)/2
         hn = getfield(rw, 'value')
         for i = 1, deg do hn = node_next(hn) end; 
	 node_remove(getfield(rw, 'value'), hn)
         setfield(hn, 'next', nil)
         insert_after(ch, rs[#rs], hn)
         set_attr(hn, attr_icflag,  PROCESSED)
     end
   else
      local deg = (hn-1)/2; 
      if deg == 1 then deg = 2 end
      hn = getfield(rw, 'value'); for i = 1, cmp+deg-1 do hn = node_next(hn) end
      -- -1 is needed except the case hn = 3, 
      --   because a ending-line form is removed already from the list
      node_remove(getfield(rw, 'value'), hn); setfield(hn, 'next', nil)
      insert_after(ch, rs[#rs], hn)
      set_attr(hn, attr_icflag,  PROCESSED)
   end
   for i = 1,#rs do 
      ch = node_remove(ch, rs[i]); node_free(rs[i]) 
   end
   -- cleanup
   if fn >= 2*cmp+1 then
      --setfield(hn, 'next', nil); 
      node_free(rw); 
   end
   return ch;
end


local function post_high_break(head)
   local h = to_direct(head); 
   local rs = {};  -- rs: sequence of ruby_nodes, 
   local rw = nil; -- rw: main whatsit
   while h do 
      if getid(h) == id_hlist then
         local ha = getlist(h); rs = {}
        while ha do
            local hai = getid(ha)
            local i = (((hai == id_glue and getsubtype(ha)==0) 
                           or (hai == id_rule and getsubtype(ha)==0)
                           or (hai == id_whatsit and getsubtype(ha)==sid_user 
                                  and getfield(ha, 'user_id')==RUBY_POST))
                          and has_attr(ha, attr_ruby)) or 0
            if i==1 then 
               setfield(h, 'head', post_lown(rs, rw, getlist(h))); rs = {}; rw = nil
               rs[1] = ha; ha = node_next(ha)
            elseif i>=3 then 
               rs[#rs+1] = ha; ha = node_next(ha)
            elseif i==2 then 
               rw = ha
               local hb, hc =  node_remove(getlist(h), rw)
               setfield(h, 'head', hb); ha = hc
            else
               ha = node_next(ha)
            end
         end
         setfield(h, 'head', post_lown(rs, rw, getlist(h)))
      end
      h = node_next(h)
   end

   return to_node(head)
end 

local function post_high_hbox(ahead)
   local ha = to_direct(ahead); local head = ha
   local rs = {};  -- rs: sequence of ruby_nodes, 
   local rw = nil; -- rw: main whatsit
   while ha do
      local hai = getid(ha)
      local i = (((hai == id_glue and getsubtype(ha)==0) 
                     or (hai == id_rule and getsubtype(ha)==0)
                     or (hai == id_whatsit and getsubtype(ha)==sid_user 
                            and getfield(ha, 'user_id', RUBY_POST)))
                    and has_attr(ha, attr_ruby)) or 0
      if i==1 then 
         head = post_lown(rs, rw, head); rs = {}; rw = nil
         table.insert(rs, ha); ha = node_next(ha)
      elseif i>=3 then 
         table.insert(rs, ha); ha = node_next(ha)
      elseif i==2 then 
         rw = ha; head, ha = node_remove(head, rw)
      else
         ha = node_next(ha)
      end
   end
   return to_node(post_lown(rs, rw, head))
end

luatexbase.add_to_callback('post_linebreak_filter', post_high_break, 'ltj.ruby.post_break', 100)
luatexbase.add_to_callback('hpack_filter', post_high_hbox, 'ltj.ruby.post_hbox', 101)


----------------------------------------------------------------
-- for jfmglue callbacks
----------------------------------------------------------------
do
   local RIPRE  = luatexja.stack_table_index.RIPRE
   local function whatsit_callback(Np, lp, Nq, bsl) 
      if Np.nuc then return Np 
      elseif getfield(lp, 'user_id') == RUBY_PRE then
         Np.first, Np.nuc, Np.last = lp, lp, lp
         local lpv = getfield(lp, 'value')
         local x = node_next(node_next(lpv))
         Np.last_char = luatexja.jfmglue.check_box_high(Np, getlist(x), nil)
         if Nq.id ~=id_pbox_w and  type(Nq.char)=='number' then
            if has_attr(lpv, attr_ruby_maxprep) < 0 then -- auto
               local p = round((ltjs.table_current_stack[RIPRE + Nq.char] or 0)
                                  *has_attr(lpv, attr_ruby))
               if has_attr(lpv, attr_ruby_mode)%2 == 0 then -- intrusion 無効
                  p = 0
               end
               set_attr(lpv, attr_ruby_maxprep, p)
            end
            if Nq.prev_ruby then 
               set_attr(lp, attr_ruby, 1)
            end
         else
            set_attr(getfield(lp, 'value'), attr_ruby_maxprep, 0)
         end
         return Np
      end
   end
   luatexbase.add_to_callback("luatexja.jfmglue.whatsit_getinfo", whatsit_callback,
                              "luatexja.ruby.np_info", 1)
end

do
   local RIPOST = luatexja.stack_table_index.RIPOST
   local function whatsit_after_callback(s, Nq, Np, bsl)
      if not s and  getfield(Nq.nuc, 'user_id') == RUBY_PRE then
         local nqnv = getfield(Nq.nuc, 'value')
         local x =  node_next(node_next(nqnv))
         for i = 2, getfield(nqnv, 'value') do x = node_next(node_next(x)) end
         Nq.last_char = luatexja.jfmglue.check_box_high(Nq, getlist(x), nil)
         luatexja.jfmglue.after_hlist(Nq)
         if Np and Np.id ~=id_pbox_w and type(Np.char)=='number' then
            if has_attr(nqnv, attr_ruby_maxpostp) < 0 then -- auto
               local p = round((ltjs.table_current_stack[RIPOST + Np.char] or 0)
                                  *has_attr(nqnv, attr_ruby))
               if has_attr(nqnv, attr_ruby_mode)%2 == 0 then -- intrusion 無効
                  p = 0
               end
               if has_attr(nqnv, attr_ruby_mode)%4 >= 2 then
                  local q = has_attr(nqnv, attr_ruby_maxprep)
                  if q < p then p = q
                  elseif q > p then
                     set_attr(nqnv, attr_ruby_maxprep, p)
                  end
               end
               set_attr(nqnv, attr_ruby_maxpostp, p)
            end
            Np.prev_ruby = true -- 前のクラスタがルビであったことのフラグ
         else -- 直前が文字以外なら intrusion なし
	    local nqnv = getfield(Nq.nuc, 'value')
            set_attr(nqnv, attr_ruby_maxpostp, 0)
	    if has_attr(nqnv, attr_ruby_mode)%4 >= 2 then
               set_attr(nqnv, attr_ruby_maxprep, 0)
            end
            if Np and Np.id == id_pbox_w then
               set_attr(getfield(Np.nuc, 'value'), attr_ruby_maxprep, 0)
            end
         end
	 return true
      else
	 return s
      end
   end
   luatexbase.add_to_callback("luatexja.jfmglue.whatsit_after", whatsit_after_callback,
                              "luatexja.ruby.np_info_after", 1)
end


