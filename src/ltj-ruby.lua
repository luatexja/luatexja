--
-- ltj-ruby.lua
--
luatexbase.provides_module({
  name = 'luatexja.ruby',
  date = '2018/09/29',
  description = 'Ruby annotation',
})
luatexja.ruby = {}
luatexja.load_module('stack');     local ltjs = luatexja.stack
luatexja.load_module('base');      local ltjb = luatexja.base

local to_node =  node.direct.tonode
local to_direct =  node.direct.todirect

local setfield =  node.direct.setfield
local setglue = luatexja.setglue
local getfield =  node.direct.getfield
local getid =  node.direct.getid
local getfont =  node.direct.getfont
local getlist =  node.direct.getlist
local getchar =  node.direct.getchar
local getsubtype =  node.direct.getsubtype

local node_new = node.direct.new
local node_remove = node.direct.remove
local node_next =  node.direct.getnext
local node_copy, node_free, node_tail = node.direct.copy, node.direct.free, node.direct.tail
local has_attr, set_attr = node.direct.has_attribute, node.direct.set_attribute
local insert_before, insert_after = node.direct.insert_before, node.direct.insert_after

local id_hlist = node.id('hlist')
local id_vlist = node.id('vlist')
local id_rule = node.id('rule')
local id_whatsit = node.id('whatsit')
local id_glue = node.id('glue')
local id_kern = node.id('kern')
local id_penalty = node.id('penalty')
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
local attr_ruby_id = luatexbase.attributes['ltj@kcat4'] -- uniq id
local attr_ruby_intergap = luatexbase.attributes['ltj@kcat5']
local attr_ruby = luatexbase.attributes['ltj@rubyattr']
-- ルビ内部処理用，以下のようにノードによって使われ方が異なる
-- * (whatsit) では JAglue 処理時に，
--     「2つ前のクラスタもルビ」 ==> そのルビクラスタの id
--   otherwise ==> unset
-- * (whatsit).value node ではルビ全角の値（sp単位）
-- * 行分割で whatsit の前後に並ぶノードでは，「何番目のルビ関連ノード」か
-- * (whatsit).value に続く整形済み vbox たちでは post_intrusion の値
local cat_lp = luatexbase.catcodetables['latex-package']

local round, floor = tex.round, math.floor
local min, max = math.min, math.max

luatexja.userid_table.RUBY_PRE = luatexbase.newuserwhatsitid('ruby_pre',  'luatexja')
luatexja.userid_table.RUBY_POST = luatexbase.newuserwhatsitid('ruby_post',  'luatexja')
local RUBY_PRE  = luatexja.userid_table.RUBY_PRE
local RUBY_POST = luatexja.userid_table.RUBY_POST
local PROCESSED_BEGIN_FLAG = luatexja.icflag_table.PROCESSED_BEGIN_FLAG

----------------------------------------------------------------
-- TeX interface 0
----------------------------------------------------------------
do
   local getbox = node.direct.getbox
   function luatexja.ruby.cpbox() return node_copy(getbox(0)) end
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

local function solve_1(coef)
   local a, b, c = coef[1][4], coef[2][4], coef[3][4]
   coef[1][4], coef[2][4], coef[3][4] = c-b, a+b-c, c-a
   return coef
end

local function solve_2(coef)
   local a, b, c, d, e = coef[1][6], coef[2][6], coef[3][6], coef[4][6], coef[5][6]
   coef[1][6], coef[2][6], coef[3][6], coef[4][6], coef[5][6]
      = e-c, a+c-e, e-a-d, b+d-e, e-b
   return coef
end


-- 実行回数 + ルビ中身 から uniq_id を作る関数
luatexja.ruby.old_break_info = {} -- public, 前 run 時の分割情報
local old_break_info = luatexja.ruby.old_break_info
local cache_handle
function luatexja.ruby.read_old_break_info()
   if  tex.jobname then
      local fname = tex.jobname .. '.ltjruby'
      local real_file = kpse.find_file(fname)
      if real_file then dofile(real_file) end
      cache_handle = io.open(fname, 'w')
   end
end
local make_uniq_id
do
   local exec_count = 0
   make_uniq_id = function (w)
      exec_count = exec_count + 1
      return exec_count
   end
end

-- concatenation of boxes: reusing nodes
-- ルビ組版が行われている段落/hboxでの設定が使われる．
-- ルビ文字を格納しているボックスでの設定ではない！
local concat
do
   local node_prev = node.direct.getprev
   local function get_attr_icflag(p)
      return (has_attr(p, attr_icflag) or 0) % PROCESSED_BEGIN_FLAG
   end
   function concat(f, b)
      if f then
	 if b then
	    local h, nh = getlist(f), getlist(b)
	    if getid(nh)==id_whatsit and getsubtype(nh)==sid_user then
	       nh=node_next(nh); node_free(node_prev(nh))
	    end
            set_attr(nh, attr_icflag,
	      get_attr_icflag(nh) + PROCESSED_BEGIN_FLAG)
	    setfield(node_tail(h), 'next', nh)
	    setfield(f, 'head', nil); node_free(f)
	    setfield(b, 'head', nil); node_free(b)
	    local g = luatexja.jfmglue.main(h,false)
	    return node.direct.hpack(g)
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
local enlarge
do
   local FROM_JFM       = luatexja.icflag_table.FROM_JFM
   local PROCESSED      = luatexja.icflag_table.PROCESSED
   local KANJI_SKIP     = luatexja.icflag_table.KANJI_SKIP
   local KANJI_SKIP_JFM = luatexja.icflag_table.KANJI_SKIP_JFM
   local XKANJI_SKIP    = luatexja.icflag_table.XKANJI_SKIP
   local XKANJI_SKIP_JFM= luatexja.icflag_table.XKANJI_SKIP_JFM
   enlarge = function (box, new_width, pre, middle, post, prenw, postnw)
      -- pre, middle, post: 伸縮比率
      -- prenw, postnw: 前後の自然長 (sp)
      local h = getlist(box);
      local hh, hd = getfield(box, 'height'), getfield(box, 'depth')
      local hx = h
      while hx do
	 local hic = has_attr(hx, attr_icflag) or 0
	 if (hic == KANJI_SKIP) or (hic == KANJI_SKIP_JFM)
            or (hic == XKANJI_SKIP) or (hic == XKANJI_SKIP_JFM)
            or ((hic<=FROM_JFM+63) and (hic>=FROM_JFM)) then
	    -- この 5 種類の空白をのばす
	       if getid(hx) == id_kern then
		  local k = node_new(id_glue)
		  setglue(k, getfield(hx, 'kern'), round(middle*65536), 0,
		             2, 0)
		  setfield(k, 'subtype', 0);
		  h = insert_after(h, hx, k);
		  h = node_remove(h, hx); node_free(hx); hx = k
	       else -- glue
                  setglue(hx, getfield(hx, 'width'), round(middle*65536), 0,
	                     2, 0)
	       end
	 end
	 hx = node_next(hx)
      end
      -- 先頭の空白を挿入
      local k = node_new(id_glue);
      setglue(k, prenw, round(pre*65536), 0, 2, 0)
      h = insert_before(h, h, k);
      -- 末尾の空白を挿入
      local k = node_new(id_glue);
      setglue(k, postnw, round(post*65536), 0, 2, 0)
      insert_after(h, node_tail(h), k);
      -- hpack
      setfield(box, 'head', nil); node_free(box)
      box = node.direct.hpack(h, new_width, 'exactly')
      setfield(box, 'height', hh)
      setfield(box, 'depth', hd)
      return box
   end
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
   setfield(wv, 'user_id', RUBY_PRE) -- dummy
   set_attr(wv, attr_ruby, rst.rubyzw)
   set_attr(wv, attr_ruby_maxmargin, rst.maxmargin)
   set_attr(wv, attr_ruby_maxprep, rst.pre)
   set_attr(wv, attr_ruby_maxpostp, rst.post)
   set_attr(wv, attr_ruby_intergap, rst.intergap)
   set_attr(wv, attr_ruby_stretch, rst.stretch)
   set_attr(wv, attr_ruby_mode, rst.mode)
   local n = wv
   for i = 1, #rtlr do
      _, n = insert_after(wv, n, rtlr[i])
      _, n = insert_after(wv, n, rtlp[i])
   end
   -- w.value: (whatsit) .. r1 .. p1 .. r2 .. p2
   node.direct.write(w); return w,wv
end

-- rst: table
function luatexja.ruby.texiface(rst, rtlr, rtlp)
   if #rtlr ~= #rtlp then
      for i=1, #rtlr do node_free(rtlr[i]) end
      for i=1, #rtlp do node_free(rtlp[i]) end
      ltjb.package_error('luatexja-ruby',
				  'Group count mismatch between the ruby and\n' ..
				     'the body (' .. #rtlr .. ' != ' .. #rtlp .. ').',
				  '')
   else
      local f = true
      for i = 1,#rtlr do
	 if getfield(rtlr[i], 'width') > getfield(rtlp[i], 'width') then
	    f = false; break
	 end
      end
      if f then -- モノルビ * n
	 local r,p = {true}, {true}
	 for i = 1,#rtlr do
	    r[1] = rtlr[i]; p[1] = rtlp[i]; texiface_low(rst, r, p)
	 end
      else
	 local w, wv = texiface_low(rst, rtlr, rtlp)
	 local id = make_uniq_id(w)
	 set_attr(wv, attr_ruby_id, id)
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
   local ps = getlist(p)
   setfield(ps, 'width', getfield(ps, 'width') - pre_intrusion)
   return r, p, post_intrusion
end

-- ルビボックスの生成（単一グループ）
-- returned value: <new box>, <ruby width>, <post_intrusion>
local max_margin
local function new_ruby_box(r, p, ppre, pmid, ppost,
			    mapre, mapost, imode, rgap)
   local post_intrusion = 0
   local intmode = imode%4
   local rpre, rmid, rpost, rsmash
   imode = floor(imode/262144); rsmash = (imode%2 ==1)
   imode = floor(imode/2); rpost = imode%8;
   imode = (imode-rpost)/8;  rmid  = imode%8;
   imode = (imode-rmid)/8;   rpre  = imode%8
   if getfield(r, 'width') > getfield(p, 'width') then  -- change the width of p
      r, p, post_intrusion  = enlarge_parent(r, p, ppre, pmid, ppost, mapre, mapost, intmode)
   elseif getfield(r, 'width') < getfield(p, 'width') then -- change the width of r
      r = enlarge(r, getfield(p, 'width'), rpre, rmid, rpost, 0, 0)
      post_intrusion = 0
      local need_repack = false
      -- margin が大きくなりすぎた時の処理
      if round(rpre*getfield(r, 'glue_set')*65536) > max_margin then
	 local ps = getlist(r); need_repack = true
	 setfield(ps, 'width', max_margin)
         setfield(ps, 'stretch', 1) -- 全く伸縮しないのも困る
      end
      if round(rpost*getfield(r, 'glue_set')*65536) > max_margin then
	 local ps = node_tail(getlist(r)); need_repack = true
	 setfield(ps, 'width', max_margin)
         setfield(ps, 'stretch', 1) -- 全く伸縮しないのも困る
      end
      if need_repack then
	 local rt = r
	 r = node.direct.hpack(getlist(r), getfield(r, 'width'), 'exactly')
	 setfield(rt, 'head', nil); node_free(rt);
      end
   end
   local a, k = node_new(id_rule), node_new(id_kern, 1)
   setfield(a, 'width', 0); setfield(a, 'height', 0)
   setfield(a, 'depth', 0); setfield(k, 'kern', rgap)
   insert_after(r, r, a); insert_after(r, a, k);
   insert_after(r, k, p); setfield(p, 'next', nil)
   a = node.direct.vpack(r); setfield(a, 'shift', 0)
   set_attr(a, attr_ruby, post_intrusion)
   if rsmash or getfield(a, 'height')<getfield(p, 'height') then
      local k = node_new(id_kern, 1)
      setfield(k, 'kern', -getfield(a, 'height')+getfield(p, 'height'))
      setfield(a, 'head', k); insert_before(r, r, k)
      setfield(a, 'height', getfield(p, 'height'))
   end

   return a, getfield(r, 'width'), post_intrusion
end


-- High-level routine in pre_linebreak_filter
local post_intrusion_backup
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
   local rgap = has_attr(wv, attr_ruby_intergap)
   local intmode = floor(has_attr(wv, attr_ruby_mode)/4)

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
			rtb[6], rtb[5], rtb[4], max_allow_pre, 0, intmode, rgap)
   end
   node_free(nta); node_free(ntb)

   -- 行頭形の計算
   local nta, ntb = nil, nil
   for i = cmp,1,-1 do
      coef[cmp+i] = {}
      for j = 1, 2*i-1 do coef[cmp+i][j] = 0 end
      for j = 2*i, 2*cmp+1 do coef[cmp+i][j] = 1 end
      nta = concat(node_copy(rb[i]), nta); ntb = concat(node_copy(pb[i]), ntb)
      kf[cmp+i], coef[cmp+i][2*cmp+2]
	 = new_ruby_box(node_copy(nta), node_copy(ntb),
			rtb[9], rtb[8], rtb[7], 0, max_allow_post, intmode, rgap)
   end

   -- ここで，nta, ntb には全 container を連結した box が入っているので
   -- それを使って行中形を計算する．
   coef[2*cmp+1] = {}
   for j = 1, 2*cmp+1 do coef[2*cmp+1][j] = 1 end
   kf[2*cmp+1], coef[2*cmp+1][2*cmp+2], post_intrusion_backup
      = new_ruby_box(nta, ntb, rtb[3], rtb[2], rtb[1],
                     max_allow_pre, max_allow_post, intmode, rgap)

   -- w.value の node list 更新．
   local nt = wv
   node.direct.flush_list(node_next(wv))
   for i = 1, 2*cmp+1 do setfield(nt, 'next', kf[i]); nt = kf[i]  end

   if cmp==1 then     solve_1(coef)
   elseif cmp==2 then solve_2(coef)
   else
      gauss(coef) -- 掃きだし法で連立方程式形 coef を解く
   end
   return coef
end

local first_whatsit
do
   local traverse_id = node.direct.traverse_id
   function first_whatsit(n) -- n 以後で最初の whatsit
      for h in traverse_id(id_whatsit, n) do
         return h
      end
      return nil
   end
end

local next_cluster_array = {}
-- ノード追加
local function pre_low_app_node(head, w, cmp, coef, ht, dp)
   -- メインの node list 更新
   local nt = node_new(id_glue)
   setglue(nt, coef[1][2*cmp+2], 0, 0, 0, 0)
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
      if i~=cmp or not next_cluster_array[w] then
	 nt = node_new(id_glue); insert_after(head, nta, nt)
      else
	 nt = next_cluster_array[w]
      end
      setglue(nt, coef[i*2+1][2*cmp+2], 0, 0, 0, 0)
      set_attr(nt, attr_ruby, 2*i+2)
   end
   tex.setattribute('global', attr_ruby, -0x7FFFFFFF)
   setfield(w, 'user_id', RUBY_POST)
   next_cluster_array[w]=nil
   return head, first_whatsit(node_next(nt))
end

local function pre_high(ahead)
   if not ahead then return ahead end
   local head = to_direct(ahead)
   post_intrusion_backup = 0
   local n = first_whatsit(head)
   while n do
      if getsubtype(n) == sid_user and getfield(n, 'user_id') == RUBY_PRE then
        local nv = getfield(n, 'value')
         max_allow_pre = has_attr(nv, attr_ruby_maxprep) or 0
         local atr = has_attr(n, attr_ruby) or 0
         if max_allow_pre < 0 then
            if atr>0 then
               -- 直前のルビで intrusion がおこる可能性あり．
               -- 前 run のデータが残っていればそれを使用，
               -- そうでなければ行中形のデータを利用する
               local op = old_break_info[atr] or post_intrusion_backup
               max_allow_pre = max(0, -max_allow_pre - op)
            else
               max_allow_pre = -max_allow_pre
            end
         end
         post_intrusion_backup = 0
         max_allow_post = has_attr(nv, attr_ruby_maxpostp) or 0
         max_margin = has_attr(nv, attr_ruby_maxmargin) or 0
         local coef = pre_low_cal_box(n, getfield(nv, 'value'))
         local s = node_tail(nv) --ルビ文字
         head, n = pre_low_app_node(
            head, n, getfield(nv, 'value'), coef,
            getfield(s, 'height'), getfield(s, 'depth')
         )
      else
         n = first_whatsit(node_next(n))
      end
   end
   return to_node(head)
end
luatexbase.add_to_callback('pre_linebreak_filter', pre_high, 'ltj.ruby.pre', 100)
luatexbase.add_to_callback('hpack_filter', pre_high, 'ltj.ruby.pre', 100)

----------------------------------------------------------------
-- post_line_break
----------------------------------------------------------------
local post_lown
do
   local function write_aux(wv, num)
      local id = has_attr(wv, attr_ruby_id)
      if id>0 and cache_handle then
	 cache_handle:write(
		    'luatexja.ruby.old_break_info['
		       .. tostring(id) .. ']=' .. num
		       .. '\n')
      end
   end

   post_lown = function (rs, rw, cmp, ch)
      -- ch: the head of `current' hlist
      if #rs ==0 or not rw then return ch end
      local hn = has_attr(rs[1], attr_ruby)
      local fn = has_attr(rs[#rs], attr_ruby)
      local wv = getfield(rw, 'value')
      if hn==1 then
	 if fn==2*cmp+2 then
	    local hn = node_tail(wv)
	    node_remove(wv, hn)
	    insert_after(ch, rs[1], hn)
	    set_attr(hn, attr_icflag,  PROCESSED)
	    write_aux(wv, has_attr(hn, attr_ruby))-- 行中形
	 else
	    local deg, hn = (fn-1)/2, wv
	    for i = 1, deg do hn = node_next(hn) end;
	    node_remove(wv, hn)
	    setfield(hn, 'next', nil)
	    insert_after(ch, rs[1], hn)
	    set_attr(hn, attr_icflag,  PROCESSED)
	    write_aux(wv, has_attr(hn, attr_ruby))
	 end
      else
	 local deg, hn = max((hn-1)/2,2), wv
	 for i = 1, cmp+deg-1 do hn = node_next(hn) end
	 -- -1 is needed except the case hn = 3,
	 --   because a ending-line form is removed already from the list
	 node_remove(wv, hn); setfield(hn, 'next', nil)
	 insert_after(ch, rs[1], hn)
	 set_attr(hn, attr_icflag,  PROCESSED)
	 if fn == 2*cmp-1 then
	    write_aux(wv, has_attr(hn, attr_ruby))
	 end
      end
      for i = 1,#rs do
	 local ri = rs[i]
	 ch = node_remove(ch, ri); node_free(ri);
      end
      -- cleanup
      if fn >= 2*cmp+1 then node_free(rw) end
      return ch;
   end
end

local function post_high_break(head)
   local rs = {}   -- rs: sequence of ruby_nodes,
   local rw = nil  -- rw: main whatsit
   local cmp = -2  -- dummy
   for h in node.direct.traverse_id(id_hlist, to_direct(head)) do
      for i = 1, #rs do rs[i] = nil end
      local ha = getlist(h)
      while ha do
	 local hai = getid(ha)
	 local i = ((hai == id_glue and getsubtype(ha)==0)
                       or (hai == id_rule and getsubtype(ha)==0)
                       or (hai == id_whatsit and getsubtype(ha)==sid_user
                              and getfield(ha, 'user_id', RUBY_POST)))
            and has_attr(ha, attr_ruby) or 0
	 if i==0 then
            ha = node_next(ha)
         elseif i==1 then
	    setfield(h, 'head', post_lown(rs, rw, cmp, getlist(h)))
	    for i = 2, #rs do rs[i] = nil end -- rs[1] is set by the next statement
	    rs[1], rw = ha, nil; ha = node_next(ha)
	 elseif i==2 then
	    rw = ha
	    cmp = getfield(getfield(rw, 'value'), 'value')
	    local hb, hc =  node_remove(getlist(h), rw)
	    setfield(h, 'head', hb); ha = hc
	 else -- i>=3
	    rs[#rs+1] = ha; ha = node_next(ha)
	 end
      end
      setfield(h, 'head', post_lown(rs, rw, cmp, getlist(h)))
   end
   return head
end

local function post_high_hbox(ahead)
   local ha = to_direct(ahead); local head = ha
   local rs = {};  -- rs: sequence of ruby_nodes,
   local rw = nil; -- rw: main whatsit
   local cmp
   while ha do
      local hai = getid(ha)
      local i = ((hai == id_glue and getsubtype(ha)==0)
                    or (hai == id_rule and getsubtype(ha)==0)
                    or (hai == id_whatsit and getsubtype(ha)==sid_user
                           and getfield(ha, 'user_id', RUBY_POST)))
         and has_attr(ha, attr_ruby) or 0
      if i==0 then
         ha = node_next(ha)
      elseif i==1 then
         head = post_lown(rs, rw, cmp, head)
         for i = 2, #rs do rs[i] = nil end -- rs[1] is set by the next statement
	 rs[1], rw = ha, nil; ha = node_next(ha)
      elseif i==2 then
         rw = ha
	 cmp = getfield(getfield(rw, 'value'), 'value')
	 head, ha = node_remove(head, rw)
      else -- i >= 3
         rs[#rs+1] = ha; ha = node_next(ha)
      end
   end
   return to_node(post_lown(rs, rw, cmp, head))
end

luatexbase.add_to_callback('post_linebreak_filter', post_high_break, 'ltj.ruby.post_break', 100)
luatexbase.add_to_callback('hpack_filter', post_high_hbox, 'ltj.ruby.post_hbox', 101)


----------------------------------------------------------------
-- for jfmglue callbacks
----------------------------------------------------------------
do
   local RIPRE  = luatexja.stack_table_index.RIPRE
   local function whatsit_callback(Np, lp, Nq)
      if Np.nuc then return Np
      elseif  getfield(lp, 'user_id') == RUBY_PRE then
         Np.first, Np.nuc, Np.last = lp, lp, lp
         local lpv = getfield(lp, 'value')
         local x = node_next(node_next(lpv))
         Np.last_char = luatexja.jfmglue.check_box_high(Np, getlist(x), nil)
         if Nq.id ~=id_pbox_w then
            if type(Nq.char)=='number' then
               -- Nq is a JAchar
               if has_attr(lpv, attr_ruby_maxprep) < 0 then -- auto
                  local p = round((ltjs.table_current_stack[RIPRE + Nq.char] or 0)
                                     *has_attr(lpv, attr_ruby))
                  if has_attr(lpv, attr_ruby_mode)%2 == 0 then -- intrusion 無効
                     p = 0
                  end
                  set_attr(lpv, attr_ruby_maxprep, -p)
               end
               if Nq.prev_ruby then
                  set_attr(lp, attr_ruby, Nq.prev_ruby)
               end
            elseif has_attr(lpv, attr_ruby_maxprep) < 0 then -- auto
               if Nq.char == 'parbdd' then
                  local p = round((ltjs.table_current_stack[RIPRE-1] or 0)
                                     *has_attr(lpv, attr_ruby))
                  p = min(p, Nq.width)
                 if has_attr(lpv, attr_ruby_mode)%2 == 0 then -- intrusion 無効
                     p = 0
                  end
                  set_attr(lpv, attr_ruby_maxprep, p)
               else
                  set_attr(lpv, attr_ruby_maxprep, 0)
               end
            end
         elseif has_attr(lpv, attr_ruby_maxprep) < 0 then -- auto
            set_attr(lpv, attr_ruby_maxprep, 0)
         end
         return Np
      else
        return Np
      end
   end
   luatexbase.add_to_callback("luatexja.jfmglue.whatsit_getinfo", whatsit_callback,
                              "luatexja.ruby.np_info", 1)
end

do
   local RIPOST = luatexja.stack_table_index.RIPOST
   local function whatsit_after_callback(s, Nq, Np)
      if not s and  getfield(Nq.nuc, 'user_id') == RUBY_PRE then
	 if Np then
	    local last_glue = node_new(id_glue)
	    set_attr(last_glue, attr_icflag, 0)
	    insert_before(Nq.nuc, Np.first, last_glue)
	    Np.first = last_glue
	    next_cluster_array[Nq.nuc] = last_glue -- ルビ処理用のグルー
	 end
         local nqnv = getfield(Nq.nuc, 'value')
         local x =  node_next(node_next(nqnv))
         for i = 2, getfield(nqnv, 'value') do x = node_next(node_next(x)) end
         Nq.last_char = luatexja.jfmglue.check_box_high(Nq, getlist(x), nil)
         luatexja.jfmglue.after_hlist(Nq)
         if Np and Np.id ~=id_pbox_w and type(Np.char)=='number' then
	    -- Np is a JAchar
	    local rm = has_attr(nqnv, attr_ruby_mode)
            if has_attr(nqnv, attr_ruby_maxpostp) < 0 then -- auto
               local p = round((ltjs.table_current_stack[RIPOST + Np.char] or 0)
                                  *has_attr(nqnv, attr_ruby))
               if rm%2 == 0 then -- intrusion 無効
                  p = 0
               end
               if rm%4 >= 2 then
                  local q = has_attr(nqnv, attr_ruby_maxprep)
                  if q < p then p = q
                  elseif q > p then
                     set_attr(nqnv, attr_ruby_maxprep, p)
                  end
               end
               set_attr(nqnv, attr_ruby_maxpostp, p)
            end
            Np.prev_ruby = has_attr(getfield(Nq.nuc, 'value'), attr_ruby_id)
	    -- 前のクラスタがルビであったことのフラグ
         else -- 直前が文字以外
	    local nqnv = getfield(Nq.nuc, 'value')
            if has_attr(nqnv, attr_ruby_maxpostp) < 0 then -- auto
	       set_attr(nqnv, attr_ruby_maxpostp, 0)
	       if has_attr(nqnv, attr_ruby_mode)%4 >= 2 then
		  set_attr(nqnv, attr_ruby_maxprep, 0)
	       end
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

