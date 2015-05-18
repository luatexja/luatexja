--
-- luatexja/ltj-jfmglue.lua
--
luatexbase.provides_module({
  name = 'luatexja.jfmglue',
  date = '2015/05/03',
  description = 'Insertion process of JFM glues and kanjiskip',
})
module('luatexja.jfmglue', package.seeall)
local err, warn, info, log = luatexbase .errwarinf(_NAME)

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('stack');     local ltjs = luatexja.stack
luatexja.load_module('jfont');     local ltjf = luatexja.jfont
luatexja.load_module('direction'); local ltjd = luatexja.direction
luatexja.load_module('setwidth');      local ltjw = luatexja.setwidth
local pairs = pairs

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

local has_attr = Dnode.has_attribute
local set_attr = Dnode.set_attribute
local insert_before = Dnode.insert_before
local insert_after = Dnode.insert_after
local node_next = (Dnode ~= node) and Dnode.getnext or node.next
local round = tex.round
local ltjd_make_dir_whatsit = ltjd.make_dir_whatsit
local ltjf_font_metric_table = ltjf.font_metric_table
local ltjf_find_char_class = ltjf.find_char_class
local node_new = Dnode.new
local node_copy = Dnode.copy
local node_remove = Dnode.remove
local node_tail = Dnode.tail
local node_free = Dnode.free
local node_end_of_math = Dnode.end_of_math

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
local lang_ja = luatexja.lang_ja

local sid_start_link = node.subtype('pdf_start_link')
local sid_start_thread = node.subtype('pdf_start_thread')
local sid_end_link = node.subtype('pdf_end_link')
local sid_end_thread = node.subtype('pdf_end_thread')

local ITALIC       = luatexja.icflag_table.ITALIC
local PACKED       = luatexja.icflag_table.PACKED
local KINSOKU      = luatexja.icflag_table.KINSOKU
local FROM_JFM     = luatexja.icflag_table.FROM_JFM
local PROCESSED    = luatexja.icflag_table.PROCESSED
local IC_PROCESSED = luatexja.icflag_table.IC_PROCESSED
local BOXBDD       = luatexja.icflag_table.BOXBDD
local PROCESSED_BEGIN_FLAG = luatexja.icflag_table.PROCESSED_BEGIN_FLAG

local attr_icflag = luatexbase.attributes['ltj@icflag']
local kanji_skip
local xkanji_skip
local table_current_stack
local list_dir
local capsule_glyph
local tex_dir
local attr_ablshift
local set_np_xspc_jachar
local set_np_xspc_jachar_hbox

local ltjs_orig_char_table = ltjs.orig_char_table

local function get_attr_icflag(p)
   return (has_attr(p, attr_icflag) or 0)%PROCESSED_BEGIN_FLAG
end

-------------------- Helper functions

-- This function is called only for acquiring `special' characters.
local function fast_find_char_class(c,m)
   return m.chars[c] or 0
end

-- 文字クラスの決定
local slow_find_char_class
do
   local start_time_measure = ltjb.start_time_measure
   local stop_time_measure = ltjb.stop_time_measure
   slow_find_char_class = function (c, m, oc)
      local cls = ltjf_find_char_class(oc, m)
      if oc~=c and c and cls==0 then
	 return ltjf_find_char_class(c, m)
      else
	 return cls
      end
   end
end

local zero_glue = node_new(id_glue)
spec_zero_glue = to_node(node_new(id_glue_spec))
  -- must be public, since mentioned from other sources
local spec_zero_glue = to_direct(spec_zero_glue)
setfield(spec_zero_glue, 'width', 0)
setfield(spec_zero_glue, 'stretch', 0)
setfield(spec_zero_glue, 'shrink', 0)
setfield(spec_zero_glue, 'stretch_order', 0)
setfield(spec_zero_glue, 'shrink_order', 0)
setfield(zero_glue, 'spec', spec_zero_glue)

local function skip_table_to_spec(n)
   local g, st = node_new(id_glue_spec), ltjs.fast_get_stack_skip(n)
   setfield(g, 'width', st.width)
   setfield(g, 'stretch', st.stretch)
   setfield(g, 'shrink', st.shrink)
   setfield(g, 'stretch_order', st.stretch_order)
   setfield(g, 'shrink_order', st.shrink_order)
   return g
end


-- penalty 値の計算
local function add_penalty(p,e)
   local pp = getfield(p, 'penalty')
   if pp>=10000 then
      if e<=-10000 then setfield(p, 'penalty', 0) end
   elseif pp<=-10000 then
      if e>=10000 then  setfield(p, 'penalty', 0) end
   else
      pp = pp + e
      if pp>=10000 then      setfield(p, 'penalty', 10000)
      elseif pp<=-10000 then setfield(p, 'penalty', -10000)
      else                   setfield(p, 'penalty', pp) end
   end
end

-- 「異なる JFM」の間の調整方法
diffmet_rule = math.two_paverage
function math.two_add(a,b) return a+b end
function math.two_average(a,b) return (a+b)*0.5 end
function math.two_paverage(a,b) return (a+b)/2 end
function math.two_pleft(a,b) return a end
function math.two_pright(a,b) return b end

local head -- the head of current list

local Np, Nq, Bp
local widow_Bp, widow_Np -- \jcharwidowpenalty 挿入位置管理用

local non_ihb_flag -- JFM グルー挿入抑止用 flag
-- false: \inhibitglue 指定時 true: それ以外

-------------------- hlist 内の文字の検索

local first_char, last_char, find_first_char
do
local ltjd_glyph_from_packed = ltjd.glyph_from_packed
local function check_box(box_ptr, box_end)
   local p = box_ptr; local found_visible_node = false
   if not p then
      find_first_char = false; last_char = nil
      return true
   end
   while p and p~=box_end do
      local pid = getid(p)
      if pid==id_kern and getsubtype(p)==2 then
	 p = node_next(node_next(node_next(p))); pid = getid(p) -- p must be glyph_node
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
	 until getid(p)~=id_glyph
	 pid = getid(p) -- p must be non-nil
      end
      if pid==id_kern then
	 local pa = get_attr_icflag(p)
	 if pa==IC_PROCESSED then
	    -- do nothing
	 elseif getsubtype(p)==2 then
	    p = node_next(node_next(p));
	    -- Note that another node_next will be executed outside this if-statement.
	 else
	    found_visible_node = true
	    find_first_char = false; last_char = nil
	 end
      elseif pid==id_hlist then
	 if PACKED == get_attr_icflag(p) then
	    local s = ltjd_glyph_from_packed(p)
	    if find_first_char then
	       first_char = s; find_first_char = false
	    end
	    last_char = s; found_visible_node = true
	 else
	    if getfield(p, 'shift')==0 then
	       last_char = nil
	       if check_box(getlist(p), nil) then found_visible_node = true end
	    else
	       find_first_char = false; last_char = nil
	    end
	 end
      elseif pid==id_math then
	 if find_first_char then
	    first_char = p; find_first_char = false
	 end
	 last_char = p; found_visible_node = true
      elseif pid==id_rule and get_attr_icflag(p)==PACKED then
	 -- do nothing
      elseif not (pid==id_ins   or pid==id_mark
		  or pid==id_adjust or pid==id_whatsit
		  or pid==id_penalty) then
	 found_visible_node = true
	 find_first_char = false; last_char = nil
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
         if getid(first_char)==id_glyph then
	    if getfield(first_char, 'lang') == lang_ja then
	       set_np_xspc_jachar_hbox(Nx, first_char)
	    else
	       set_np_xspc_alchar(Nx, getchar(first_char),first_char, 1)
	    end
	 else -- math_node
	    set_np_xspc_alchar(Nx, -1,first_char)
         end
      end
   end
   return last_char
end
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
local calc_np 
do

local traverse = Dnode.traverse
local function check_next_ickern(lp)
   if lp and getid(lp) == id_kern and ITALIC == get_attr_icflag(lp) then
      set_attr(lp, attr_icflag, IC_PROCESSED)
      Np.last = lp; return node_next(lp)
   else
      Np.last = Np.nuc; return lp
   end
end

local function calc_np_pbox(lp, last)
   local first, lpa, nc = (not Np.first), KINSOKU, nil
   Np.first = Np.first or lp; Np.id = id_pbox
   set_attr(lp, attr_icflag, get_attr_icflag(lp));
   while lp ~=last and (lpa>=PACKED) and (lpa<BOXBDD) do
      if getid(lp)==id_hlist or getid(lp)==id_vlist then
	 head, lp, nc = ltjd_make_dir_whatsit(head, lp, list_dir, 'jfm pbox')
	 Np.first = first and nc or Np.first
      else
	 nc, lp = lp, node_next(lp)
      end
      first, lpa = false, (lp and has_attr(lp, attr_icflag) or 0)
     -- get_attr_icflag() ではいけない！
   end
   Np.nuc = nc
   lp = check_next_ickern(lp)
   Np.last_char = check_box_high(Np, Np.first, lp)
   return lp
end

local ltjw_apply_ashift_math = ltjw.apply_ashift_math
local ltjw_apply_ashift_disc = ltjw.apply_ashift_disc
local min, max = math.min, math.max
local function calc_np_aux_glyph_common(lp)
   Np.nuc = lp
   Np.first= (Np.first or lp)
   if getfield(lp, 'lang') == lang_ja then
      Np.id = id_jglyph
      local m, cls = set_np_xspc_jachar(Np, lp)
      local npi, npf
      lp, head, npi, npf = capsule_glyph(lp, m, cls, head, tex_dir, lp)
      Np.first = (Np.first~=Np.nuc) and Np.first or npf or npi
      Np.nuc = npi
      return true, check_next_ickern(lp);
   else
      Np.id = id_glyph
      set_np_xspc_alchar(Np, getchar(lp), lp, 1)
      -- loop
      local first_glyph, last_glyph = lp
      set_attr(lp, attr_icflag, PROCESSED); Np.last = lp
      local y_adjust = has_attr(lp,attr_ablshift) or 0
      local node_depth = getfield(lp, 'depth') + min(y_adjust, 0)
      local adj_depth = (y_adjust>0) and (getfield(lp, 'depth') + y_adjust) or 0
      setfield(lp, 'yoffset', getfield(lp, 'yoffset') - y_adjust)
      lp = node_next(lp)
      for lx in traverse(lp) do
	 local lai = get_attr_icflag(lx)
	 if lx==last or  lai>=PACKED then
	    lp=lx; break
	 else
	    local lid = getid(lx)
	    if lid==id_glyph and getfield(lx, 'lang') ~= lang_ja then
	       -- 欧文文字
	       last_glyph = lx; set_attr(lx, attr_icflag, PROCESSED); Np.last = lx
	       y_adjust = has_attr(lx,attr_ablshift) or 0
	       node_depth = max(getfield(lx, 'depth') + min(y_adjust, 0), node_depth)
	       adj_depth = (y_adjust>0) and max(getfield(lx, 'depth') + y_adjust, adj_depth) or adj_depth
	       setfield(lx, 'yoffset', getfield(lx, 'yoffset') - y_adjust)
	    elseif lid==id_kern then
	       local ls = getsubtype(lx)
	       if ls==2 then -- アクセント用の kern
		  set_attr(lx, attr_icflag, PROCESSED)
		  lx = node_next(lx) -- lx: アクセント本体
		  setfield(lx, 'yoffset', getfield(lx, 'yoffset') - (has_attr(lx,attr_ablshift) or 0))
		  lx = node_next(node_next(lx))
	       elseif ls==0  then
		  Np.last = lx
	       elseif (ls==1 and lai==ITALIC) then
		  Np.last = lx; set_attr(lx, attr_icflag, IC_PROCESSED)
	       else
		  lp=lx; break
	       end
	    else
	       lp=lx; break
	    end
	 end
      end
      local r
      if adj_depth>node_depth then
	    r = node_new(id_rule)
	    setfield(r, 'width', 0); setfield(r, 'height', 0)
	    setfield(r, 'depth',adj_depth); setfield(r, 'dir', tex_dir)
	    set_attr(r, attr_icflag, PROCESSED)
      end
      if last_glyph then
	 Np.last_char = last_glyph
	 if r then insert_after(head, first_glyph, r) end
      else
	 local npn = Np.nuc
	 Np.last_char = npn
	 if r then
	    local nf, nc = getfont(npn), getchar(npn)
	    local ct = (font.getfont(nf) or font.fonts[nf] ).characters[nc]
	    if not ct then -- variation selector
	       node_free(r)
	    elseif (ct.left_protruding or 0) == 0 then
	       head = insert_before(head, npn, r)
	       Np.first = (Np.first==npn) and r or npn
	    elseif (ct.right_protruding or 0) == 0 then
	       insert_after(head, npn, r); Np.last, lp = r, r
	    else
	       ltjb.package_warning_no_line(
		  'luatexja',
		  'Check depth of glyph node ' .. tostring(npn) .. '(font=' .. nf
		     .. ', char=' .. nc .. '),    because its \\lpcode is ' .. tostring(ct.left_protruding)
		     .. ' and its \\rpcode is ' .. tostring(ct.right_protruding)
	       ); node_free(r)
	    end
	 end
      end
      return true, lp
   end
end
local calc_np_auxtable = {
   [id_glyph] = calc_np_aux_glyph_common,
   [id_hlist] = function(lp)
      local op, flag
      head, lp, op, flag = ltjd_make_dir_whatsit(head, lp, list_dir, 'jfm hlist')
      set_attr(op, attr_icflag, PROCESSED)
      Np.first = Np.first or op; Np.last = op; Np.nuc = op;
      if (flag or getfield(op, 'shift')~=0) then
	 Np.id = id_box_like
      else
	 Np.id = id_hlist
	 Np.last_char = check_box_high(Np, getlist(op), nil)
      end
      return true, lp
   end,
   [id_vlist] =  function(lp)
      local op
      head, lp, op = ltjd_make_dir_whatsit(head, lp, list_dir, 'jfm:' .. getid(lp))
      Np.first = Np.first or op; Np.last = op; Np.nuc = op;
      Np.id = id_box_like;
      return true, lp
   end,
   box_like = function(lp)
      Np.first = Np.first or lp; Np.last = lp; Np.nuc = lp;
      Np.id = id_box_like;
      return true, node_next(lp)
   end,
   skip = function(lp)
      set_attr(lp, attr_icflag, PROCESSED)
      return false, node_next(lp)
   end,
   [id_whatsit] = function(lp)
      local lps = getsubtype(lp)
      if lps==sid_user then
	 if getfield(lp, 'user_id')==luatexja.userid_table.IHB then
	    local lq = node_next(lp);
	    head = node_remove(head, lp); node_free(lp); non_ihb_flag = false
	    return false, lq;
	 else
	    set_attr(lp, attr_icflag, PROCESSED)
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
	 if lps == sid_start_link or lps == sid_start_thread then
	    Np.first = lp
	 elseif lps == sid_end_link or lps == sid_end_thread then
	    Np.first, Nq.last = nil, lp;
	 end
	 set_attr(lp, attr_icflag, PROCESSED)
	 return false, node_next(lp)
      end
   end,
   [id_math] = function(lp)
      Np.first, Np.nuc = (Np.first or lp), lp;
      set_attr(lp, attr_icflag, PROCESSED)
      set_np_xspc_alchar(Np, -1, lp)
      local end_math  = node_end_of_math(lp)
      ltjw_apply_ashift_math(lp, end_math, attr_ablshift)
      set_attr(end_math, attr_icflag, PROCESSED)
      Np.last, Np.id = end_math, id_math;
      return true, node_next(end_math);
   end,
   [id_glue] = function(lp)
      Np.first, Np.nuc, Np.last = (Np.first or lp), lp, lp;
      Np.id = getid(lp); set_attr(lp, attr_icflag, PROCESSED)
      return true, node_next(lp)
   end,
   [id_disc] = function(lp)
      Np.first, Np.nuc, Np.last = (Np.first or lp), lp, lp;
      Np.id = getid(lp); set_attr(lp, attr_icflag, PROCESSED)
      ltjw_apply_ashift_disc(lp, (list_dir==dir_tate), tex_dir)
      Np.last_char = check_box_high(Np, getfield(lp, 'replace'), nil)
      return true, node_next(lp)
   end,
   [id_kern] = function(lp)
      if getsubtype(lp)==2 then
	 Np.first = Np.first or lp
	 set_attr(lp, attr_icflag, PROCESSED); lp = node_next(lp)
	 set_attr(lp, attr_icflag, PROCESSED); lp = node_next(lp)
	 set_attr(lp, attr_icflag, PROCESSED); lp = node_next(lp)
	 set_attr(lp, attr_icflag, PROCESSED);
	 return calc_np_aux_glyph_common(lp)
      else
	 Np.first = Np.first or lp
	 Np.id = id_kern; set_attr(lp, attr_icflag, PROCESSED)
	 Np.last = lp; return true, node_next(lp)
      end
   end,
   [id_penalty] = function(lp)
      Bp[#Bp+1] = lp; set_attr(lp, attr_icflag, PROCESSED)
      return false, node_next(lp)
   end,
}
calc_np_auxtable[id_rule]   = calc_np_auxtable.box_like
calc_np_auxtable[13]        = calc_np_auxtable.box_like
calc_np_auxtable[id_ins]    = calc_np_auxtable.skip
calc_np_auxtable[id_mark]   = calc_np_auxtable.skip
calc_np_auxtable[id_adjust] = calc_np_auxtable.skip

function calc_np(last, lp)
   local k
   -- We assume lp = node_next(Np.last)
   Np, Nq, non_ihb_flag = Nq, Np, true
   -- We clear `predefined' entries of Np before pairs() loop,
   -- because using only pairs() loop is slower.
   Np.post, Np.pre, Np.xspc = nil, nil, nil
   Np.first, Np.id, Np.last, Np.met, Np.class= nil, nil, nil, nil
   Np.auto_kspc, Np.auto_xspc, Np.char, Np.nuc = nil, nil, nil, nil
   for k in pairs(Np) do Np[k] = nil end

   for k = 1,#Bp do Bp[k] = nil end
   while lp ~= last  do
      local lpa = has_attr(lp, attr_icflag) or 0
       -- unbox 由来ノードの検出
      if lpa>=PACKED then
         if lpa%PROCESSED_BEGIN_FLAG == BOXBDD then
	    local lq = node_next(lp)
            head = node_remove(head, lp); node_free(lp); lp = lq
         else
	    return calc_np_pbox(lp, last)
         end -- id_pbox
      else
	 k, lp = calc_np_auxtable[getid(lp)](lp)
	 if k then return lp end
      end
   end
   Np=nil
end
end

-- extract informations from Np
-- We think that "Np is a Japanese character" if Np.met~=nil,
--            "Np is an alphabetic character" if Np.pre~=nil,
--            "Np is not a character" otherwise.
after_hlist = nil -- global
local after_alchar, extract_np
do
  local PRE  = luatexja.stack_table_index.PRE
  local POST = luatexja.stack_table_index.POST
  local KCAT = luatexja.stack_table_index.KCAT
  local XSP  = luatexja.stack_table_index.XSP
  local dir_tate = luatexja.dir_table.dir_tate

-- 和文文字のデータを取得
   local attr_jchar_class = luatexbase.attributes['ltj@charclass']
   local attr_jchar_code = luatexbase.attributes['ltj@charcode']
   local attr_autospc = luatexbase.attributes['ltj@autospc']
   local attr_autoxspc = luatexbase.attributes['ltj@autoxspc']
   --local ltjf_get_vert_glyph = ltjf.get_vert_glyph
   function set_np_xspc_jachar(Nx, x)
      local m = ltjf_font_metric_table[getfont(x)]
      local c, c_glyph = ltjs_orig_char_table[x], getchar(x)
      c = c or c_glyph
      local cls = slow_find_char_class(c, m, c_glyph)
      Nx.met, Nx.class, Nx.char = m, cls, c;
      if cls~=0 then set_attr(x, attr_jchar_class, cls) end
      if c~=c_glyph then set_attr(x, attr_jchar_code, c) end
      Nx.pre  = table_current_stack[PRE + c]  or 0
      Nx.post = table_current_stack[POST + c] or 0
      Nx.xspc = table_current_stack[XSP  + c] or 3
      Nx.kcat = table_current_stack[KCAT + c] or 0
      Nx.auto_kspc, Nx.auto_xspc = (has_attr(x, attr_autospc)==1), (has_attr(x, attr_autoxspc)==1)
      return m, cls
   end
   function set_np_xspc_jachar_hbox(Nx, x)
      local m = ltjf_font_metric_table[getfont(x)]
      local c = has_attr(x, attr_jchar_code) or getchar(x)
      Nx.met, Nx.char  = m, c; Nx.class = has_attr(x, attr_jchar_class) or 0;
      Nx.pre  = table_current_stack[PRE + c]  or 0
      Nx.post = table_current_stack[POST + c] or 0
      Nx.xspc = table_current_stack[XSP  + c] or 3
      Nx.kcat = table_current_stack[KCAT + c] or 0
      Nx.auto_kspc, Nx.auto_xspc = (has_attr(x, attr_autospc)==1), (has_attr(x, attr_autoxspc)==1)
   end

-- 欧文文字のデータを取得
   local floor = math.floor
   function set_np_xspc_alchar(Nx, c,x, lig)
      if c~=-1 then
	 local f = (lig ==1) and nullfunc or node_tail
         local xc, xs = getfield(x, 'components'), getsubtype(x)
	 while xc and xs and xs%4>=2 do
	    x = f(xc); xc, xs = getfield(x, 'components'), getsubtype(x)
	 end
	 c = getchar(x)
	 Nx.pre  = table_current_stack[PRE + c]  or 0
	 Nx.post = table_current_stack[POST + c] or 0
	 Nx.xspc = table_current_stack[XSP  + c] or 3
      else
	 Nx.pre, Nx.post = 0, 0
         Nx.xspc = table_current_stack[XSP - 1] or 3
      end
      Nx.met = nil
      Nx.auto_xspc = (has_attr(x, attr_autoxspc)==1)
   end
   local set_np_xspc_alchar = set_np_xspc_alchar

   -- change the information for the next loop
   -- (will be done if Nx is an alphabetic character or a hlist)
   after_hlist = function (Nx)
      local s = Nx.last_char
      if s then
	 if getid(s)==id_glyph then
	    if getfield(s, 'lang') == lang_ja then
	       set_np_xspc_jachar_hbox(Nx, s)
	    else
	       set_np_xspc_alchar(Nx, getchar(s), s, 2)
	    end
	 else
	    set_np_xspc_alchar(Nx, -1, s)
	 end
      else
	 Nx.pre, Nx.met = nil, nil
      end
   end

   after_alchar = function (Nx)
      local x = Nx.last_char
      return set_np_xspc_alchar(Nx, getchar(x), x, 2)
   end

end

-------------------- 最下層の処理

-- change penalties (or create a new penalty, if needed)
local function handle_penalty_normal(post, pre, g)
   local a = (pre or 0) + (post or 0)
   if #Bp == 0 then
      if (a~=0 and not(g and getid(g)==id_kern)) then
	 local p = node_new(id_penalty)
	 if a<-10000 then a = -10000 elseif a>10000 then a = 10000 end
	 setfield(p, 'penalty', a)
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
      if not (g and getid(g)==id_glue) or a~=0 then
	 local p = node_new(id_penalty)
	 if a<-10000 then a = -10000 elseif a>10000 then a = 10000 end
	 setfield(p, 'penalty', a)
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
      if g and getid(g)==id_glue then
	 local p = node_new(id_penalty)
	 setfield(p, 'penalty', 10000); head = insert_before(head, Np.first, p)
	 Bp[1]=p
         set_attr(p, attr_icflag, KINSOKU)
      end
   else for _, v in pairs(Bp) do add_penalty(v,a) end
   end
end

-- 和文文字間の JFM glue を node 化
local function new_jfm_glue(m, bc, ac)
-- bc, ac: char classes
   local g = m.char_type[bc][ac]
   if g then
      if g[1] then
	 local f = node_new(id_glue)
	 set_attr(f, attr_icflag, g[4])
	 setfield(f, 'spec', node_copy(g[2]))
	 return f, g[3]
      else
	 return node_copy(g[2]), g[3]
      end
   end
   return nil, 0
end

-- Nq.last (kern w) .... (glue/kern g) Np.first
local function real_insert(g)
   if g then
      head  = insert_before(head, Np.first, g)
      Np.first = g
   end
end


-------------------- 和文文字間空白量の決定
local null_skip_table = {0, 0, 0}
-- get kanjiskip
local get_kanjiskip
local get_kanjiskip_normal, get_kanjiskip_jfm
do
   local KANJI_SKIP   = luatexja.icflag_table.KANJI_SKIP
   local KANJI_SKIP_JFM   = luatexja.icflag_table.KANJI_SKIP_JFM
   get_kanjiskip_normal = function ()
      if Np.auto_kspc or Nq.auto_kspc then
	 return node_copy(kanji_skip)
      else
	 local g = node_copy(zero_glue)
	 set_attr(g, attr_icflag, KANJI_SKIP)
	 return g
      end
   end

   get_kanjiskip_jfm = function ()
      local g
      if Np.auto_kspc or Nq.auto_kspc then
	 g = node_new(id_glue); --copy_attr(g, Nq.nuc)
	 local gx = node_new(id_glue_spec);
	 setfield(gx, 'stretch_order', 0); setfield(gx, 'shrink_order', 0)
	 local pm, qm = Np.met, Nq.met
	 local bk = qm.kanjiskip or null_skip_table
	 if (pm.char_type==qm.char_type) and (qm.var==pm.var) then
	    setfield(gx, 'width', bk[1])
	    setfield(gx, 'stretch', bk[2])
	    setfield(gx, 'shrink', bk[3])
	 else
	    local ak = pm.kanjiskip or null_skip_table
	    setfield(gx, 'width', round(diffmet_rule(bk[1], ak[1])))
	    setfield(gx, 'stretch', round(diffmet_rule(bk[2], ak[2])))
	    setfield(gx, 'shrink', -round(diffmet_rule(-bk[3], -ak[3])))
	 end
	 setfield(g, 'spec', gx)
      else
	 g =  node_copy(zero_glue)
      end
      set_attr(g, attr_icflag, KANJI_SKIP_JFM)
      return g
   end
end

local calc_ja_ja_aux
do
   local bg_ag = 2*id_glue - id_glue
   local bg_ak = 2*id_glue - id_kern
   local bk_ag = 2*id_kern - id_glue
   local bk_ak = 2*id_kern - id_kern

   calc_ja_ja_aux = function (gb,ga, db, da)
      local rbb, rab = 0.5*(1-db), 0.5*(1-da) -- 「前の文字」由来のグルーの割合
      local rba, raa = 0.5*(1+db), 0.5*(1+da) -- 「前の文字」由来のグルーの割合
      if diffmet_rule ~= math.two_pleft and diffmet_rule ~= math.two_pright
          and diffmet_rule ~= math.two_paverage then
	 rbb, rab, rba, raa = 1,0,0,1
      end
      if not gb then
	 if ga then
	    gb = node_new(id_kern); setfield(gb, 'kern', 0)
	 else return nil end
      elseif not ga then
	 ga = node_new(id_kern); setfield(ga, 'kern', 0)
      end

      local k = 2*getid(gb) - getid(ga)
      if k == bg_ag then
	 local bs, as = getfield(gb, 'spec'), getfield(ga, 'spec')
	 -- 両方とも glue．
	 local bd, ad = getfield(bs, 'width'), getfield(as, 'width')
	 setfield(bs, 'width', round(diffmet_rule(rbb*bd + rba*ad, rab*bd + raa*ad)))
	 bd, ad = getfield(bs, 'stretch'), getfield(as, 'stretch')
	 setfield(bs, 'stretch', round(diffmet_rule(rbb*bd + rba*ad, rab*bd + raa*ad)))
	 bd, ad = getfield(bs, 'shrink'), getfield(as, 'shrink')
	 setfield(bs, 'shrink', -round(diffmet_rule(-rbb*bd - rba*ad, -rab*bd - raa*ad)))
	 node_free(ga)
	 return gb
      elseif k == bk_ak then
	 -- 両方とも kern．
	 local bd, ad = getfield(gb, 'kern'), getfield(ga, 'kern')
	 setfield(gb, 'kern', round(diffmet_rule(rbb*bd + rba*ad, rab*bd + raa*ad)))
	 node_free(ga)
	 return gb
      elseif k == bk_ag then
	 local as = getfield(ga, 'spec')
	 -- gb: kern, ga: glue
	 local bd, ad = getfield(gb, 'kern'), getfield(as, 'width')
	 setfield(as, 'width', round(diffmet_rule(rbb*bd + rba*ad, rab*bd + raa*ad)))
	 ad = getfield(as, 'stretch')
	 setfield(bs, 'stretch', round(diffmet_rule(rba*ad, raa*ad)))
	 ad = getfield(as, 'shrink')
	 setfield(bs, 'shrink', -round(diffmet_rule(-rba*ad, -raa*ad)))
	 node_free(gb)
	 return ga
      else
	 local bs = getfield(gb, 'spec')
	 -- gb: glue, ga: kern
	 local bd, ad = getfield(bs, 'width'), getfield(ga, 'kern')
	 setfield(bs, 'width', round(diffmet_rule(rbb*bd + rba*ad, rab*bd + raa*ad)))
	 bd = getfield(bs, 'stretch')
	 setfield(bs, 'stretch', round(diffmet_rule(rbb*bd, rab*bd)))
	 bd = getfield(bs, 'shrink')
	 setfield(bs, 'shrink', -round(diffmet_rule(-rbb*bd, -rab*bd)))
	 node_free(ga)
	 return gb
      end
   end
end

local function calc_ja_ja_glue()
   local qm, pm = Nq.met, Np.met
   if (qm.char_type==pm.char_type) and (qm.var==pm.var) then
      return new_jfm_glue(qm, Nq.class, Np.class)
   else
      local npn, nqn = Np.nuc, Nq.nuc
      local gb, db = new_jfm_glue(qm, Nq.class,
				  slow_find_char_class(Np.char,
						       qm, getchar(npn)))
      local ga, da = new_jfm_glue(pm,
				  slow_find_char_class(Nq.char,
						       pm, getchar(nqn)),
				  Np.class)
      return calc_ja_ja_aux(gb, ga, db, da);
   end
end

-------------------- 和欧文間空白量の決定

-- get xkanjiskip
local get_xkanjiskip
local get_xkanjiskip_normal, get_xkanjiskip_jfm
do
   local XKANJI_SKIP   = luatexja.icflag_table.XKANJI_SKIP
   local XKANJI_SKIP_JFM   = luatexja.icflag_table.XKANJI_SKIP_JFM
   get_xkanjiskip_normal = function (Nn)
      if (Nq.xspc>=2) and (Np.xspc%2==1) and (Nq.auto_xspc or Np.auto_xspc) then
	 return node_copy(xkanji_skip)
      else
	 local g = node_copy(zero_glue)
	 set_attr(g, attr_icflag, XKANJI_SKIP)
	 return g
      end
   end
   get_xkanjiskip_jfm = function (Nn)
      local g
      if (Nq.xspc>=2) and (Np.xspc%2==1) and (Nq.auto_xspc or Np.auto_xspc) then
	 g = node_new(id_glue)
	 local gx = node_new(id_glue_spec);
	 setfield(gx, 'stretch_order', 0); setfield(gx, 'shrink_order', 0)
	 local bk = Nn.met.xkanjiskip or null_skip_table
	 setfield(gx, 'width', bk[1])
	 setfield(gx, 'stretch', bk[2])
	 setfield(gx, 'shrink', bk[3])
	 setfield(g, 'spec', gx)
      else
	 g = node_copy(zero_glue)
      end
      set_attr(g, attr_icflag, XKANJI_SKIP_JFM)
      return g
   end
end

-------------------- 隣接した「塊」間の処理

local function get_OA_skip()
   local pm = Np.met
   return new_jfm_glue(pm,
		       fast_find_char_class((Nq.id == id_math and -1 or 'jcharbdd'), pm), Np.class)
end
local function get_OB_skip()
   local qm = Nq.met
   return new_jfm_glue(qm, Nq.class,
		       fast_find_char_class((Np.id == id_math and -1 or'jcharbdd'), qm))
end

-- (anything) .. jachar
local function handle_np_jachar(mode)
   local qid = Nq.id
   if qid==id_jglyph or ((qid==id_pbox or qid==id_pbox_w) and Nq.met) then
       local g = non_ihb_flag and calc_ja_ja_glue() or get_kanjiskip() -- M->K
      handle_penalty_normal(Nq.post, Np.pre, g); real_insert(g)
   elseif Nq.met then  -- qid==id_hlist
      local g = non_ihb_flag and get_OA_skip() or get_kanjiskip() -- O_A->K
      handle_penalty_normal(0, Np.pre, g); real_insert(g)
   elseif Nq.pre then
      local g = non_ihb_flag and get_OA_skip() or get_xkanjiskip(Np) -- O_A->X
      handle_penalty_normal((qid==id_hlist and 0 or Nq.post), Np.pre, g); real_insert(g)
   else
      local g = non_ihb_flag and get_OA_skip() -- O_A
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
      local g = non_ihb_flag and get_OB_skip() or get_xkanjiskip(Nq) -- O_B->X
      handle_penalty_normal(Nq.post, (Np.id==id_hlist and 0 or Np.pre), g); real_insert(g)
   else
      local g =non_ihb_flag and  get_OB_skip() -- O_B
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
      local g = non_ihb_flag and get_OB_skip() or get_kanjiskip() -- O_B->K
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
      [id_glyph] = function() after_alchar(Nq) end, -- after_alchar(Nq)
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
do

-- リスト末尾の処理
local JWP  = luatexja.stack_table_index.JWP
local function handle_list_tail(mode)
   adjust_nq(); Np = Nq
   if mode then
      -- the current list is to be line-breaked.
      -- Insert \jcharwidowpenalty
      Bp = widow_Bp; Np = widow_Np
      if Np.first then
	 handle_penalty_normal(0, table_current_stack[JWP] or 0)
      end
   else
      -- the current list is the contents of a hbox
      local npi, pm = Np.id, Np.met
      if npi == id_jglyph or (npi==id_pbox and pm) then
	 local g = new_jfm_glue(pm, Np.class, fast_find_char_class('boxbdd', pm))
	 if g then
	    set_attr(g, attr_icflag, BOXBDD)
	    head = insert_after(head, Np.last, g)
	 end
      end
   end
end

-- リスト先頭の処理
local function handle_list_head(par_indented)
   local npi, pm = Np.id, Np.met
   if npi ==  id_jglyph or (npi==id_pbox and pm) then
      if non_ihb_flag then
	 local g = new_jfm_glue(pm, fast_find_char_class(par_indented, pm), Np.class)
	 if g then
	    set_attr(g, attr_icflag, BOXBDD)
	    if getid(g)==id_glue and #Bp==0 then
	       local h = node_new(id_penalty)
	       setfield(h, 'penalty', 10000); set_attr(h, attr_icflag, BOXBDD)
	    end
	    head = insert_before(head, Np.first, g)
	 end
      end
   end
end

-- initialize
-- return value: (the initial cursor lp), (last node)
local init_var
do
   local KANJI_SKIP   = luatexja.icflag_table.KANJI_SKIP
   local XKANJI_SKIP   = luatexja.icflag_table.XKANJI_SKIP
   local KSK  = luatexja.stack_table_index.KSK
   local XSK  = luatexja.stack_table_index.XSK
   local dir_yoko = luatexja.dir_table.dir_yoko
   local dir_tate = luatexja.dir_table.dir_tate
   local attr_yablshift = luatexbase.attributes['ltj@yablshift']
   local attr_tablshift = luatexbase.attributes['ltj@tablshift']
   local table_pool = {
      {}, {}, {first=nil},
      { auto_kspc=nil, auto_xspc=nil, char=nil, class=nil,
	first=nil, id=nil, last=nil, met=nil, nuc=nil,
	post=nil, pre=nil, xspc=nil, }, 
      { auto_kspc=nil, auto_xspc=nil, char=nil, class=nil,
	first=nil, id=nil, last=nil, met=nil, nuc=nil,
	post=nil, pre=nil, xspc=nil, },
   }
   init_var = function (mode,dir)
      -- 1073741823: max_dimen
      Bp, widow_Bp, widow_Np, Np, Nq
	 = table_pool[1], table_pool[2], table_pool[3], table_pool[4], table_pool[5]
      for i=1,5 do for j,_ in pairs(table_pool[i]) do table_pool[i][j]=nil end end
      table_current_stack = ltjs.table_current_stack

      list_dir, tex_dir = (ltjs.list_dir or dir_yoko), (dir or 'TLT')
      local is_dir_tate = list_dir==dir_tate
      capsule_glyph = is_dir_tate and ltjw.capsule_glyph_tate or ltjw.capsule_glyph_yoko
      attr_ablshift = is_dir_tate and attr_tablshift or attr_yablshift
      local TEMP = node_new(id_glue) 
      -- TEMP is a dummy node, which will be freed at the end of the callback. 
      -- ithout this node, set_attr(kanji_skip, ...) somehow creates an "orphaned"  attribute list.

      do
	 kanji_skip = node_new(id_glue); set_attr(kanji_skip, attr_icflag, KANJI_SKIP)
	 local s = skip_table_to_spec(KSK)
	 setfield(kanji_skip, 'spec', s)
	 get_kanjiskip = (getfield(s, 'width') == 1073741823)
	    and get_kanjiskip_jfm or get_kanjiskip_normal
      end

      do
	 xkanji_skip = node_new(id_glue); set_attr(xkanji_skip, attr_icflag, XKANJI_SKIP)
	 local s = skip_table_to_spec(XSK)
	 setfield(xkanji_skip, 'spec', s)
	 get_xkanjiskip = (getfield(s, 'width') == 1073741823)
	    and get_xkanjiskip_jfm or get_xkanjiskip_normal
      end

      if mode then
	 -- the current list is to be line-breaked:
	 -- hbox from \parindent is skipped.
	 local lp, par_indented, lpi, lps  = head, 'boxbdd', getid(head), getsubtype(head)
	 while lp and ((lpi==id_whatsit and lps~=sid_user)
		       or ((lpi==id_hlist) and (lps==3))) do
	    if (lpi==id_hlist) and (lps==3) then
               Np.char, par_indented = 'parbdd', 'parbdd'
               Np.width = getfield(lp, 'width')
            end
	    lp=node_next(lp); lpi, lps = getid(lp), getsubtype(lp) end
	 return lp, node_tail(head), par_indented, TEMP
      else
	 return head, nil, 'boxbdd', TEMP
      end
   end
end

local ensure_tex_attr = ltjb.ensure_tex_attr
local function cleanup(mode, TEMP)
   -- adjust attr_icflag for avoiding error
   if tex.getattribute(attr_icflag)~=0 then ensure_tex_attr(attr_icflag, 0) end
   node_free(kanji_skip); node_free(xkanji_skip); node_free(TEMP)
   
   if mode then
      local h = node_next(head)
      if getid(h) == id_penalty and getfield(h, 'penalty') == 10000 then
	 h = node_next(h)
	 if getid(h) == id_glue and getsubtype(h) == 15 and not node_next(h) then
	    return false
	 end
      end
   end
   return head
end
-------------------- 外部から呼ばれる関数

-- main interface
function main(ahead, mode, dir)
   if not ahead then return ahead end
   head = ahead;
   local lp, last, par_indented, TEMP = init_var(mode,dir)
   lp = calc_np(last, lp)
   if Np then
      handle_list_head(par_indented)
      lp = calc_np(last,lp); while Np do
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
	 lp = calc_np(last,lp)
      end
      handle_list_tail(mode)
   end
   return cleanup(mode, TEMP)
end
end

do
   local IHB  = luatexja.userid_table.IHB
   local BPAR = luatexja.userid_table.BPAR
   local node_prev = (Dnode ~= node) and Dnode.getprev or node.prev
   local node_write = Dnode.write

   -- \inhibitglue
   function create_inhibitglue_node()
      local tn = node_new(id_whatsit, sid_user)
      setfield(tn, 'user_id', IHB)
      setfield(tn, 'type', 100)
      setfield(tn, 'value', 1)
      node_write(tn)
   end

   -- Node for indicating beginning of a paragraph
   -- (for ltjsclasses)
   function create_beginpar_node()
      local tn = node_new(id_whatsit, sid_user)
      setfield(tn, 'user_id', BPAR)
      setfield(tn, 'type', 100)
      setfield(tn, 'value', 1)
      node_write(tn)
   end

   local function whatsit_callback(Np, lp, Nq)
      if Np and Np.nuc then return Np
      elseif Np and getfield(lp, 'user_id') == BPAR then
         Np.first = lp; Np.nuc = lp; Np.last = lp
         return Np
      end
   end

    local function whatsit_after_callback(s, Nq, Np)
       if not s and getfield(Nq.nuc, 'user_id') == BPAR then
         local x, y = node_prev(Nq.nuc), Nq.nuc
         Nq.first, Nq.nuc, Nq.last = x, x, x
         if Np then
            if Np.met then
               Nq.class = fast_find_char_class('parbdd', Np.met)
            end
            Nq.met = Np.met; Nq.pre = 0; Nq.post = 0; Nq.xspc = 0
            Nq.auto_xspc = false
         end
         head = node_remove(head, y)
	 node_free(y)
      end
      return s
   end

   luatexbase.add_to_callback("luatexja.jfmglue.whatsit_getinfo", whatsit_callback,
                              "luatexja.beginpar.np_info", 1)
   luatexbase.add_to_callback("luatexja.jfmglue.whatsit_after", whatsit_after_callback,
                              "luatexja.beginpar.np_info_after", 1)

end
