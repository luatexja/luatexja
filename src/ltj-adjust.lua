--
-- luatexja/otf.lua
--
luatexbase.provides_module({
  name = 'luatexja.adjust',
  date = '2014/01/23',
  description = 'Advanced line adjustment for LuaTeX-ja',
})
module('luatexja.adjust', package.seeall)

luatexja.load_module('jfont');     local ltjf = luatexja.jfont
luatexja.load_module('jfmglue');   local ltjj = luatexja.jfmglue

local Dnode = node.direct or node

local nullfunc = function(n) return n end
local to_node = (Dnode ~= node) and Dnode.tonode or nullfunc
local to_direct = (Dnode ~= node) and Dnode.todirect or nullfunc

local setfield = (Dnode ~= node) and Dnode.setfield or function(n, i, c) n[i] = c end
local getfield = (Dnode ~= node) and Dnode.getfield or function(n, i) return n[i] end
local getlist = (Dnode ~= node) and Dnode.getlist or function(n) return n.head end
local getid = (Dnode ~= node) and Dnode.getid or function(n) return n.id end
local getfont = (Dnode ~= node) and Dnode.getfont or function(n) return n.font end
local getsubtype = (Dnode ~= node) and Dnode.getsubtype or function(n) return n.subtype end

local node_traverse_id = Dnode.traverse_id
local node_new = Dnode.new
local node_copy = Dnode.copy
local node_hpack = Dnode.hpack
local node_next = Dnode.getnext
local node_free = Dnode.free
local node_prev = Dnode.getprev
local node_tail = Dnode.tail
local has_attr = Dnode.has_attribute
local set_attr = Dnode.set_attribute
local insert_after = Dnode.insert_after

local id_glyph = node.id('glyph')
local id_kern = node.id('kern')
local id_hlist = node.id('hlist')
local id_glue  = node.id('glue')
local id_glue_spec = node.id('glue_spec')
local id_whatsit = node.id('whatsit')
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']

local ltjf_font_metric_table = ltjf.font_metric_table
local spec_zero_glue = ltjj.spec_zero_glue
local round = tex.round

local PACKED       = luatexja.icflag_table.PACKED
local FROM_JFM     = luatexja.icflag_table.FROM_JFM
local KANJI_SKIP   = luatexja.icflag_table.KANJI_SKIP
local XKANJI_SKIP  = luatexja.icflag_table.XKANJI_SKIP

local priority_table = {
   FROM_JFM + 2,
   FROM_JFM + 1,
   FROM_JFM,
   FROM_JFM - 1,
   FROM_JFM - 2,
   XKANJI_SKIP,
   KANJI_SKIP
}

local PROCESSED_BEGIN_FLAG = 32
local function get_attr_icflag(p)
   return (has_attr(p, attr_icflag) or 0) % PROCESSED_BEGIN_FLAG
end

-- box 内で伸縮された glue の合計値を計算

local function get_stretched(q, go, gs)
   local qs = getfield(q, 'spec')
   if not getfield(qs, 'writable') then return 0 end
   if gs == 1 then -- stretching
      if getfield(qs, 'stretch_order') == go then 
	 return getfield(qs, 'stretch') 
      end
   else -- shrinking
      if getfield(qs, 'shrink_order') == go then 
	 return getfield(qs, 'shrink')
      end
   end
end

local res = {}

-- local new_ks, new_xs
local function get_total_stretched(p)
   local go, gf, gs 
      = getfield(p, 'glue_order'), getfield(p, 'glue_set'), getfield(p, 'glue_sign')
   res[0], res.glue_set, res.name = 0, gf, (gs==1) and 'stretch' or 'shrink'
   for i=1,#priority_table do res[priority_table[i]]=0 end
   if go ~= 0 then return nil end
   if gs ~= 1 and gs ~= 2 then return res end
   for q in node_traverse_id(id_glue, getlist(p)) do
      local a, ic = get_stretched(q, go, gs), get_attr_icflag(q)
      if   type(res[ic]) == 'number' then 
	 -- kanjiskip, xkanjiskip は段落内で spec を共有しているが，
	 -- それはここでは望ましくないので，各 glue ごとに異なる spec を使う．
	 -- JFM グルーはそれぞれ異なる glue_spec を用いているので，問題ない．
	 res[ic] = res[ic] + a
	 if ic == KANJI_SKIP or ic == XKANJI_SKIP  then
	    local qs = getfield(q, 'spec')
	    if qs ~= spec_zero_glue then
	       setfield(q, 'spec', node_copy(qs))
	    end
	 end
      else 
	 res[0]  = res[0]  + a
      end
   end
   return res
end

local function clear_stretch(p, ic, name)
   for q in node_traverse_id(id_glue, getlist(p)) do
      if get_attr_icflag(q) == ic then
         local qs = getfield(q, 'spec')
         if getfield(qs, 'writable') then
            setfield(qs, name..'_order', 0)
            setfield(qs, name, 0)
         end
      end
   end
end

local set_stretch_table = {}
local function set_stretch(p, after, before, ic, name)
   if before > 0 then
      --print (ic, before, after)
      local ratio = after/before
      for i,_ in pairs(set_stretch_table) do
         set_stretch_table[i] = nil
      end
      for q in node_traverse_id(id_glue, getlist(p)) do
         if get_attr_icflag(q) == ic then
            local qs, do_flag = getfield(q, 'spec'), true
            for i=1,#set_stretch_table do 
               if set_stretch_table[i]==qs then do_flag = false end 
            end
            if getfield(qs, 'writable') and getfield(qs, name..'_order')==0 and do_flag then
               setfield(qs, name, getfield(qs, name)*ratio)
               set_stretch_table[#set_stretch_table+1] = qs
            end
         end
      end
   end
end

-- step 1: 行末に kern を挿入（句読点，中点用）
local function aw_step1(p, res, total)
   local head = getlist(p)
   local x = node_tail(head); if not x then return false end
   x = node_prev(x); if not x then return false end
   -- 本当の行末の node を格納
   if getid(x) == id_glue and getsubtype(x) == 15 then 
      -- 段落最終行のときは，\penalty10000 \parfillskip が入るので，
      -- その前の node が本来の末尾文字となる
      x = node_prev(node_prev(x)) 
   end
   local xi, xc = getid(x)
   if xi == id_glyph and has_attr(x, attr_curjfnt) == getfont(x) then
      -- 和文文字
      xc = x
   elseif xi == id_hlist and get_attr_icflag(x) == PACKED then
      -- packed JAchar
      xc = getlist(x)
      while getid(xc) == id_whatsit do xc = node_next(xc) end
   else
     return false-- それ以外は対象外．
   end
   local xk = ltjf_font_metric_table[getfont(xc)]
     xk = xk.char_type[has_attr(xc, attr_jchar_class) or 0]
     xk = xk['end_' .. res.name] or 0

   if xk>0 and total>=xk then
      total = total - xk
      local kn = node_new(id_kern)
      setfield(kn, 'kern', (res.name=='shrink' and -1 or 1) * xk)
      set_attr(kn, attr_icflag, FROM_JFM)
      insert_after(head, x, kn)
      return true
   else return false
   end
end

-- step 2: 行中の glue を変える
local function aw_step2(p, res, total, added_flag)
   if total == 0 then -- もともと伸縮の必要なし
      if added_flag then -- 行末に kern 追加したので，それによる補正
	 local f = node_hpack(getlist(p), getfield(p, 'width'), 'exactly')
	 setfield(f, 'head', nil)
	 setfield(p, 'glue_set', getfield(f, 'glue_set'))
	 setfield(p, 'glue_order', getfield(f, 'glue_order'))
	 setfield(p, 'glue_sign', getfield(f, 'glue_sign'))
	 node_free(f)
	 return
      end
   elseif total <= res[0] then -- 和文処理グルー以外で足りる
      for _,v in pairs(priority_table) do clear_stretch(p, v, res.name) end
      local f = node_hpack(getlist(p), getfield(p, 'width'), 'exactly')
      setfield(f, 'head', nil)
	 setfield(p, 'glue_set', getfield(f, 'glue_set'))
	 setfield(p, 'glue_order', getfield(f, 'glue_order'))
	 setfield(p, 'glue_sign', getfield(f, 'glue_sign'))
      node_free(f)
   else
      local orig_total, avail = total, res[0]
      total, i = total - res[0], 1
      while i <= #priority_table do
         local v = priority_table[i]
         if total <= res[v] then
            for j = i+1,#priority_table do
               clear_stretch(p, priority_table[j], res.name)
            end
            set_stretch(p, total, res[v], v, res.name)
	    avail = avail + total
            i = #priority_table + 9 -- ループから抜けさせたいため
         end
         total, i, avail = total - res[v], i+1, avail + res[v]
      end
      if i == #priority_table + 10 or added_flag then
	 local f = node_hpack(getlist(p), getfield(p, 'width'), 'exactly')
	 setfield(f, 'head', nil)
	 setfield(p, 'glue_set', getfield(f, 'glue_set'))
	 setfield(p, 'glue_order', getfield(f, 'glue_order'))
	 setfield(p, 'glue_sign', getfield(f, 'glue_sign'))
	 node_free(f)
      end
   end
end


function adjust_width(head) 
   if not head then return head end
   for p in node_traverse_id(id_hlist, to_direct(head)) do
      local res = get_total_stretched(p)
      if res then
         -- 調整量の合計
         local total = 0
         for i,v in pairs(res) do 
            if type(i)=='number' then
               total = total + v
            end
         end; total = round(total * res.glue_set)
         local added_flag = aw_step1(p, res, total)
         --print(total, res[0], res[KANJI_SKIP], res[FROM_JFM])
         aw_step2(p, res, total, added_flag)
      end
   end
   return to_node(head)
end

local is_reg = false
function enable_cb()
   if not is_reg then
      luatexbase.add_to_callback('post_linebreak_filter', adjust_width, 'Adjust width', 100)
      is_reg = true
   end
end
function disable_cb()
   if is_reg then
      luatexbase.remove_from_callback('post_linebreak_filter', 'Adjust width')
      is_reg = false
   end
end

luatexja.unary_pars.adjust = function(t)
   return is_reg and 1 or 0
end
