--
-- luatexja/otf.lua
--
luatexja.load_module('jfont');     local ltjf = luatexja.jfont
luatexja.load_module('jfmglue');   local ltjj = luatexja.jfmglue
luatexja.load_module('stack');     local ltjs = luatexja.stack
luatexja.load_module('direction'); local ltjd = luatexja.direction

local to_node = node.direct.tonode
local to_direct = node.direct.todirect

local setfield = node.direct.setfield
local setglue = luatexja.setglue
local getfield = node.direct.getfield
local is_zero_glue = node.direct.is_zero_glue or
   function(g)
      return (getfield(g,'width')==0)and (getfield(g,'stretch')==0)and(getfield(g,'shrink')==0)
   end
local getlist = node.direct.getlist
local getid = node.direct.getid
local getfont = node.direct.getfont
local getsubtype = node.direct.getsubtype

local node_traverse_id = node.direct.traverse_id
local node_new = node.direct.new
local node_copy = node.direct.copy
local node_hpack = node.direct.hpack
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
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local lang_ja = luatexja.lang_ja

local ltjf_font_metric_table = ltjf.font_metric_table
local round, pairs = tex.round, pairs

local PACKED       = luatexja.icflag_table.PACKED
local FROM_JFM     = luatexja.icflag_table.FROM_JFM
local KANJI_SKIP   = luatexja.icflag_table.KANJI_SKIP
local KANJI_SKIP_JFM = luatexja.icflag_table.KANJI_SKIP_JFM
local XKANJI_SKIP  = luatexja.icflag_table.XKANJI_SKIP
local XKANJI_SKIP_JFM  = luatexja.icflag_table.XKANJI_SKIP_JFM

local priority_table = {
   FROM_JFM + 2,
   FROM_JFM + 1,
   FROM_JFM,
   FROM_JFM - 1,
   FROM_JFM - 2,
   XKANJI_SKIP,
   KANJI_SKIP
}

local get_attr_icflag
do
   local PROCESSED_BEGIN_FLAG = luatexja.icflag_table.PROCESSED_BEGIN_FLAG
   get_attr_icflag = function(p)
      return (has_attr(p, attr_icflag) or 0) % PROCESSED_BEGIN_FLAG
   end
end

-- box 内で伸縮された glue の合計値を計算

local function get_stretched(q, go, gs)
   if gs == 1 then -- stretching
      if getfield(q, 'stretch_order') == go then
	 return getfield(q, 'stretch')
      else return 0
      end
   else -- shrinking
      if getfield(q, 'shrink_order') == go then
	 return getfield(q, 'shrink')
      else return 0
      end
   end
end

local res = {}
local gs_used_line = {}
local function get_total_stretched(p, line)
   local go, gf, gs
      = getfield(p, 'glue_order'), getfield(p, 'glue_set'), getfield(p, 'glue_sign')
   if go ~= 0 then return nil end
   res[0], res.glue_set, res.name = 0, gf, (gs==1) and 'stretch' or 'shrink'
   for i=1,#priority_table do res[priority_table[i]]=0 end
   if gs ~= 1 and gs ~= 2 then return res, 0 end
   local total = 0
   for q in node_traverse_id(id_glue, getlist(p)) do
      local a, ic = get_stretched(q, go, gs), get_attr_icflag(q)
      if ic == KANJI_SKIP_JFM  then ic = KANJI_SKIP
      elseif ic == XKANJI_SKIP_JFM  then ic = XKANJI_SKIP
      end
      if   type(res[ic]) == 'number' then
	 -- kanjiskip, xkanjiskip は段落内で spec を共有しているが，
	 -- それはここでは望ましくないので，各 glue ごとに異なる spec を使う．
	 -- 本当は各行ごとに glue_spec を共有させたかったが，安直にやると
	 -- ref_count が 0 なので Double-free が発生する．どうする？
	 -- JFM グルーはそれぞれ異なる glue_spec を用いているので，問題ない．
	 if (ic == KANJI_SKIP or ic == XKANJI_SKIP) and getsubtype(q)==0 then
	    local qs = getfield(q, 'spec')
	    if is_zero_glue(q) then
	       if (gs_used_line[qs] or 0)<line  then
		  setfield(q, 'spec', node_copy(qs))
		  local f = node_new(id_glue); setfield(f, 'spec', qs); node_free(f)
		  -- decrese qs's reference count
	       else
		  gs_used_line[qs] = line
	       end
	    end
	 end
	 res[ic], total = res[ic] + a, total + a
      else
	 res[0], total = res[0]  + a, total + a
      end
   end
   return res, total
end

local function clear_stretch(p, ic, name)
   for q in node_traverse_id(id_glue, getlist(p)) do
      local f = get_attr_icflag(q)
      if (f == ic) or ((ic ==KANJI_SKIP) and (f == KANJI_SKIP_JFM))
	   or ((ic ==XKANJI_SKIP) and (f == XKANJI_SKIP_JFM)) then
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
      local ratio = after/before
      for i,_ in pairs(set_stretch_table) do
         set_stretch_table[i] = nil
      end
      for q in node_traverse_id(id_glue, getlist(p)) do
	 local f = get_attr_icflag(q)
         if (f == ic) or ((ic ==KANJI_SKIP) and (f == KANJI_SKIP_JFM))
	   or ((ic ==XKANJI_SKIP) and (f == XKANJI_SKIP_JFM)) then
            local qs, do_flag = getfield(q, 'spec'), true
            for i=1,#set_stretch_table do
               if set_stretch_table[i]==qs then do_flag = false end
            end
            if getfield(qs, 'writable') and getfield(qs, name..'_order')==0 and do_flag then
               setfield(q, name, getfield(qs, name)*ratio)
               set_stretch_table[#set_stretch_table+1] = qs
            end
         end
      end
   end
end

-- step 1: 行末に kern を挿入（句読点，中点用）
local ltjd_glyph_from_packed = ltjd.glyph_from_packed
local function aw_step1(p, res, total)
   local head = getlist(p)
   local x = node_tail(head); if not x then return false end
   -- x: \rightskip
   x = node_prev(x); if not x then return false end
   local xi, xc = getid(x)
   if xi == id_glue and getsubtype(x) == 15 then
      -- 段落最終行のときは，\penalty10000 \parfillskip が入るので，
      -- その前の node が本来の末尾文字となる
      x = node_prev(node_prev(x)); xi = getid(x)
   end
   -- local xi = getid(x)
   -- while (get_attr_icflag(x) == PACKED)
   --    and  ((xi == id_penalty) or (xi == id_kern) or (xi == id_kern)) do
   --       x = node_prev(x); xi = getid(x)
   -- end
   if xi == id_glyph and getfield(x, 'lang')==lang_ja then
      -- 和文文字
      xc = x
   elseif xi == id_hlist and get_attr_icflag(x) == PACKED then
      -- packed JAchar
      xc = ltjd_glyph_from_packed(x)
      while getid(xc) == id_whatsit do xc = node_next(xc) end -- これはなんのために？
   else
     return false-- それ以外は対象外．
   end
   local xk = ltjf_font_metric_table[getfont(xc)]
     .char_type[has_attr(xc, attr_jchar_class) or 0]['end_' .. res.name] or 0

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
      total = total - res[0]
      for i = 1, #priority_table do
         local v = priority_table[i]
         if total <= res[v] then
            for j = i+1,#priority_table do
               clear_stretch(p, priority_table[j], res.name)
            end
            set_stretch(p, total, res[v], v, res.name); break
         end
         total = total - res[v]
      end
      local f = node_hpack(getlist(p), getfield(p, 'width'), 'exactly')
      setfield(f, 'head', nil)
      setfield(p, 'glue_set', getfield(f, 'glue_set'))
      setfield(p, 'glue_order', getfield(f, 'glue_order'))
      setfield(p, 'glue_sign', getfield(f, 'glue_sign'))
      node_free(f)
   end
end


local ltjs_fast_get_stack_skip = ltjs.fast_get_stack_skip
local function adjust_width(head)
   if not head then return head end
   local line = 1
   for p in node_traverse_id(id_hlist, to_direct(head)) do
      line = line + 1
      local res, total = get_total_stretched(p, line)
        -- this is the same table as the table which is def'd in l. 92
      if res and res.glue_set<1 then
	 total = round(total * res.glue_set)
         aw_step2(p, res, total, aw_step1(p, res, total))
      end
   end
   for i,_ in pairs(gs_used_line) do
      gs_used_line[i]  = nil
   end
   return to_node(head)
end

do
   luatexja.adjust = luatexja.adjust or {}
   local is_reg = false
   function luatexja.adjust.enable_cb()
      if not is_reg then
	 luatexbase.add_to_callback('post_linebreak_filter',
				    adjust_width, 'Adjust width', 100)
	 is_reg = true
      end
   end
   function luatexja.adjust.disable_cb()
      if is_reg then
	 luatexbase.remove_from_callback('post_linebreak_filter', 'Adjust width')
	 is_reg = false
      end
   end
end

luatexja.unary_pars.adjust = function(t)
   return is_reg and 1 or 0
end
