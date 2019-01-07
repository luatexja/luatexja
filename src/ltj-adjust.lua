--
-- ltj-adjust.lua
--
luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('jfont');     local ltjf = luatexja.jfont
luatexja.load_module('jfmglue');   local ltjj = luatexja.jfmglue
luatexja.load_module('stack');     local ltjs = luatexja.stack
luatexja.load_module('direction'); local ltjd = luatexja.direction
luatexja.load_module('lineskip');  local ltjl = luatexja.lineskip
luatexja.adjust = luatexja.adjust or {}

local to_node = node.direct.tonode
local to_direct = node.direct.todirect

local setfield = node.direct.setfield
local setglue = luatexja.setglue
local getfield = node.direct.getfield
local getlist = node.direct.getlist
local getid = node.direct.getid
local getfont = node.direct.getfont
local getsubtype = node.direct.getsubtype

local node_traverse_id = node.direct.traverse_id
local node_new = node.direct.new
local node_next = node.direct.getnext
local node_free = node.direct.free
local node_prev = node.direct.getprev
local node_tail = node.direct.tail
local has_attr = node.direct.has_attribute
local set_attr = node.direct.set_attribute
local insert_after = node.direct.insert_after

local id_glyph = node.id('glyph')
local id_kern = node.id('kern')
local id_hlist = node.id('hlist')
local id_glue  = node.id('glue')
local id_whatsit = node.id('whatsit')
local id_penalty = node.id('penalty')
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local lang_ja = luatexja.lang_ja

local ltjf_font_metric_table = ltjf.font_metric_table
local ipairs, pairs = ipairs, pairs

local PACKED       = luatexja.icflag_table.PACKED
local LINEEND      = luatexja.icflag_table.LINEEND
local FROM_JFM     = luatexja.icflag_table.FROM_JFM
local KANJI_SKIP   = luatexja.icflag_table.KANJI_SKIP
local KANJI_SKIP_JFM = luatexja.icflag_table.KANJI_SKIP_JFM
local XKANJI_SKIP  = luatexja.icflag_table.XKANJI_SKIP
local XKANJI_SKIP_JFM  = luatexja.icflag_table.XKANJI_SKIP_JFM

local get_attr_icflag
do
   local PROCESSED_BEGIN_FLAG = luatexja.icflag_table.PROCESSED_BEGIN_FLAG
   get_attr_icflag = function(p)
      return (has_attr(p, attr_icflag) or 0) % PROCESSED_BEGIN_FLAG
   end
end

local priority_num = { 0, 0 }
local at2pr = { {}, {} }
local at2pr_st, at2pr_sh = at2pr[1], at2pr[2]
do
   local priority_table = {{},{}}
   luatexja.adjust.priority_table = priority_table
   local tmp = {}
   local function cmp(a,b) return a[1]>b[1] end -- 大きいほうが先！
   local function make_priority_table(glue_sign)
      for i,_ in pairs(tmp) do tmp[i]=nil end
      if glue_sign==2 then -- shrink
	 for i=0,63 do tmp[#tmp+1] = { (i%8)-4, FROM_JFM+i } end
      else -- stretch
	 for i=0,63 do tmp[#tmp+1] = { math.floor(i/8)-4, FROM_JFM+i } end
      end    
      local pt = priority_table[glue_sign]
      tmp[#tmp+1] = { pt[2]/10, XKANJI_SKIP }
      tmp[#tmp+1] = { pt[2]/10, XKANJI_SKIP_JFM }
      tmp[#tmp+1] = { pt[1]/10, KANJI_SKIP }
      tmp[#tmp+1] = { pt[1]/10, KANJI_SKIP_JFM }
      tmp[#tmp+1] = { pt[3]/10, -1 }
      table.sort(tmp, cmp)
      local a, m, n = at2pr[glue_sign], 10000000, 0
      for i=1,#tmp do
	 if tmp[i][1]<m then n,m = n+1,tmp[i][1] end
	 a[tmp[i][2]] = n
      end
      local o = a[-1]
      priority_num[glue_sign] = n
      setmetatable(a, {__index = function () return o end })
   end
   luatexja.adjust.make_priority_table = make_priority_table
end

-- box 内で伸縮された glue の合計値を計算

local total_stsh = {{},{}}
local total_st, total_sh = total_stsh[1], total_stsh[2]
local get_total_stretched
do
local dimensions = node.direct.dimensions
function get_total_stretched(p)
-- return value: <補正値(sp)>
   local ph = getlist(p)
   if not ph then return 0 end
   for i,_ in pairs(total_st) do total_st[i]=nil; total_sh[i]=nil end
   for i=1,priority_num[1] do total_st[i]=0 end
   for i=1,priority_num[2] do total_sh[i]=0 end
   for i=0,4 do total_st[i*65536]=0; total_sh[i*65536]=0 end
   for q in node_traverse_id(id_glue, ph) do
      local a = getfield(q, 'stretch_order')
      if a==0 then
	 local b = at2pr_st[get_attr_icflag(q)]; 
	 total_st[b] = total_st[b]+getfield(q, 'stretch')
      end
      total_st[a*65536] = total_st[a]+getfield(q, 'stretch')
      local a = getfield(q, 'shrink_order')
      if a==0 then
	 local b = at2pr_sh[get_attr_icflag(q)]; 
	 total_sh[b] = total_sh[b]+getfield(q, 'shrink')
      end
      total_sh[a*65536] = total_sh[a]+getfield(q, 'shrink')
   end
   for i=4,1,-1 do if total_st[i*65536]~=0 then total_st.order=i; break end; end
   if not total_st.order then
       total_st.order, total_st[-65536] = -1,0.1 -- dummy
   end
   for i=4,1,-1 do if total_sh[i*65536]~=0 then total_sh.order=i; break end; end
   if not total_sh.order then
       total_sh.order, total_sh[-65536] = -1,0.1 -- dummy
   end
   return getfield(p,'width') - dimensions(ph)
end
end

-- step 1: 行末に kern を挿入（句読点，中点用）
local abs = math.abs
local ltjd_glyph_from_packed = ltjd.glyph_from_packed
local function aw_step1(p, total)
   local head = getlist(p)
   local x = node_tail(head); if not x then return total, false end
   -- x: \rightskip
   x = node_prev(x); if not x then return total, false end
   local xi, xc = getid(x)
   -- x may be penalty
   while xi==id_penalty do
      x = node_prev(x); if not x then return total, false end
      xi = getid(x)
   end
   if (total>0 and total_st.order>0) or (total<0 and total_sh.order>0) then
       -- 無限大のグルーで処理が行われているときは処理中止．
       return total, false
   end
   if xi == id_glyph and getfield(x, 'lang')==lang_ja then
      -- 和文文字
      xc = x
   elseif xi == id_hlist and get_attr_icflag(x) == PACKED then
      -- packed JAchar
      xc = ltjd_glyph_from_packed(x)
      while getid(xc) == id_whatsit do xc = node_next(xc) end -- これはなんのために？
   else
      return total, false-- それ以外は対象外．
   end
   local eadt = ltjf_font_metric_table[getfont(xc)]
      .char_type[has_attr(xc, attr_jchar_class) or 0].end_adjust
   if not eadt then 
      return total, false
   end
   local eadt_ratio = {}
   for i, v in ipairs(eadt) do
      local t = total - v
      if t>0 then
	 eadt_ratio[i] = {i, t/total_st[65536*total_st.order], t, v}
      else
	 eadt_ratio[i] = {i, t/total_sh[65536*total_sh.order], t, v}
      end
   end
   table.sort(eadt_ratio, 
   function (a,b) 
       for i=2,4 do
	   local at, bt = abs(a[i]), abs(b[i])
	   if at~=bt then return at<bt end
       end
       return a[4]<b[4]
   end)
   if eadt[eadt_ratio[1][1]]~=0 then
      local kn = node_new(id_kern, 1)
      setfield(kn, 'kern', eadt[eadt_ratio[1][1]]); set_attr(kn, attr_icflag, LINEEND)
      insert_after(head, x, kn)
      return eadt_ratio[1][3], true
   else
      return total, false
   end
end

-- step 1 最終行用
local min, max = math.min, math.max
local function aw_step1_last(p, total)
   local head = getlist(p)
   local x = node_tail(head); if not x then return total, false end
   -- x: \rightskip
   pf = node_prev(x); if not x then return total, false end
   if getid(pf) ~= id_glue or getsubtype(pf) ~= 15 then return total, false end
   x = node_prev(node_prev(pf)); xi = getid(x)
   local xi, xc = getid(x)
   if xi == id_glyph and getfield(x, 'lang')==lang_ja then
      -- 和文文字
      xc = x
   elseif xi == id_hlist and get_attr_icflag(x) == PACKED then
      -- packed JAchar
      xc = ltjd_glyph_from_packed(x)
      while getid(xc) == id_whatsit do xc = node_next(xc) end -- これはなんのために？
   else
      return total, false-- それ以外は対象外．
   end
   -- 続行条件1：無限の伸縮度を持つグルーは \parfillskipのみ
   if total>0 and total_st.order>0 then
      if total_st.order ~= getfield(pf, 'stretch_order') then return total, false end
      if total_st[total_st.order*65536] ~= getfield(pf, 'stretch') then return total, false end
      for i=total_st.order-1, 1, -1 do
	 if total_st[i*65536] ~= 0 then return total, false end
      end
   end
   if total<0 and total_sh.order>0 then
      if total_sh.order ~= getfield(pf, 'shrink_order') then return total, false end
      if total_sh[total_sh.order*65536] ~= getfield(pf, 'shrink') then return total, false end
      for i=total_sh.order-1, 1, -1 do
	 if total_sh[i*65536] ~= 0 then return total, false end
      end
   end
   local eadt = ltjf_font_metric_table[getfont(xc)]
      .char_type[has_attr(xc, attr_jchar_class) or 0].end_adjust
   if not eadt then 
      return total, false
   end
   -- 続行条件2: min(eadt[1], 0)<= \parfillskip <= max(eadt[#eadt], 0)
   local pfw = getfield(pf, 'width') 
     + (total>0 and getfield(pf, 'stretch') or -getfield(pf, 'shrink')) *getfield(p, 'glue_set') 
   if pfw<min(0,eadt[1]) or max(0,eadt[#eadt])<pfw then return total, false end
   -- \parfillskip を 0 にする
   total = total + getfield(pf, 'width') 
   total_st.order, total_sh.order = 0, 0
   if getfield(pf, 'stretch_order')==0 then 
      local i = at2pr_st[-1] 
      total_st[0] = total_st[0] - getfield(pf, 'stretch') 
      total_st[i] = total_st[i] - getfield(pf, 'stretch') 
      total_st.order = (total_st[0]==0) and -1 or 0
   end
   if getfield(pf, 'shrink_order')==0 then 
      local i = at2pr_sh[-1] 
      total_sh[0] = total_sh[0] - getfield(pf, 'shrink') 
      total_sh[i] = total_sh[i] - getfield(pf, 'shrink') 
      total_sh.order = (total_sh[0]==0) and -1 or 0
   end
   setfield(pf, 'subtype', 1); setglue(pf)
   local eadt_ratio = {}
   for i, v in ipairs(eadt) do
      local t = total - v
      if t>0 then
	 eadt_ratio[i] = {i, t/total_st[65536*total_st.order], t, v}
      else
	 eadt_ratio[i] = {i, t/total_sh[65536*total_sh.order], t, v}
      end
   end
   table.sort(eadt_ratio, 
   function (a,b) 
       for i=2,4 do
	   local at, bt = abs(a[i]), abs(b[i])
	   if at~=bt then return at<bt end
       end
       return a[4]<b[4]
   end)
   if eadt[eadt_ratio[1][1]]~=0 then
      local kn = node_new(id_kern, 1)
      setfield(kn, 'kern', eadt[eadt_ratio[1][1]]); set_attr(kn, attr_icflag, LINEEND)
      insert_after(head, x, kn)
      return eadt_ratio[1][3], true
   else
      return total, false
   end
end


-- step 2: 行中の glue を変える
local aw_step2, aw_step2_dummy
do
local node_hpack = node.direct.hpack
local function repack(p)
   local f = node_hpack(getlist(p), getfield(p, 'width'), 'exactly')
   setfield(f, 'head', nil)
   setfield(p, 'glue_set', getfield(f, 'glue_set'))
   setfield(p, 'glue_order', getfield(f, 'glue_order'))
   setfield(p, 'glue_sign', getfield(f, 'glue_sign'))
   node_free(f)
   return
end
function aw_step2_dummy(p, _, added_flag)
   if added_flag then return repack(p) end
end

local function clear_stretch(p, ind, ap, name)
   for q in node_traverse_id(id_glue, getlist(p)) do
      local f = ap[get_attr_icflag(q)]
      if f == ind then
         setfield(q, name..'_order', 0)
         setfield(q, name, 0)
      end
   end
end

local function set_stretch(p, after, before, ind, ap, name)
   if before > 0 then
      local ratio = after/before
      for q in node_traverse_id(id_glue, getlist(p)) do
	 local f = ap[get_attr_icflag(q)]
         if (f==ind) and getfield(q, name..'_order')==0 then
            setfield(q, name, getfield(q, name)*ratio)
         end
      end
   end
end

function aw_step2(p, total, added_flag)
   local name = (total>0) and 'stretch' or 'shrink'
   local id =  (total>0) and 1 or 2
   local res = total_stsh[id]
   local pnum = priority_num[id]
   if total==0 or res.order > 0 then 
      -- もともと伸縮の必要なしか，残りの伸縮量は無限大
      if added_flag then return repack(p) end
   end
   total = abs(total)
   for i = 1, pnum do
      if total <= res[i] then
	 local a = at2pr[id]  
         for j = i+1,pnum do
            clear_stretch(p, j, a, name)
         end
         set_stretch(p, total, res[i], i, a, name); break
      end
      total = total - res[i]
   end
   return repack(p)
end
end

-- step 1': lineend=extended の場合（行分割時に考慮））
local insert_lineend_kern
do
   local insert_before = node.direct.insert_before
   local KINSOKU      = luatexja.icflag_table.KINSOKU
   function insert_lineend_kern(head, nq, np, Bp)
      if nq.met then 
         local eadt = nq.met.char_type[nq.class].end_adjust
	 if not eadt then return end
	 if eadt[1]~=0 then
	    local x = node_new(id_kern, 1)
	    setfield(x, 'kern', eadt[1]); set_attr(x, attr_icflag, LINEEND)
	    insert_before(head, np.first, x)
	 end
	 local eadt_num = #eadt
	 for i=2,eadt_num do
	    local x = node_new(id_penalty)
	    setfield(x, 'penalty', 0); set_attr(x, attr_icflag, KINSOKU)
	    insert_before(head, np.first, x); Bp[#Bp+1] = x
	    local x = node_new(id_kern, 1)
	    setfield(x, 'kern', eadt[i]-eadt[i-1]); set_attr(x, attr_icflag, LINEEND)
	    insert_before(head, np.first, x)
	 end
         if eadt_num>1 or eadt[1]~=0 then
	    local x = node_new(id_penalty)
	    setfield(x, 'penalty', 0); set_attr(x, attr_icflag, KINSOKU)
	    insert_before(head, np.first, x); Bp[#Bp+1] = x
	    local x = node_new(id_kern, 1)
	    setfield(x, 'kern', -eadt[eadt_num]); set_attr(x, attr_icflag, LINEEND)
	    insert_before(head, np.first, x)
	    local x = node_new(id_penalty)
	    setfield(x, 'penalty', 10000); set_attr(x, attr_icflag, KINSOKU)
	    insert_before(head, np.first, x); Bp[#Bp+1] = x
	 end
      end
   end
end

local adjust_width
do
   local myaw_atep1, myaw_step2, myaw_step1_last
   local dummy =  function(p,t,n) return t, false end
   local ltjs_fast_get_stack_skip = ltjs.fast_get_stack_skip
   function adjust_width(head)
      if not head then return head end
      local last_p
      for p in node_traverse_id(id_hlist, to_direct(head)) do
	 if last_p then
	    myaw_step2(last_p, myaw_step1(last_p, get_total_stretched(last_p)))
	 end
         last_p = p
      end
      if last_p then
         myaw_step2(last_p, myaw_step1_last(last_p, get_total_stretched(last_p)))
      end
      return to_node(head)
   end
   local is_reg = false
   function enable_cb(status_le, status_pr, status_lp, status_ls)
      if (status_le>0 or status_pr>0) and (not is_reg) then
	 ltjb.add_to_callback('post_linebreak_filter',
            adjust_width, 'Adjust width', 
	    luatexbase.priority_in_callback('post_linebreak_filter', 'ltj.lineskip')-1)
	 is_reg = true
      elseif is_reg and (status_le==0 and status_pr==0) then
	 luatexbase.remove_from_callback('post_linebreak_filter', 'Adjust width')
	 is_reg = false
      end
      if status_le==2 then
	 if not luatexbase.in_callback('luatexja.adjust_jfmglue', 'luatexja.adjust') then
	    ltjb.add_to_callback('luatexja.adjust_jfmglue', insert_lineend_kern, 'luatexja.adjust')
	 end
         myaw_step1, myaw_step1_last = dummy, aw_step1_last
      else
         if status_le==0 then
            myaw_step1, myaw_step1_last = dummy, dummy
         else
            myaw_step1, myaw_step1_last = aw_step1, aw_step1_last
         end
         if luatexbase.in_callback('luatexja.adjust_jfmglue', 'luatexja.adjust') then
   	    luatexbase.remove_from_callback('luatexja.adjust_jfmglue', 'luatexja.adjust')
         end
      end
      myaw_step2 = (status_pr>0) and aw_step2 or aw_step2_dummy
      luatexja.lineskip.setting(
         status_lp>0 and 'profile' or 'dummy',
	 status_ls>0 and 'step' or 'dummy'
      )      
   end
   function disable_cb() -- only for compatibility
       enable_cs(0,0,0,0)
   end
   luatexja.adjust.enable_cb=enable_cb
   luatexja.adjust.disable_cb=disable_cb
end

luatexja.unary_pars.adjust = function(t)
   return is_reg and 1 or 0
end

-- ----------------------------------
do
  local max, ins, sort = math.max, table.insert, table.sort
  local function insert(package, ind, d, b, e)
    local bound = package[2]
    bound[b], bound[e]=true, true
    ins(package[1], {b,e,[ind]=d})
  end
  local function flatten(package)
    local bd={} for i,_ in pairs(package[2]) do ins(bd,{i}) end
    sort(bd, function (a,b) return a[1]<b[1] end)
    local bdc=#bd; local t = package[1]
    sort(t, function (a,b) return a[1]<b[1] end)
    local bdi =1
    for i=1,#t do
      while bd[bdi][1]<t[i][1] do bdi=bdi+1 end
      local j = bdi
      while j<bdc and bd[j+1][1]<=t[i][2] do
        for k,w in pairs(t[i]) do
          if k>=3 then
            bd[j][k]=bd[j][k] and max(bd[j][k],w) or w
          end
        end
        j=j+1
      end
    end
    package[2]=nil; package[1]=nil; package.flatten, package.insert=nil, nil
    bd[#bd]=nil
    return bd
  end
  function init_range()
    return {{},{}, insert=insert, flatten=flatten}
  end
end

-- -----------------------------------
luatexja.adjust.step_factor = 0.5
luatexja.unary_pars.linestep_factor = function(t)
   return luatexja.adjust.step_factor
end
luatexja.adjust.profile_hgap_factor = 1
luatexja.unary_pars.profile_hgap_factor = function(t)
   return luatexja.adjust.profile_hgap_factor
end
do
  local insert = table.insert
  local rangedimensions, max = node.direct.rangedimensions, math.max
  local function profile_inner(box, range, ind, vmirrored, adj)
    local w_acc, d_before = getfield(box,'shift'), 0
    local x = getlist(box); local xn = node_next(x)
    while x do
      local w, h, d
      if xn then w, h, d= rangedimensions(box,x,xn)
      else w, h, d= rangedimensions(box,x) end
      if vmirrored then h=d end
      local w_new = w_acc + w
      if w>=0 then
        range:insert(ind, h, w_acc-adj, w_new)
      else
        range:insert(ind, h, w_new-adj, w_acc)
      end
      w_acc = w_new; x = xn; if x then xn = node_next(x) end
    end
  end  
  function ltjl.p_profile(before, after, mirrored, bw)
    local range, tls 
      = init_range(), luatexja.adjust.profile_hgap_factor*tex.lineskip.width
    profile_inner(before, range, 3, true,     tls)
    profile_inner(after,  range, 4, mirrored, tls)
    range = range:flatten()
    do
      local dmax, d, hmax, h, lmin = 0, 0, 0, 0, 1/0
      for i,v in ipairs(range) do
        d, h = (v[3] or 0), (v[4] or 0)
        if d>dmax then dmax=d end
        if h>hmax then hmax=h end
        if bw-h-d<lmin then lmin=bw-h-d end
      end
      if lmin==1/0 then lmin = bw end
      return lmin, 
         bw - lmin - getfield(before, 'depth')
             - getfield(after, mirrored and 'depth' or 'height')
    end
  end
end

do
  local ltja = luatexja.adjust
  local copy_glue = ltjl.copy_glue
  local floor, max = math.floor, math.max
  function ltjl.l_step(dist, g, adj, normal, bw, loc)
    if loc=='alignment' then
      return ltjl.l_dummy(dist, g, adj, normal, bw, loc)
    end
    if dist < tex.lineskiplimit then
    local f = max(1, bw*ltja.step_factor)
       copy_glue(g, tex.baselineskip, 1, normal - f * floor((dist-tex.lineskip.width)/f))
    else
       copy_glue(g, tex.baselineskip, 2, normal)
    end
  end
end


