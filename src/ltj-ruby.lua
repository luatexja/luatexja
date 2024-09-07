--
-- ltj-ruby.lua
--
luatexbase.provides_module({
  name = 'luatexja.ruby',
  date = '2024-09-06',
  description = 'Ruby annotation',
})
luatexja.ruby = {}
luatexja.load_module 'stack';     local ltjs = luatexja.stack
luatexja.load_module 'base';      local ltjb = luatexja.base

local to_node =  node.direct.tonode
local to_direct =  node.direct.todirect

local getfield =  node.direct.getfield
local getid =  node.direct.getid
local getfont =  node.direct.getfont
local getlist =  node.direct.getlist
local getchar =  node.direct.getchar
local getsubtype =  node.direct.getsubtype
local getkern = node.direct.getkern
local getwidth =  node.direct.getwidth
local getheight = node.direct.getheight
local getdepth = node.direct.getdepth
local getwhd = node.direct.getwhd
local getvalue = node.direct.getdata
local setfield =  node.direct.setfield
local setglue = node.direct.setglue
local setkern = node.direct.setkern
local setnext = node.direct.setnext
local setshift = node.direct.setshift
local setwidth = node.direct.setwidth
local setheight = node.direct.setheight
local setdepth = node.direct.setdepth
local setwhd = node.direct.setwhd
local setlist = node.direct.setlist
local setvalue = node.direct.setdata

local node_new = luatexja.dnode_new
local node_remove = node.direct.remove
local node_next =  node.direct.getnext
local node_copy, node_tail = node.direct.copy, node.direct.tail
local node_free = node.direct.flush_node or node.direct.free
local get_attr, set_attr = node.direct.get_attribute, node.direct.set_attribute
local insert_before, insert_after = node.direct.insert_before, node.direct.insert_after
local hpack = node.direct.hpack
local node_inherit_attr = luatexja.node_inherit_attr

local id_hlist  = node.id 'hlist'
local id_vlist  = node.id 'vlist'
local id_rule   = node.id 'rule'
local id_whatsit= node.id 'whatsit'
local id_glue   = node.id 'glue'
local id_kern   = node.id 'kern'
local id_penalty= node.id 'penalty'
local sid_user  = node.subtype 'user_defined'
local ltjs_get_stack_table = luatexja.stack.get_stack_table
local id_pbox_w = 258 -- cluster which consists of a whatsit

local attr_icflag = luatexbase.attributes['ltj@icflag']
-- ルビ処理用の attribute は他のやつの流用なので注意！
-- 進入許容量 (sp)
local attr_ruby_id = luatexbase.attributes['ltj@kcat4'] -- uniq id
local attr_ruby = luatexbase.attributes['ltj@rubyattr']
-- ルビ内部処理用，以下のようにノードによって使われ方が異なる
-- * (whatsit) では JAglue 処理時に，
--     「2つ前のクラスタもルビ」 ==> そのルビクラスタの id
--   otherwise ==> unset
-- * (whatsit).value node ではルビ全角の値（sp単位）
-- * 行分割で whatsit の前後に並ぶノードでは，「何番目のルビ関連ノード」か
-- * (whatsit).value に続く整形済み vbox たちでは post_intrusion の値
local attr_ruby_post_jfmgk = luatexbase.attributes['ltj@kcat3']
-- JAglue 処理時に，2つ前のクラスタもルビであれば，そのルビが直後の和文処理グルーへ
-- 正の進入をしたか否か（した：1，しなかった：0）
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
      if cache_handle then
         cache_handle:write('local lrob=luatexja.ruby.old_break_info\n')
      end
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
local function get_attr_icflag(p)
    return (get_attr(p, attr_icflag) or 0) % PROCESSED_BEGIN_FLAG
end
local concat
do
   local node_prev = node.direct.getprev
   function concat(f, b)
      if f then
         if b then
            local h, nh = getlist(f), getlist(b)
            if getid(nh)==id_whatsit and getsubtype(nh)==sid_user then
               nh=node_next(nh); node_free(node_prev(nh))
            end
            set_attr(nh, attr_icflag,
              get_attr_icflag(nh) + PROCESSED_BEGIN_FLAG)
            setnext(node_tail(h), nh)
            setlist(f, nil)
            setlist(b, nil); node_free(b)
            local g = luatexja.jfmglue.main(h,false)
            g = node_inherit_attr(hpack(g),f); node_free(f); return g
         else
            return f
         end
      elseif b then
         return b
      else
         local h = node_new(id_hlist, 0)
         setwhd(h, 0, 0, 0)
         setfield(h, 'glue_set', 0)
         setfield(h, 'glue_order', 0)
         setlist(h, nil)
         return h
      end
   end
end

local function expand_3bits(num)
   local t = {}; local a = num
   for i = 1, 10 do t[i], a = a%8, a//8 end
   return t
end
----------------------------------------------------------------
-- 補助関数群 2
----------------------------------------------------------------

-- box の中身のノードは再利用される
local enlarge
do
   local dimensions = node.direct.dimensions
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
      local _, hh, hd = getwhd(box)
      local hx = h
      while hx do
         local hic = get_attr(hx, attr_icflag) or 0
         if (hic == KANJI_SKIP) or (hic == KANJI_SKIP_JFM)
            or (hic == XKANJI_SKIP) or (hic == XKANJI_SKIP_JFM)
            or ((hic<=FROM_JFM+63) and (hic>=FROM_JFM)) then
            -- この 5 種類の空白をのばす
               if getid(hx) == id_kern then
                  local k = node_new(id_glue, 0)
                  setglue(k, getkern(hx), round(middle*65536), 0,
                             2, 0)
                  h = insert_after(h, hx, k);
                  h = node_remove(h, hx); node_free(hx); hx = k
               else -- glue
                  setglue(hx, getwidth(hx), round(middle*65536), 0,
                             2, 0)
               end
         end
         hx = node_next(hx)
      end
      -- 先頭の空白を挿入
      local k1 = node_new(id_glue);
      setglue(k1, prenw, round(pre*65536), 0, 2, 0)
      h = insert_before(h, h, k1);
      -- 末尾の空白を挿入
      local k2 = node_new(id_glue);
      setglue(k2, postnw, round(post*65536), 0, 2, 0)
      insert_after(h, node_tail(h), k2);
      -- hpack
      setlist(box, nil);
      local new_box = node_inherit_attr(hpack(h, new_width, 'exactly'), box)
      setheight(new_box, hh); setdepth(new_box, hd)
      node_free(box); 
      local gset, gsign, go 
        = getfield(new_box,'glue_set'), getfield(new_box,'glue_sign'), getfield(new_box,'glue_order')
      return new_box, (dimensions(gset, gsign, go, k1, node_next(k1))), (dimensions(gset, gsign, go, k2))
      -- return value: (enlarged box), (width of left glue), (width of right glue)
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
   setfield(wv, 'type', 108)
   setvalue(w, to_node(wv)); setvalue(wv, rst); rst.count = #rtlr
   setfield(wv, 'user_id', RUBY_PRE) -- dummy
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
      local f, eps = true, rst.eps
      for i = 1,#rtlr do
         if getwidth(rtlr[i]) > getwidth(rtlp[i]) + eps then
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
-- pre_linebreak
----------------------------------------------------------------

-- r, p の中身のノードは再利用される
local function enlarge_parent(r, p, tmp_tbl, no_begin, no_end)
   -- r: ルビ部分の格納された box，p: 同，親文字
   -- no_begin: 行頭形ではないか
   -- no_end: 行末形ではないか
   local rwidth = getwidth(r)
   local sumprot = rwidth - getwidth(p) -- >0
   local pre_intrusion, post_intrusion
   local pre_protrusion, post_protrusion
   local ppre, pmid, ppost = tmp_tbl.ppre, tmp_tbl.pmid, tmp_tbl.ppost
   local mapre, mapost = tmp_tbl.mapre, tmp_tbl.mapost
   local intmode = (tmp_tbl.mode//4)%8
   if no_begin then mapre  = mapre + tmp_tbl.before_jfmgk end
   if no_end   then mapost = mapost + tmp_tbl.after_jfmgk end
   if (tmp_tbl.mode%4 >=2) and (tmp_tbl.pre<0) and (tmp_tbl.post<0) then
       mapre = min(mapre,mapost); mapost = mapre
   end
   if intmode == 0 then --  とりあえず組んでから決める
      p, pre_protrusion, post_protrusion = enlarge(p, rwidth, ppre, pmid, ppost, 0, 0)
      pre_intrusion  = min(mapre, round(ppre*getfield(p, 'glue_set')*65536))
      post_intrusion = min(mapost, round(ppost*getfield(p, 'glue_set')*65536))
   elseif intmode == 1 then
      pre_intrusion = min(mapre, sumprot);
      post_intrusion = min(mapost, max(sumprot-pre_intrusion, 0))
      p, pre_protrusion, post_protrusion = enlarge(p, rwidth, ppre, pmid, ppost, pre_intrusion, post_intrusion)
   elseif intmode == 2 then
      post_intrusion = min(mapost, sumprot);
      pre_intrusion = min(mapre, max(sumprot-post_intrusion, 0))
      p, pre_protrusion, post_protrusion = enlarge(p, rwidth, ppre, pmid, ppost, pre_intrusion, post_intrusion)
   elseif intmode==3 then
      local n = min(mapre, mapost)*2
      if n < sumprot then
         pre_intrusion = n/2; post_intrusion = n/2
      else
         pre_intrusion = sumprot//2; post_intrusion = sumprot - pre_intrusion
      end
      p, pre_protrusion, post_protrusion = enlarge(p, rwidth, ppre, pmid, ppost, pre_intrusion, post_intrusion)
      pre_intrusion = min(mapre, pre_intrusion + round(ppre*getfield(p, 'glue_set')*65536))
      post_intrusion = min(mapost, post_intrusion + round(ppost*getfield(p, 'glue_set')*65536))
   else  --  intmode == 4
      if 2*min(mapre, mapost) > sumprot then
         pre_intrusion = sumprot//2; post_intrusion = sumprot/2
      elseif mapre>=mapost then 
         pre_intrusion, post_intrusion = min(mapre, sumprot-mapost), mapost
      else
         pre_intrusion, post_intrusion = mapre, min(mapost, sumprot-mapre)
      end
      p, pre_protrusion, post_protrusion = enlarge(p, rwidth, ppre, pmid, ppost, pre_intrusion, post_intrusion)
   end
   setshift(r, -pre_intrusion)
   local rwidth = rwidth - pre_intrusion - post_intrusion
   setwidth(r, rwidth); setwidth(p, rwidth)
   local ps = getlist(p)
   setwidth(ps, getwidth(ps) - pre_intrusion)
   local orig_post_intrusion, post_jfmgk = post_intrusion, false
   if no_end then
       if orig_post_intrusion > tmp_tbl.after_jfmgk then
           orig_post_intrusion = orig_post_intrusion - tmp_tbl.after_jfmgk
           post_jfmgk = (tmp_tbl.after_jfmgk > 0)
       else
           orig_post_intrusion = 0
           post_jfmgk = (post_intrusion > 0)
       end
    end
    return r, p, orig_post_intrusion, post_jfmgk, 
      pre_protrusion - pre_intrusion, post_protrusion - post_intrusion
end

-- ルビボックスの生成（単一グループ）
-- returned value: <new box>, <ruby width>, <post_intrusion>
local max_margin
local function new_ruby_box(r, p, tmp_tbl, no_begin, no_end, w)
   -- no_begin: 行頭形ではないか
   -- no_end: 行末形ではないか
   local post_intrusion, post_jfmgk = 0, false
   local imode
   local ppre, pmid, ppost = tmp_tbl.ppre, tmp_tbl.pmid, tmp_tbl.ppost
   local mapre, mapost = tmp_tbl.mapre, tmp_tbl.mapost
   local rpre, rmid, rpost, rsmash
   local protrusion = {0, 0}; tmp_tbl[tmp_tbl.index] = protrusion
   imode = tmp_tbl.mode//0x100000; rsmash = (imode%2 ==1)
   imode = imode//2; rpost = imode%8;
   imode = (imode-rpost)/8;  rmid  = imode%8;
   imode = (imode-rmid)/8;   rpre  = imode%8
   if getwidth(r) > getwidth(p) then  -- change the width of p
      r, p, post_intrusion, post_jfmgk, protrusion[1], protrusion[2]
        = enlarge_parent(r, p, tmp_tbl, no_begin, no_end)
   elseif getwidth(r) < getwidth(p) then -- change the width of r
      r = enlarge(r, getwidth(p), rpre, rmid, rpost, 0, 0)
      post_intrusion = 0
      local need_repack = false
      -- margin が大きくなりすぎた時の処理
      if round(rpre*getfield(r, 'glue_set')*65536) > max_margin then
         local ps = getlist(r); need_repack = true
         setwidth(ps, max_margin)
         setfield(ps, 'stretch', 1) -- 全く伸縮しないのも困る
      end
      if round(rpost*getfield(r, 'glue_set')*65536) > max_margin then
         local ps = node_tail(getlist(r)); need_repack = true
         setwidth(ps, max_margin)
         setfield(ps, 'stretch', 1) -- 全く伸縮しないのも困る
      end
      if need_repack then
         local rt = r
         r = node_inherit_attr(hpack(getlist(r), getwidth(r), 'exactly'), r)
         setlist(rt, nil); node_free(rt);
      end
   end
   local a, k = node_new(id_rule), node_new(id_kern, 1)
   setwhd(a, 0, 0, 0); setkern(k, tmp_tbl.intergap)
   insert_after(r, r, a); insert_after(r, a, k);
   insert_after(r, k, p); setnext(p, nil)
   if tmp_tbl.rubydepth >= 0 then setdepth(r, tmp_tbl.rubydepth) end
   if tmp_tbl.baseheight >= 0 then setheight(p, tmp_tbl.baseheight) end
   a = node_inherit_attr(node.direct.vpack(r), p) 
   setshift(a, 0)
   set_attr(a, attr_ruby, post_intrusion)
   set_attr(a, attr_ruby_post_jfmgk, post_jfmgk and 1 or 0)
   if rsmash or getheight(a)<getheight(p) then
      local k = node_new(id_kern, 1)
      setkern(k, -getheight(a)+getheight(p))
      setlist(a, k); insert_before(r, r, k)
      setheight(a, getheight(p))
   end

   return a, getwidth(r), post_intrusion, post_jfmgk
end


-- High-level routine in pre_linebreak_filter
local post_intrusion_backup, post_jfmgk_backup
local max_allow_pre, max_allow_post

local flush_list = node.direct.flush_list
-- 中付き熟語ルビ，cmp containers
-- 「文字の構成を考えた」やつはどうしよう
local pre_low_cal_box
do
   local node_prev = node.direct.getprev
pre_low_cal_box = function (w, cmp)
   local rb = {}
   local pb = {}
   local kf = {}
   -- kf[i] : container 1--i からなる行末形
   -- kf[cmp+i] : container i--cmp からなる行頭形
   -- kf[2cmp+1] : 行中形
   local wv = getvalue(w)
   local rst = getvalue(wv)
   local mdt -- nt*: node temp
   local coef = {} -- 連立一次方程式の拡大係数行列
   local rtb = expand_3bits(rst.stretch)

   local kb, ka
   if rst.quirk_protrusion then
       kb = node_prev(node_tail(wv)); ka = node_next(kb)
       node_remove(wv, kb); node_remove(wv, ka)
   end
   -- node list 展開・行末形の計算
   local nt, nta, ntb = wv, nil, nil -- nt*: node temp
   rst.ppre, rst.pmid, rst.ppost = rtb[6], rtb[5], rtb[4]
   rst.mapre, rst.mapost = max_allow_pre, 0
   for i = 1, cmp do
      nt = node_next(nt); rb[i] = nt; nta = concat(nta, node_copy(nt))
      nt = node_next(nt); pb[i] = nt; ntb = concat(ntb, node_copy(nt))
      coef[i] = {}
      for j = 1, 2*i do coef[i][j] = 1 end
      for j = 2*i+1, 2*cmp+1 do coef[i][j] = 0 end
      rst.index = i
      kf[i], coef[i][2*cmp+2]
         = new_ruby_box(node_copy(nta), node_copy(ntb), rst, true, false, w)
   end
   node_free(nta); node_free(ntb)

   -- 行頭形の計算
   local nta, ntb = nil, nil
   rst.ppre, rst.pmid, rst.ppost = rtb[9], rtb[8], rtb[7]
   rst.mapre, rst.mapost = 0, max_allow_post
   for i = cmp,1,-1 do
      coef[cmp+i] = {}
      for j = 1, 2*i-1 do coef[cmp+i][j] = 0 end
      for j = 2*i, 2*cmp+1 do coef[cmp+i][j] = 1 end
      nta = concat(node_copy(rb[i]), nta); ntb = concat(node_copy(pb[i]), ntb)
      rst.index = 2*cmp+1-i
      kf[cmp+i], coef[cmp+i][2*cmp+2]
         = new_ruby_box(node_copy(nta), node_copy(ntb), rst, false, true, w)
   end

   -- ここで，nta, ntb には全 container を連結した box が入っているので
   -- それを使って行中形を計算する．
   coef[2*cmp+1] = {}
   for j = 1, 2*cmp+1 do coef[2*cmp+1][j] = 1 end
   rst.ppre, rst.pmid, rst.ppost = rtb[3], rtb[2], rtb[1]
   rst.mapre, rst.mapost = max_allow_pre, max_allow_post
   rst.index = 2*cmp+1
   kf[2*cmp+1], coef[2*cmp+1][2*cmp+2], post_intrusion_backup, post_jfmgk_backup
      = new_ruby_box(nta, ntb, rst, true, true, w)

   -- w.value の node list 更新．
   local nt = wv
   flush_list(node_next(wv))
   for i = 1, 2*cmp+1 do setnext(nt, kf[i]); nt = kf[i]  end
   if rst.quirk_protrusion then
       insert_after(wv, nt, kb); insert_after(wv, kb, ka);
   end

   if cmp==1 then     solve_1(coef)
   elseif cmp==2 then solve_2(coef)
   else
      gauss(coef) -- 掃きだし法で連立方程式形 coef を解く
   end
   return coef
end
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
local pre_high
-- ノード追加
do
   local node_prev = node.direct.getprev
   local KINSOKU = luatexja.icflag_table.KINSOKU
   local function pre_low_app_node (head, w, cmp, coef, ht, dp)
   -- メインの node list 更新
   local nt = node_new(id_glue, nil, w) -- INHERIT ATTRIBUTES OF w
   setglue(nt, coef[1][2*cmp+2], 0, 0, 0, 0)
   set_attr(nt, attr_ruby, 1); set_attr(w, attr_ruby, 2)
   head = insert_before(head, w, nt)
   nt = w
   for i = 1, cmp do
      -- rule
      local nta = node_new(id_rule, 0, w); -- INHERIT ATTRIBUTES OF w
      setwhd(nta, coef[i*2][2*cmp+2], ht, dp)
      insert_after(head, nt, nta)
      set_attr(nta, attr_ruby, 2*i+1)
      -- glue
      if i~=cmp or not next_cluster_array[w] then
         nt = node_new(id_glue, nil, w);  -- INHERIT ATTRIBUTE OF w
         insert_after(head, nta, nt)
      else
         nt = next_cluster_array[w]; local f = node_next(nta)
         while f and f~=nt do
            if getid(f)==id_glue then
               node_remove(head, nt); insert_before(head, f, nt); f = nil
            else if getid(f)==id_penalty and get_attr_icflag(f)==KINSOKU then
                 node_inherit_attr(f, w) -- INHERIT ATTRIBUTE OF w; for lua-ul
                 set_attr(f, attr_icflag, KINSOKU)
               end
               f = node_next(f)
            end
         end
      end
      setglue(nt, coef[i*2+1][2*cmp+2], 0, 0, 0, 0)
      set_attr(nt, attr_ruby, 2*i+2)
   end
   tex.setattribute('global', attr_ruby, -0x7FFFFFFF)
   setfield(w, 'user_id', RUBY_POST)
   next_cluster_array[w]=nil
   return head, first_whatsit(node_next(nt))
end
pre_high = function (ahead)
   if not ahead then return ahead end
   local head = to_direct(ahead)
   post_intrusion_backup, post_jfmgk_backup = 0, false
   local n = first_whatsit(head)
   while n do
       if getsubtype(n) == sid_user and getfield(n, 'user_id') == RUBY_PRE then
         local nv = getvalue(n)
         local rst = getvalue(nv)
         max_allow_pre = rst.pre or 0
         local atr = get_attr(n, attr_ruby) or 0
         if max_allow_pre < 0 then
             -- 直前のルビで intrusion がおこる可能性あり．
             -- 前 run のデータが残っていればそれを使用，
             -- そうでなければ行中形のデータを利用する
             local op = (atr>0) and (old_break_info[atr] or post_intrusion_backup) or 0
             max_allow_pre = max(0, -max_allow_pre - op)
         end
         if rst.exclude_pre_from_prev_ruby  and atr>0 and old_break_info[-atr]
           and (old_break_info[-atr]>0 or post_jfmgk_backup) then
            -- 「直前のルビが JFM グルーに進入→現在のルビの前文字進入はなし」という状況
            max_allow_pre = 0; rst.exclude_pre_from_prev_ruby=false
         end
         if rst.exclude_pre_jfmgk_from_prev_ruby
            and atr>0 and ((old_break_info[atr]  or post_intrusion_backup) > 0) then
            -- 「直前のルビが文字に進入→現在のルビの和文処理グルーへの進入はなし」という状況
            max_allow_pre = 0;rst.before_jfmgk = 0
         end
         post_intrusion_backup, post_jfmgk_backup = 0, false
         max_allow_post = rst.post or 0
         max_margin = rst.maxmargin or 0
         local coef = pre_low_cal_box(n, rst.count)
         local s = node_tail(nv); if rst.quirk_protrusion then s = node_prev(node_prev(s)) end --ルビ文字
         head, n = pre_low_app_node(
            head, n, rst.count, coef, getheight(s), getdepth(s)
         )
      else
         n = first_whatsit(node_next(n))
      end
   end
   return to_node(head)
end
end
luatexbase.add_to_callback('pre_linebreak_filter', pre_high, 'ltj.ruby.pre', 100)

----------------------------------------------------------------
-- post_linebreak
----------------------------------------------------------------
local post_lown
do
   local function write_aux(wv, num, bool)
      local id = get_attr(wv, attr_ruby_id) or 0
      if id>0 and cache_handle then
         cache_handle:write(
            'lrob[' .. tostring(id) .. ']=' .. tostring(num) .. '\nlrob[' .. tostring(-id) .. ']=' .. tostring(bool) .. '\n')
      end
   end
   local node_prev = node.direct.getprev
   local function new_kern(inherit, num)
    local k = node_new(id_kern, 1, inherit); setkern(k, num); set_attr(kt, attr_icflag, PROCESSED);
      return k;
   end
   post_lown = function (rs, rw, cmp, ch)
      -- ch: the head of `current' hlist
      if #rs ==0 or not rw then return ch end
      local hn = get_attr(rs[1], attr_ruby)
      local fn = get_attr(rs[#rs], attr_ruby)
      local wv = getvalue(rw); local rst = getvalue(wv)
      if hn==1 then
         if fn==2*cmp+2 then
            -- 行中形  
            local nn = node_tail(wv); 
            if rst.quirk_protrusion then
               local prot_b,prot_a = rst[fn-1][1], rst[fn-1][2]
               local ka=nn; local kb = node_prev(nn); nn = node_prev(kb)
               node_remove(wv, nn); node_remove(wv, kb); node_remove(wv, ka)
               if prot_b~=0 then
                   setkern(kb, prot_b); insert_after(ch, rs[1], kb);
                   local kt = new_kern(rw, -prot_b); insert_after(ch, kb, kt); 
                   insert_after(ch, kt, nn);
               else 
                   node_free(kb); insert_after(ch, rs[1], nn)
               end
               if prot_a~=0 then
                  local kt = new_kern(rw, -prot_a); insert_after(ch, nn, kt);
                  setkern(ka, prot_a); insert_after(ch, kt, ka);
               else node_free(ka)
               end   
            else 
               node_remove(wv, nn); insert_after(ch, rs[1], nn)
            end
            set_attr(nn, attr_icflag, PROCESSED)
            write_aux(wv, get_attr(nn, attr_ruby), get_attr(nn, attr_ruby_post_jfmgk))
         else
            -- 行末形
            local deg, nn = (fn-1)/2, wv; for i = 1, deg do nn = node_next(nn) end
            if rst.quirk_protrusion then
               local prot_b = rst[deg][1]
               local ka = node_tail(wv); local kb = node_prev(ka);
               node_remove(wv, nn); setnext(nn, nil); node_remove(wv, kb);
               if prot_b~=0 then
                   setkern(kb, prot_b); insert_after(ch, rs[1], kb);
                   local kt = new_kern(rw, -prot_b); insert_after(ch, kb, kt); 
                   insert_after(ch, kt, nn);
               else 
                   node_free(kb); insert_after(ch, rs[1], nn)
               end
               if deg==cmp then
                  local prot_a = rst[deg][2]; node_remove(wv,ka)
                  if prot_a~=0 then
                     local kt = new_kern(rw, -prot_a); insert_after(ch, nn, kt);
                     setkern(ka, prot_a); insert_after(ch, kt, ka);
                  else node_free(ka)
                  end   
               end   
            else 
               node_remove(wv, nn); setnext(nn, nil); insert_after(ch, rs[1], nn)
            end

            set_attr(nn, attr_icflag, PROCESSED)
            write_aux(wv, get_attr(nn, attr_ruby), get_attr(nn, attr_ruby_post_jfmgk))
         end
      else
         -- 行頭形
         local nn = wv; for i = 1, cmp+max((hn-1)/2,2)-1 do nn = node_next(nn) end
         -- -1 is needed except the case hn = 3,
         --   because a ending-line form is removed already from the list
         if rst.quirk_protrusion then
            local deg=(hn-1)/2; local prot_b = rst[2*cmp+1-deg][1]
            local ka = node_tail(wv); node_remove(wv, nn); setnext(nn, nil);
            if deg==1 then
               local kb = node_prev(ka); node_remove(wv, kb);
               if prot_b~=0 then
                   setkern(kb, prot_b); insert_after(ch, rs[1], kb);
                   local kt = new_kern(rw, -prot_b); insert_after(ch, kb, kt); 
                   insert_after(ch, kt, nn);
               else 
                   node_free(kb); insert_after(ch, rs[1], nn)
               end
            else insert_after(ch, rs[1], nn)
            end
            local prot_a = rst[2*cmp+1-deg][2]; node_remove(wv,ka)
            if prot_a~=0 then
               local kt = new_kern(rw, -prot_a); insert_after(ch, nn, kt);
               setkern(ka, prot_a); insert_after(ch, kt, ka);
            else node_free(ka)
            end
         else
            node_remove(wv, nn); setnext(nn, nil); insert_after(ch, rs[1], nn)
         end

         set_attr(nn, attr_icflag, PROCESSED)
         if fn == 2*cmp-1 then
            write_aux(wv, get_attr(nn, attr_ruby), get_attr(nn, attr_ruby_post_jfmgk))
         end
      end
      for i = 1,#rs do
         local ri = rs[i]; ch = node_remove(ch, ri); node_free(ri)
      end
      -- cleanup
      if fn >= 2*cmp+1 then node_free(rw) end
      return ch;
   end
end

local traverse_id = node.direct.traverse_id
local post_high_hbox, post_high_break
do
   local rs, rw = {}, nil -- rs: sequence of ruby_nodes, rw: main whatsit
   local cmp
   post_high_break =  function (head)
      for h in traverse_id(id_hlist, to_direct(head)) do
         for i = 1, #rs do rs[i] = nil end
         local ha = getlist(h);
         while ha do
            local hai = getid(ha)
            local i = ((hai == id_glue and getsubtype(ha)==0)
                       or (hai == id_rule and getsubtype(ha)==0)
                       or (hai == id_whatsit and getsubtype(ha)==sid_user
                           and getfield(ha, 'user_id', RUBY_POST)))
                  and get_attr(ha, attr_ruby) or 0
            if i==0 then
               ha = node_next(ha)
            elseif i==1 then
               setlist(h, post_lown(rs, rw, cmp, getlist(h)))
               for i = 2, #rs do rs[i] = nil end -- rs[1] is set by the next statement
               rs[1], rw = ha, nil; ha = node_next(ha)
            elseif i==2 then
               rw = ha
               cmp = getvalue(getvalue(rw)).count
               local hb, hc =  node_remove(getlist(h), rw)
               setlist(h, hb); ha = hc
            else -- i>=3
               rs[#rs+1] = ha; ha = node_next(ha)
            end
         end
         setlist(h, post_lown(rs, rw, cmp, getlist(h)))
      end
      return head
   end
   post_high_hbox = function (ahead)
      for i = 1, #rs do rs[i] = nil end; rw = nil
      local ha = to_direct(ahead); local head = ha
      while ha do
         local hai = getid(ha)
         local i = ((hai == id_glue and getsubtype(ha)==0)
                    or (hai == id_rule and getsubtype(ha)==0)
                    or (hai == id_whatsit and getsubtype(ha)==sid_user
                        and getfield(ha, 'user_id', RUBY_POST)))
               and get_attr(ha, attr_ruby) or 0
         if i==0 then
            ha = node_next(ha)
         elseif i==1 then
            head = post_lown(rs, rw, cmp, head)
            for i = 2, #rs do rs[i] = nil end -- rs[1] is set by the next statement
            rs[1], rw = ha, nil; ha = node_next(ha)
         elseif i==2 then
            rw = ha
            cmp = getvalue(getvalue(rw)).count
            head, ha = node_remove(head, rw)
         else -- i >= 3
            rs[#rs+1] = ha; ha = node_next(ha)
         end
      end
      return to_node(post_lown(rs, rw, cmp, head))
   end
end
do
   -- pre_append_to_vlist_filter.lua: distributed with lua-ul
   local found = kpse.find_file('pre_append_to_vlist_filter.lua', 'lua')
   if not found then
      luatexbase.add_to_callback('post_linebreak_filter', post_high_break, 'ltj.ruby.post_break')
   else
      require 'pre_append_to_vlist_filter'
      luatexbase.add_to_callback('pre_append_to_vlist_filter', 
         function(head, loc) 
             return (loc~='post_linebreak') and head or post_high_break(head)
         end,
         'ltj.ruby.post_break',
         (luatexbase.priority_in_callback('pre_append_to_vlist_filter', 'add underlines to list') or 1))
   end
   luatexbase.add_to_callback('hpack_filter', 
     function(head) return post_high_hbox(pre_high(head)) end, 'ltj.ruby', 
     luatexbase.priority_in_callback('hpack_filter', 'add underlines to list') or nil)
end

----------------------------------------------------------------
-- for jfmglue callbacks
----------------------------------------------------------------
do
   local RIPRE  = luatexja.stack_table_index.RIPRE
   local RIPOST = luatexja.stack_table_index.RIPOST
   local abs = math.abs
   local function whatsit_callback(Np, lp, Nq)
      if Np.nuc then return Np
      elseif  getfield(lp, 'user_id') == RUBY_PRE then
         Np.first, Np.nuc, Np.last = lp, lp, lp
         local lpv = getvalue(lp)
         local rst = getvalue(lpv)
         local x = node_next(node_next(lpv))
         Np.last_char = luatexja.jfmglue.check_box_high(Np, getlist(x), nil)
         if Nq.id ~=id_pbox_w then
            if type(Nq.char)=='number' then
               -- Nq is a JAchar
               if rst.pre < 0 then -- auto
                  local s = ltjs.table_current_stack[RIPRE + Nq.char] or 0
                  local p = round(abs(s)*rst.rubyzw)
                  if rst.mode%2 == 0 then -- intrusion 無効
                     p = 0
                  end
                  rst.pre = -p; rst.exclude_pre_from_prev_ruby = (s<0);
                  rst.exclude_pre_jfmgk_from_prev_ruby = (ltjs.table_current_stack[RIPOST +Nq.char] or 0)<0;
               end
               if Nq.prev_ruby then
                  set_attr(lp, attr_ruby, Nq.prev_ruby)
               end
            elseif rst.pre < 0 then -- auto
               if Nq.char == 'parbdd' then
                  local s = ltjs.table_current_stack[RIPRE - 1] or 0
                  local p = round(abs(s)*rst.rubyzw)
                  p = min(p, Nq.width)
                  if rst.mode%2 == 0 then -- intrusion 無効
                     p = 0
                  end
                  rst.pre = p; rst.exclude_pre_from_prev_ruby = (s<0);
                  rst.exclude_pre_jfmgk_from_prev_ruby = (ltjs.table_current_stack[RIPOST -1] or 0)<0;
               else
                  rst.pre = 0
               end
            end
         elseif rst.pre < 0 then -- auto
            rst.pre = 0
         end
         if rst.quirk_protrusion then
            local lk = node_new(id_kern, 1, Nq.nuc, lp); set_attr(lk, attr_icflag, PROCESSED)
            insert_after(lpv, node_tail(lpv), lk)
            insert_after(lpv, node_tail(lpv), node_new(id_kern, 1))
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
   local FROM_JFM = luatexja.icflag_table.FROM_JFM
   local KANJI_SKIP = luatexja.icflag_table.KANJI_SKIP
   local function add_gk(t, index, p)
      local ic = get_attr_icflag(p)
      if ic and (ic>FROM_JFM) and (ic<KANJI_SKIP) then ic = FROM_JFM end
      if t.intrude_jfmgk[ic] then
          if getid(p)==id_kern then t[index] = t[index] + getkern(p)
          else t[index] = t[index] + getwidth(p) end
      end
   end
   local RIPOST = luatexja.stack_table_index.RIPOST
   local abs = math.abs
   local ltjj_after_hlist=luatexja.jfmglue.after_hlist
   local ltjj_check_box_high=luatexja.jfmglue.check_box_high
   local function whatsit_after_callback(s, Nq, Np, head)
      if not s and  getfield(Nq.nuc, 'user_id') == RUBY_PRE then
         if Np then
            local last_glue = node_new(id_glue, nil, Nq.nuc) -- INHERIT ATTRIBUTE OF Nq.nuc
            set_attr(last_glue, attr_icflag, 0)
            insert_before(Nq.nuc, Np.first, last_glue)
            Np.first = last_glue
            next_cluster_array[Nq.nuc] = last_glue -- ルビ処理用のグルー
         end
         local nqnv = getvalue(Nq.nuc)
         local rst = getvalue(nqnv)
         if Nq.gk then
            if type(Nq.gk)=="table" then
               for _,v in ipairs(Nq.gk) do add_gk(rst, 'before_jfmgk', v) end
            else add_gk(rst, 'before_jfmgk', Nq.gk) end
         end
         local x =  node_next(node_next(nqnv))
         for i = 2, rst.count do x = node_next(node_next(x)) end
         Nq.last_char = ltjj_check_box_high(Nq, getlist(x), nil)
         ltjj_after_hlist(Nq)
         if Np and Np.id ~=id_pbox_w and type(Np.char)=='number' then
            -- Np is a JAchar
            if rst.post < 0 then -- auto
               local p = round(abs(ltjs.table_current_stack[RIPOST + Np.char] or 0)*rst.rubyzw)
               if rst.mode%2 == 0 then -- intrusion 無効
                  p = 0
               end
               rst.post = p
            end
            Np.prev_ruby = get_attr(getvalue(Nq.nuc), attr_ruby_id)
            -- 前のクラスタがルビであったことのフラグ
         else -- 直前が文字以外
            if rst.post < 0 then -- auto
               rst.post = 0
            end
         end
         if rst.quirk_protrusion then
            local lk = node_tail(nqnv);
            node_inherit_attr(lk, Nq.nuc, Np and Np.nuc)
            set_attr(lk, attr_icflag, PROCESSED)
         end
         return head
      else
         return s
      end
   end
   luatexbase.add_to_callback("luatexja.jfmglue.whatsit_after", whatsit_after_callback,
                              "luatexja.ruby.np_info_after", 1)
   local function w (s, Nq, Np)
      if not s and  getfield(Nq.nuc, 'user_id') == RUBY_PRE then
         local rst = getvalue(getvalue(Nq.nuc))
         if Np.gk then
            if type(Np.gk)=="table" then
               for _,v in ipairs(Np.gk) do add_gk(rst, 'after_jfmgk', v) end
            else add_gk(rst, 'after_jfmgk', Np.gk) end
         end
      end
   end
   luatexbase.add_to_callback("luatexja.jfmglue.whatsit_last_minute", w,
                              "luatexja.ruby.np_info_last_minute", 1)
end
