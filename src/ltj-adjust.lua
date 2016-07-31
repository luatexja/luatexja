--
-- ltj-adjust.lua
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
local is_zero_glue = node.direct.is_zero_glue
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

local total_stsh = {{},{}}
local total_st, total_sh = total_stsh[1], total_stsh[2]
local function get_total_stretched(p, line)
-- return value: <補正値(sp)>
   local go, gf, gs
     = getfield(p, 'glue_order'), getfield(p, 'glue_set'), getfield(p, 'glue_sign')
   for i,_ in pairs(total_st) do total_st[i]=nil; total_sh[i]=nil end
   for i=1,#priority_table do 
      total_st[priority_table[i]]=0; total_sh[priority_table[i]]=0; 
   end
   for i=0,4 do total_st[i*65536]=0; total_sh[i*65536]=0 end
   total_st[-1]=0; total_sh[-1]=0;
   for q in node_traverse_id(id_glue, getlist(p)) do
       local a = getfield(q, 'stretch_order')
      if a>0 then a=a*65536 else 
         total_st[0] = total_st[0]+getfield(q, 'stretch')
         a = get_attr_icflag(q)
         if a == KANJI_SKIP_JFM  then a = KANJI_SKIP
	 elseif a == XKANJI_SKIP_JFM  then a = XKANJI_SKIP
	 elseif type(total_st[a])~='number' then a = -1 end
      end
      total_st[a] = total_st[a]+getfield(q, 'stretch')
      local a = getfield(q, 'shrink_order')
      if a>0 then a=a*65536 else 
         total_sh[0] = total_sh[0]+getfield(q, 'shrink')
         a = get_attr_icflag(q)
         if a == KANJI_SKIP_JFM  then a = KANJI_SKIP
         elseif a == XKANJI_SKIP_JFM  then a = XKANJI_SKIP
	 elseif type(total_sh[a])~='number' then a = -1 end
      end
      total_sh[a] = total_sh[a]+getfield(q, 'shrink')
   end
   for i=4,0,-1 do if total_st[i*65536]~=0 then total_st.order=i; break end; end
   for i=4,0,-1 do if total_sh[i*65536]~=0 then total_sh.order=i; break end; end
   if gs==0 then
      return 0, gf
   else 
      return round((3-2*gs)*total_stsh[gs][go*65536]*gf), gf
   end
end

local function clear_stretch(p, ic, name)
   for q in node_traverse_id(id_glue, getlist(p)) do
      local f = get_attr_icflag(q)
      if (f == ic) or ((ic ==KANJI_SKIP) and (f == KANJI_SKIP_JFM))
	   or ((ic ==XKANJI_SKIP) and (f == XKANJI_SKIP_JFM)) then
         setfield(q, name..'_order', 0)
         setfield(q, name, 0)
      end
   end
end

local function set_stretch(p, after, before, ic, name)
   if before > 0 then
      local ratio = after/before
      for q in node_traverse_id(id_glue, getlist(p)) do
	 local f = get_attr_icflag(q)
         if (f == ic) or ((ic ==KANJI_SKIP) and (f == KANJI_SKIP_JFM))
	   or ((ic ==XKANJI_SKIP) and (f == XKANJI_SKIP_JFM)) then
            if getfield(q, name..'_order')==0 then
               setfield(q, name, getfield(q, name)*ratio)
            end
         end
      end
   end
end

-- step 1: 行末に kern を挿入（句読点，中点用）
local abs = math.abs
local ltjd_glyph_from_packed = ltjd.glyph_from_packed
local function aw_step1(p, total, ntr)
   local head = getlist(p)
   local x = node_tail(head); if not x then return total, false end
   -- x: \rightskip
   x = node_prev(x); if not x then return total, false end
   local xi, xc = getid(x)
   if xi == id_glue and getsubtype(x) == 15 then
      -- 段落最終行のときは，\penalty10000 \parfillskip が入るので，
      -- その前の node が本来の末尾文字となる
      x = node_prev(node_prev(x)); xi = getid(x)
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
	 eadt_ratio[i] = {i, t/total_st[65536*total_st.order], t}
      else
	 eadt_ratio[i] = {i, t/total_sh[65536*total_sh.order], t}
      end
   end
   table.sort(eadt_ratio, function (a,b) return abs(a[2])<abs(b[2]) end)
   --print('min', eadt[eadt_ratio[1][1]], eadt_ratio[1][3])
   if eadt[eadt_ratio[1][1]]~=0 then
      local kn = node_new(id_kern)
      setfield(kn, 'kern', eadt[eadt_ratio[1][1]]); set_attr(kn, attr_icflag, FROM_JFM)
      insert_after(head, x, kn)
      return eadt_ratio[1][3], true
   else
      return total, false
   end
end

-- step 2: 行中の glue を変える
local function aw_step2(p, total, added_flag)
   local name = (total>0) and 'stretch' or 'shrink'
   local res = total_stsh[(total>0) and 1 or 2]
   if total==0 or res.order > 0 then 
      -- もともと伸縮の必要なしか，残りの伸縮量は無限大
      if added_flag then -- 行末に kern 追加したので，それによる補正
	 local f = node_hpack(getlist(p), getfield(p, 'width'), 'exactly')
	 setfield(f, 'head', nil)
	 setfield(p, 'glue_set', getfield(f, 'glue_set'))
	 setfield(p, 'glue_order', getfield(f, 'glue_order'))
	 setfield(p, 'glue_sign', getfield(f, 'glue_sign'))
	 node_free(f)
	 return
      end
   end
   total = math.abs(total)
   if total <= res[-1] then -- 和文処理グルー以外で足りる
      for _,v in pairs(priority_table) do clear_stretch(p, v, name) end
      local f = node_hpack(getlist(p), getfield(p, 'width'), 'exactly')
      setfield(f, 'head', nil)
      setfield(p, 'glue_set', getfield(f, 'glue_set'))
      setfield(p, 'glue_order', getfield(f, 'glue_order'))
      setfield(p, 'glue_sign', getfield(f, 'glue_sign'))
      node_free(f)
   else
      total = total - res[-1];
      for i = 1, #priority_table do
	 local v = priority_table[i]
         if total <= res[v] then
            for j = i+1,#priority_table do
               clear_stretch(p, priority_table[j], name)
            end
            set_stretch(p, total, res[v], v, name); break
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
      aw_step2(p, aw_step1(p, get_total_stretched(p, line)))
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
