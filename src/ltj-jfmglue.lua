--
-- ltj-jfmglue.lua
--
luatexbase.provides_module({
  name = 'luatexja.jfmglue',
  date = '2021-09-18',
  description = 'Insertion process of JFM glues, [x]kanjiskip and others',
})
luatexja.jfmglue = luatexja.jfmglue or {}

luatexja.load_module 'base';      local ltjb = luatexja.base
luatexja.load_module 'stack';     local ltjs = luatexja.stack
luatexja.load_module 'jfont';     local ltjf = luatexja.jfont
luatexja.load_module 'direction'; local ltjd = luatexja.direction
luatexja.load_module 'setwidth';  local ltjw = luatexja.setwidth
luatexja.load_module 'lotf_aux';  local ltju = luatexja.lotf_aux
local pairs = pairs

--local to_node = node.direct.tonode
--local to_direct = node.direct.todirect

local setfield = node.direct.setfield
local setglue = luatexja.setglue
local getfield = node.direct.getfield
local getid = node.direct.getid
local getfont = node.direct.getfont
local getlist = node.direct.getlist
local getchar = node.direct.getchar
local getsubtype = node.direct.getsubtype
local if_lang_ja
do
    local lang_ja = luatexja.lang_ja
    local getlang = node.direct.getlang
    -- glyph with font number 0 (\nullfont) is always considered an ALchar node
    if_lang_ja = getlang 
      and function (n) return (getlang(n)==lang_ja)and(getfont(n)~=0) end
      or  function (n) return (getfield(n,'lang')==lang_ja)and(getfont(n)~=0) end
end
  
local has_attr = node.direct.has_attribute
local set_attr = node.direct.set_attribute
local insert_before = node.direct.insert_before
local insert_after = node.direct.insert_after
local node_next = node.direct.getnext
local ltjd_make_dir_whatsit = ltjd.make_dir_whatsit
local ltjf_font_metric_table = ltjf.font_metric_table
local ltjf_find_char_class = ltjf.find_char_class
local node_new = luatexja.dnode_new
local node_copy = node.direct.copy
local node_tail = node.direct.tail
local node_free = node.direct.free
local node_remove = node.direct.remove
local node_inherit_attr = luatexja.node_inherit_attr

local id_glyph = node.id 'glyph'
local id_hlist = node.id 'hlist'
local id_vlist = node.id 'vlist'
local id_rule  = node.id 'rule'
local id_ins   = node.id 'ins'
local id_mark  = node.id 'mark'
local id_adjust = node.id 'adjust'
local id_disc  = node.id 'disc'
local id_whatsit = node.id 'whatsit'
local id_math  = node.id 'math'
local id_glue  = node.id 'glue'
local id_kern  = node.id 'kern'
local id_penalty = node.id 'penalty'

local id_jglyph    = 512 -- Japanese character
local id_box_like  = 256 -- vbox, shifted hbox
local id_pbox      = 257 -- already processed nodes (by \unhbox)
local id_pbox_w    = 258 -- cluster which consists of a whatsit
local sid_user = node.subtype 'user_defined'

local ITALIC       = luatexja.icflag_table.ITALIC
local PACKED       = luatexja.icflag_table.PACKED
local KINSOKU      = luatexja.icflag_table.KINSOKU
local FROM_JFM     = luatexja.icflag_table.FROM_JFM
local PROCESSED    = luatexja.icflag_table.PROCESSED
local IC_PROCESSED = luatexja.icflag_table.IC_PROCESSED
local BOXBDD       = luatexja.icflag_table.BOXBDD
local SPECIAL_JAGLUE = luatexja.icflag_table.SPECIAL_JAGLUE
local PROCESSED_BEGIN_FLAG = luatexja.icflag_table.PROCESSED_BEGIN_FLAG

local attr_icflag = luatexbase.attributes['ltj@icflag']
local kanji_skip
local xkanji_skip
local table_current_stack
local list_dir
local capsule_glyph
local tex_dir
local attr_ablshift
local set_np_xspc_jachar, set_np_xspc_alchar
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

local function skip_table_to_glue(n)
   local g, st = node_new(id_glue), ltjs.fast_get_stack_skip(n)
   setglue(g, st.width, st.stretch, st.shrink, st.stretch_order, st.shrink_order)
   return g, (st.width==1073741823)
end


-- penalty 値の計算
local add_penalty
do
local setpenalty = node.direct.setpenalty or function(n, a) setfield(n,'penalty',a) end
local getpenalty = node.direct.getpenalty or function(n) return getfield(n,'penalty') end
function add_penalty(p,e)
   local pp = getpenalty(p)
   if (pp>-10000) and (pp<10000) then
      if e>=10000 then       setpenalty(p, 10000)
      elseif e<=-10000 then  setpenalty(p, -10000)
      else
         pp = pp + e
         if pp>=10000 then      setpenalty(p, 10000)
         elseif pp<=-10000 then setpenalty(p, -10000)
         else                   setpenalty(p, pp) end
      end
   end
end
end

-- 「異なる JFM」の間の調整方法
luatexja.jfmglue.diffmet_rule = math.two_paverage
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
local check_box_high
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
            if find_first_char then first_char = p; find_first_char = false end
            last_char = p; found_visible_node = true; p=node_next(p)
            if (not p) or p==box_end then return found_visible_node end
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
            if find_first_char then first_char = s; find_first_char = false end
            last_char = s; found_visible_node = true
         else
            if getfield(p, 'shift')==0 then
               last_char = nil
               if check_box(getlist(p), nil) then found_visible_node = true end
               find_first_char = false
            else
               find_first_char = false; last_char = nil
            end
         end
      elseif pid==id_math then
         if find_first_char then first_char = p; find_first_char = false end
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

check_box_high = function (Nx, box_ptr, box_end)
   first_char = nil;  last_char = nil;  find_first_char = true
   if check_box(box_ptr, box_end) then
      local first_char = first_char
      if first_char then
         if getid(first_char)==id_glyph then
            if if_lang_ja(first_char) then
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
luatexbase.create_callback("luatexja.jfmglue.whatsit_last_minute", "data",
                           function (stat, Nq, Np) return false end)

-- calc next Np
local calc_np 
do -- 001 -----------------------------------------------

local traverse = node.direct.traverse
local function check_next_ickern(lp)
   local lx = Np.nuc
   while lp and getid(lp) == id_kern and ( getsubtype(lp)==0 or 
     getsubtype(lp)==3 or ITALIC == get_attr_icflag(lp)) do
     set_attr(lp, attr_icflag, IC_PROCESSED)
     lx, lp = lp, node_next(lp)
   end
   Np.last = lx; return lp
end

local function calc_np_pbox(lp, last)
   local first, nc = (not Np.first), nil
   --local lpa = get_attr_icflag(lp)==PACKED and PACKED or KINSOKU -- KINSOKU: dummy
   local lpa = get_attr_icflag(lp)
   Np.first = Np.first or lp; Np.id = id_pbox
   set_attr(lp, attr_icflag, get_attr_icflag(lp))
   while lp ~=last and (lpa>=PACKED) and (lpa<BOXBDD) do
      local lpi = getid(lp)
      if lpa==PACKED then
         if lpi==id_rule then lp = node_next(lp) end
         nc, lp = lp, node_next(lp)
      elseif lpi==id_hlist or lpi==id_vlist then
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

local calc_np_aux_glyph_common
do -- 002 ---------------------------------------
   local min, max = math.min, math.max
   local getwhd = node.direct.getwhd
   local attr_jchar_class = luatexbase.attributes['ltj@charclass']
   local attr_jchar_code = luatexbase.attributes['ltj@charcode']
   local font_getfont = font.getfont
   local function calc_np_notdef(lp)
      if not font_getfont(getfont(lp)).characters[getchar(lp)] then
         local ln = node_next(lp)
         if ltju.specified_feature(getfont(lp), 'notdef') and ln and getid(ln)==id_glyph then 
            set_attr(lp, attr_icflag, PROCESSED)
            set_attr(ln, attr_jchar_code, has_attr(lp, attr_jchar_code) or getchar(lp))
            set_attr(ln, attr_jchar_class, has_attr(lp, attr_jchar_class) or 0)
            Np.nuc, lp = ln, ln
         end
      end
      return lp
   end 
function calc_np_aux_glyph_common(lp, acc_flag)
   Np.nuc, Np.first = lp, (Np.first or lp)
   if if_lang_ja(lp) then -- JAchar
      Np.id = id_jglyph
      local m, mc, cls = set_np_xspc_jachar(Np, lp)
      local npi, npf
      local w, h, d = getwhd(lp)
      if w==0 and h==0 and d==0 then lp = calc_np_notdef(lp) end
      lp, head, npi, npf = capsule_glyph(lp, m, mc[cls], head, tex_dir)
      Np.first = (Np.first~=Np.nuc) and Np.first or npf or npi
      Np.nuc = npi
      return true, check_next_ickern(lp);
   else --ALchar
      Np.id = id_glyph
      set_np_xspc_alchar(Np, getchar(lp), lp, 1)
      -- loop
      local first_glyph, last_glyph = lp
      set_attr(lp, attr_icflag, PROCESSED); Np.last = lp
      local y_adjust = has_attr(lp,attr_ablshift) or 0
      local node_depth = getfield(lp, 'depth') + min(y_adjust, 0)
      local adj_depth = (y_adjust>0) and (getfield(lp, 'depth') + y_adjust) or 0
      setfield(lp, 'yoffset', getfield(lp, 'yoffset') - y_adjust); lp = node_next(lp)
      local lx=lp
      while lx do
         local lai = get_attr_icflag(lx)
         if lx==last or  lai>=PACKED then break
         else
            local lid = getid(lx)
            if lid==id_glyph and not if_lang_ja(lx) then
               -- 欧文文字
               last_glyph = lx; set_attr(lx, attr_icflag, PROCESSED); Np.last = lx
               y_adjust = has_attr(lx,attr_ablshift) or 0
               node_depth = max(getfield(lx, 'depth') + min(y_adjust, 0), node_depth)
               adj_depth = (y_adjust>0) and max(getfield(lx, 'depth') + y_adjust, adj_depth) or adj_depth
               setfield(lx, 'yoffset', getfield(lx, 'yoffset') - y_adjust); lx = node_next(lx)
            elseif lid==id_kern then
               local ls = getsubtype(lx)
               if ls==2 then -- アクセント用の kern
                  set_attr(lx, attr_icflag, PROCESSED)
                  lx = node_next(lx) -- lx: アクセント本体
                  if getid(lx)==id_glyph then
                     setfield(lx, 'yoffset', getfield(lx, 'yoffset') - (has_attr(lx,attr_ablshift) or 0))
                  else -- アクセントは上下にシフトされている
                     setfield(lx, 'shift', getfield(lx, 'shift') + (has_attr(lx,attr_ablshift) or 0))
                  end
                  set_attr(lx, attr_icflag, PROCESSED)
                  lx = node_next(lx); set_attr(lx, attr_icflag, PROCESSED)
                  lx = node_next(lx); set_attr(lx, attr_icflag, PROCESSED)
               elseif ls==0  then
                  Np.last = lx; lx = node_next(lx)
               elseif (ls==3) or (lai==ITALIC) then
                  Np.last = lx; set_attr(lx, attr_icflag, IC_PROCESSED); lx = node_next(lx)
               else break
               end
            else break
            end
         end
      end
      lp=lx
      local r
      if adj_depth>node_depth then
            r = node_new(id_rule,3,first_glyph)
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
               Np.first = acc_flag and Np.first or ((Np.first==npn) and r or npn)
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
end -- 002 ---------------------------------------
local calc_np_auxtable
do  -- 002 ---------------------------------------
local ltjw_apply_ashift_math = ltjw.apply_ashift_math
local ltjw_apply_ashift_disc = ltjw.apply_ashift_disc
local node_end_of_math = node.direct.end_of_math
local dir_tate = luatexja.dir_table.dir_tate
local sid_start_link   = node.subtype 'pdf_start_link'
local sid_start_thread = node.subtype 'pdf_start_thread'
local sid_end_link     = node.subtype 'pdf_end_link'
local sid_end_thread   = node.subtype 'pdf_end_thread'
calc_np_auxtable = {
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
   [id_whatsit] = function(lp)
      local lps = getsubtype(lp)
      if lps==sid_user then
         if getfield(lp, 'user_id')==luatexja.userid_table.IHB then
            local lq = node_next(lp);
            head = node_remove(head, lp); node_free(lp); non_ihb_flag = getfield(lp, 'value')~=1
            return false, lq;
         elseif getfield(lp, 'user_id')==luatexja.userid_table.JA_AL_BDD then
            local lq = node_next(lp);
            head = node_remove(head, lp); node_free(lp)
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
      Np.id = getid(lp); 
      local f = luatexbase.call_callback("luatexja.jfmglue.special_jaglue", lp)
      if f then
         set_attr(lp, attr_icflag, PROCESSED)
      end
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
         if getid(lp)==id_glyph then -- アクセント本体
            setfield(lp, 'yoffset', getfield(lp, 'yoffset') - (has_attr(lp,attr_ablshift) or 0))
         else -- アクセントは上下にシフトされている
            setfield(lp, 'shift', getfield(lp, 'shift') + (has_attr(lp,attr_ablshift) or 0))
         end
         set_attr(lp, attr_icflag, PROCESSED); lp = node_next(lp)
         set_attr(lp, attr_icflag, PROCESSED); lp = node_next(lp)
         set_attr(lp, attr_icflag, PROCESSED);
         return calc_np_aux_glyph_common(lp, true)
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
end -- 002 ---------------------------------------
calc_np_auxtable[id_rule]   = calc_np_auxtable.box_like
calc_np_auxtable[15]        = calc_np_auxtable.box_like

local function calc_np_aux_skip (lp)
   set_attr(lp, attr_icflag, PROCESSED)
   return false, node_next(lp)
end

function calc_np(last, lp)
   local k
   -- We assume lp = node_next(Np.last)
   if Nq and Nq.id==id_pbox_w then
      luatexbase.call_callback("luatexja.jfmglue.whatsit_last_minute", false, Nq, Np)
   end
   Np, Nq, non_ihb_flag = Nq, Np, true
   -- We clear `predefined' entries of Np before pairs() loop,
   -- because using only pairs() loop is slower.
   Np.post, Np.pre, Np.xspc, Np.gk = nil, nil, nil, nil
   Np.first, Np.id, Np.last, Np.met, Np.class= nil, nil, nil, nil
   Np.auto_kspc, Np.auto_xspc, Np.char, Np.nuc = nil, nil, nil, nil
   -- auto_kspc, auto_xspc: normally true/false, 
   -- but the number 0 when Np is ''the beginning of the box/paragraph''.
   for k in pairs(Np) do Np[k] = nil end

   for k = 1,#Bp do Bp[k] = nil end
   while lp ~= last  do
      local lpa = has_attr(lp, attr_icflag) or 0
      -- unbox 由来ノードの検出
      if (lpa>=PACKED) and (lpa%PROCESSED_BEGIN_FLAG<=BOXBDD) then
         if lpa%PROCESSED_BEGIN_FLAG == BOXBDD then
            local lq = node_next(lp)
            head = node_remove(head, lp); node_free(lp); lp = lq
         else
            return calc_np_pbox(lp, last)
         end -- id_pbox
      else
         k, lp = (calc_np_auxtable[getid(lp)] or calc_np_aux_skip)(lp)
         if k then return lp end
      end
   end
   Np=nil
end
end -- 001 -----------------------------------------------

-- extract informations from Np
-- We think that "Np is a Japanese character" if Np.met~=nil,
--            "Np is an alphabetic character" if Np.pre~=nil,
--            "Np is not a character" otherwise.
local after_hlist = nil -- global
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
   local getcomponents = node.direct.getcomponents
   --local ltjf_get_vert_glyph = ltjf.get_vert_glyph
   function set_np_xspc_jachar(Nx, x)
      local m = ltjf_font_metric_table[getfont(x)]
      local c, c_glyph = (not getcomponents(x) and ltjs_orig_char_table[x]), getchar(x)
      if c and c~=c_glyph then set_attr(x, attr_jchar_code, c) end
      c = c or c_glyph
      local cls = slow_find_char_class(c, m, c_glyph)
      Nx.met, Nx.class, Nx.char = m, cls, c;
      local mc = m.char_type; Nx.char_type = mc
      if cls~=0 then set_attr(x, attr_jchar_class, cls) end
      Nx.pre  = table_current_stack[PRE + c]  or 0
      Nx.post = table_current_stack[POST + c] or 0
      Nx.xspc = table_current_stack[XSP  + c] or 3
      Nx.kcat = table_current_stack[KCAT + c] or 0
      Nx.auto_kspc, Nx.auto_xspc = (has_attr(x, attr_autospc)==1), (has_attr(x, attr_autoxspc)==1)
      return m, mc, cls
   end
   function set_np_xspc_jachar_hbox(Nx, x)
      local m = ltjf_font_metric_table[getfont(x)]
      local c = has_attr(x, attr_jchar_code) or getchar(x)
      Nx.met, Nx.char  = m, c; Nx.class = has_attr(x, attr_jchar_class) or 0;
      local mc = m.char_type; Nx.char_type = mc
      Nx.pre  = table_current_stack[PRE + c]  or 0
      Nx.post = table_current_stack[POST + c] or 0
      Nx.xspc = table_current_stack[XSP  + c] or 3
      Nx.kcat = table_current_stack[KCAT + c] or 0
      Nx.auto_kspc, Nx.auto_xspc = (has_attr(x, attr_autospc)==1), (has_attr(x, attr_autoxspc)==1)
   end

-- 欧文文字のデータを取得
   local floor = math.floor
   local nullfunc = function(n) return n end
   function set_np_xspc_alchar(Nx, c,x, lig)
      if c~=-1 then
         local f = (lig ==1) and nullfunc or node_tail
         local xc, xs = getcomponents(x), getsubtype(x)
         while xc and xs and xs%4>=2 do
            x = f(xc);
            if getid(x)==id_disc then x, xc, xs = nil, getfield(x,'replace'), 2
            else xc, xs = getcomponents(x), getsubtype(x) end
         end
         c = x and getchar(x) or c
         Nx.pre  = table_current_stack[PRE + c]  or 0
         Nx.post = table_current_stack[POST + c] or 0
      else
         Nx.pre, Nx.post = 0, 0
      end
      Nx.met = nil
      Nx.xspc = table_current_stack[XSP  + c] or 3
      Nx.auto_xspc = (has_attr(x, attr_autoxspc)==1)
   end
   local set_np_xspc_alchar = set_np_xspc_alchar
   -- change the information for the next loop
   -- (will be done if Nx is an alphabetic character or a hlist)
   after_hlist = function (Nx)
      local s = Nx.last_char
      if s then
         if getid(s)==id_glyph then
            if if_lang_ja(s) then
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

luatexbase.create_callback('luatexja.adjust_jfmglue', 'simple', function(n) return n end)

-- change penalties (or create a new penalty, if needed)
local function handle_penalty_normal(post, pre, g)
   luatexbase.call_callback('luatexja.adjust_jfmglue', head, Nq, Np, Bp)
   local a = (pre or 0) + (post or 0)
   if #Bp == 0 then
      if (a~=0 and not(g and getid(g)==id_kern)) then
         local p = node_new(id_penalty, nil, Nq.nuc, Np.nuc)
         if a<-10000 then a = -10000 elseif a>10000 then a = 10000 end
         setfield(p, 'penalty', a); head = insert_before(head, Np.first, p)
         Bp[1]=p; set_attr(p, attr_icflag, KINSOKU)
      end
   else for _, v in pairs(Bp) do add_penalty(v,a) end
   end
end

local function handle_penalty_always(post, pre, g)
   luatexbase.call_callback('luatexja.adjust_jfmglue', head, Nq, Np, Bp)
   local a = (pre or 0) + (post or 0)
   if #Bp == 0 then
      if not (g and getid(g)==id_glue) or a~=0 then
         local p = node_new(id_penalty, nil, Nq.nuc, Np.nuc)
         if a<-10000 then a = -10000 elseif a>10000 then a = 10000 end
         setfield(p, 'penalty', a); head = insert_before(head, Np.first, p)
         Bp[1]=p; set_attr(p, attr_icflag, KINSOKU)
      end
   else for _, v in pairs(Bp) do add_penalty(v,a) end
   end
end

local function handle_penalty_suppress(post, pre, g)
   luatexbase.call_callback('luatexja.adjust_jfmglue', head, Nq, Np, Bp)
   if #Bp == 0 then
      if g and getid(g)==id_glue then
         local p = node_new(id_penalty, nil, Nq.nuc, Np.nuc)
         setfield(p, 'penalty', 10000); head = insert_before(head, Np.first, p)
         Bp[1]=p; set_attr(p, attr_icflag, KINSOKU)
      end
   else 
      local a = (pre or 0) + (post or 0)
      for _, v in pairs(Bp) do add_penalty(v,a) end
   end
end

local function handle_penalty_jwp()
   local a = table_current_stack[luatexja.stack_table_index.JWP]
   if #widow_Bp == 0 then
      if a~=0 then
         local p = node_new(id_penalty, widow_Np.nuc)
         if a<-10000 then a = -10000 elseif a>10000 then a = 10000 end
         setfield(p, 'penalty', a); head = insert_before(head, widow_Np.first, p)
         widow_Bp[1]=p; set_attr(p, attr_icflag, KINSOKU)
      end
   else for _, v in pairs(widow_Bp) do add_penalty(v,a) end
   end
end

-- 和文文字間の JFM glue を node 化
local function new_jfm_glue(mc, bc, ac)
-- bc, ac: char classes
   local g = mc[bc][ac]
   if g then
       if g[1] then
           return node_copy(g[1]), g.ratio, false, false, false
       else
         local f = node_new(id_glue)
         set_attr(f, attr_icflag, g.priority)
         setglue(f, g.width, g.stretch, g.shrink)
         return f, g.ratio, g.kanjiskip_natural, g.kanjiskip_stretch, g.kanjiskip_shrink
      end
   end
   return false, 0
end

-- Nq.last (kern w) .... (glue/kern g) Np.first
local function real_insert(g)
   if g then
      head, Np.first = insert_before(head, Np.first, node_inherit_attr(g, Nq.nuc, Np.nuc))
      local ngk = Np.gk
      if not ngk then Np.gk = g
      elseif type(ngk)=="table" then ngk[#ngk+1]=g
      else  Np.gk = { ngk, g } end
   end
end


-------------------- 和文文字間空白量の決定
local calc_ja_ja_aux
do
   local round = tex.round
   local bg_ag = 2*id_glue - id_glue
   local bg_ak = 2*id_glue - id_kern
   local bk_ag = 2*id_kern - id_glue
   local bk_ak = 2*id_kern - id_kern

   local function blend_diffmet(b, a, rb, ra)
      return round(luatexja.jfmglue.diffmet_rule((1-rb)*b+rb*a, (1-ra)*b+ra*a))
   end
   local blend_diffmet_inf
   do
      local abs, log, log264, floor = math.abs, math.log, math.log(2)*64, math.floor
      blend_diffmet_inf = function (b, a, bo, ao, rb, ra)
         local nb, na = (bo and b*2.0^(64*bo) or 0), (ao and a*2.0^(64*ao) or 0)
         local r = luatexja.jfmglue.diffmet_rule((1-rb)*nb+rb*na, (1-ra)*nb+ra*na)
         local ro = (r~=0) and floor(log(abs(r))/log264+0.0625) or 0
         return round(r/2.^(64*ro)), ro
      end
   end
   local getglue = luatexja.getglue
   calc_ja_ja_aux = function (gb, ga, db, da)
      if luatexja.jfmglue.diffmet_rule ~= math.two_pleft and diffmet_rule ~= math.two_pright
          and luatexja.jfmglue.diffmet_rule ~= math.two_paverage then
         db, da = 0, 1
      end
      if not gb then
         if ga then gb = node_new(id_kern, 1); setfield(gb, 'kern', 0)
         else return nil end
      elseif not ga then
         ga = node_new(id_kern, 1); setfield(ga, 'kern', 0)
      end
      local gbw, gaw, gbst, gast, gbsto, gasto, gbsh, gash, gbsho, gasho
      if getid(gb)==id_glue then
         gbw, gbst, gbsh, gbsto, gbsho = getglue(gb)
      else
         gbw = getfield(gb, 'kern')
      end
      if getid(ga)==id_glue then
         gaw, gast, gash, gasto, gasho = getglue(ga)
      else
         gaw = getfield(ga, 'kern')
      end
      if not (gbst or gast) then -- 両方とも kern
         setfield(gb, 'kern', blend_diffmet(gbw, gaw, db, da))
         node_free(ga); return gb
      else
         local gr = gb
         if not gbst then gr = ga; node_free(gb) else node_free(ga) end
         gbw = blend_diffmet(gbw or 0, gaw or 0, db, da) -- 結果の自然長
         gbst, gbsto = blend_diffmet_inf(gbst, gast, gbsto, gasto, db, da) -- 伸び
         gbsh, gbsho = blend_diffmet_inf(-(gbsh or 0), -(gash or 0), gbsho, gasho, db, da) -- -(縮み)
         setglue(gr, gbw, gbst, -gbsh, gbsto, gbsho)
         return gr
      end
   end
end

local null_skip_table = {0, 0, 0}
-- get kanjiskip
local get_kanjiskip, kanjiskip_jfm_flag
local get_kanjiskip_low
local calc_ja_ja_glue
do
   local KANJI_SKIP   = luatexja.icflag_table.KANJI_SKIP
   local KANJI_SKIP_JFM   = luatexja.icflag_table.KANJI_SKIP_JFM

   get_kanjiskip_low = function(flag, qm, bn, bp, bh)
   -- flag = false: kanjiskip そのもの（パラメータ or JFM）
   --               ノード kanji_skip のコピーで良い場合は nil が帰る
   -- flag = true: JFM グルーに付随する kanjiskip 自然長/伸び/縮み分
      if qm.with_kanjiskip and (bn or bp or bh) then
         if kanjiskip_jfm_flag then
            local g = node_new(id_glue);
            local bk = qm.kanjiskip or null_skip_table
            setglue(g, bn and (bn*bk[1]) or 0, 
                       bp and (bp*bk[2]) or 0, 
                       bh and (bh*bk[3]) or 0, 0, 0)
            set_attr(g, attr_icflag, KANJI_SKIP_JFM)
            return g
         elseif flag then
            local g = node_new(id_glue)
            local st = bp and (bp*getfield(kanji_skip, 'stretch')) or 0
            local sh = bh and (bh*getfield(kanji_skip, 'shrink')) or 0
            setglue(g,
               bn and (bn*getfield(kanji_skip, 'width')) or 0,
               st, sh, 
               (st==0) and 0 or getfield(kanji_skip, 'stretch_order'),
               (sh==0) and 0 or getfield(kanji_skip, 'shrink_order'))
            set_attr(g, attr_icflag, KANJI_SKIP_JFM)
            return g
         end
      end
   end
   
   get_kanjiskip = function()
      if Np.auto_kspc==0 or Nq.auto_kspc==0 then return nil 
      elseif Np.auto_kspc or Nq.auto_kspc then
         local pm, qm = Np.met, Nq.met
         if (pm.char_type==qm.char_type) and (qm.var==pm.var) then
             return get_kanjiskip_low(false, qm, 1, 1, 1) or node_copy(kanji_skip)
         else
            local gb = get_kanjiskip_low(false, qm, 1, 1, 1)
            if gb then
               return calc_ja_ja_aux(gb, 
                 get_kanjiskip_low(false, pm, 1, 1, 1) or node_copy(kanji_skip), 0, 1) 
            else
               local ga = get_kanjiskip_low(false, pm, 1, 1, 1)
               return (ga and calc_ja_ja_aux(node_copy(kanji_skip), ga, 0, 1))
                 or node_copy(kanji_skip)
            end
         end
      else   
         local g = node_new(id_glue)
         set_attr(g, attr_icflag, kanjiskip_jfm_flag and KANJI_SKIP_JFM or KANJI_SKIP)
         return g
      end
   end

   calc_ja_ja_glue = function ()
      local qm, pm = Nq.met, Np.met
      local qmc, pmc = qm.char_type, pm.char_type
      if (qmc==pmc) and (qm.var==pm.var) then
         local g, _, kn, kp, kh = new_jfm_glue(qmc, Nq.class, Np.class)
         return g, (Np.auto_kspc or Nq.auto_kspc) and get_kanjiskip_low(true, qm, kn, kp, kh)
      else
         local npn, nqn = Np.nuc, Nq.nuc
         local gb, db, bn, bp, bh 
            = new_jfm_glue(qmc, Nq.class,
                           slow_find_char_class(Np.char,
                                                qm, getchar(npn)))
         local ga, da, an, ap, ah 
            = new_jfm_glue(pmc,
                           slow_find_char_class(Nq.char,
                                                pm, getchar(nqn)),
                           Np.class)
         local g = calc_ja_ja_aux(gb, ga, db, da)
         local k
         gb = get_kanjiskip_low(true, qm, bn, bp, bh)
         ga = get_kanjiskip_low(true, pm, an, ap, ah)
         k = calc_ja_ja_aux(gb, ga, db, da)
         return g, k
      end
   end
end

-------------------- 和欧文間空白量の決定

-- get xkanjiskip
local get_xkanjiskip, xkanjiskip_jfm_flag
local get_xkanjiskip_normal, get_xkanjiskip_jfm
local get_xkanjiskip_low
do
   local XKANJI_SKIP   = luatexja.icflag_table.XKANJI_SKIP
   local XKANJI_SKIP_JFM   = luatexja.icflag_table.XKANJI_SKIP_JFM

   get_xkanjiskip_low = function(flag, qm, bn, bp, bh)
      if flag or (qm.with_kanjiskip and (bn or bp or bh)) then
         if xkanjiskip_jfm_flag then
            local g = node_new(id_glue);
            local bk = qm.xkanjiskip or null_skip_table
            setglue(g, bn and bk[1] or 0,
                       bp and bk[2] or 0,
                       bh and bk[3] or 0, 0, 0)
            set_attr(g, attr_icflag, XKANJI_SKIP_JFM)
            return g
         elseif flag then
            return node_copy(xkanji_skip)
         else
            local g = node_new(id_glue);
            setglue(g,
               bn and (bn*getfield(xkanji_skip, 'width')) or 0,
               bp and (bp*getfield(xkanji_skip, 'stretch')) or 0,
               bh and (bh*getfield(xkanji_skip, 'shrink')) or 0,
               bp and getfield(xkanji_skip, 'stretch_order') or 0,
               bh and getfield(xkanji_skip, 'shrink_order') or 0)
            set_attr(g, attr_icflag, XKANJI_SKIP_JFM)
            return g
         end
      end
   end
   
   get_xkanjiskip = function(Nn)
      if Np.auto_xspc==0 or Nq.auto_xspc==0 then
        return nil 
      elseif (Nq.xspc>=2) and (Np.xspc%2==1) and (Nq.auto_xspc or Np.auto_xspc) then
         return get_xkanjiskip_low(true, Nn.met, 1, 1, 1)
      else
         local g = node_new(id_glue)
         set_attr(g, attr_icflag, xkanjiskip_jfm_flag and XKANJI_SKIP_JFM or XKANJI_SKIP)
         return g
      end
   end
end

-------------------- 隣接した「塊」間の処理

local function combine_spc(name)
   return (Np[name] or Nq[name]) and ((Np[name]~=0) and (Nq[name]~=0))
end

-- NA, NB: alchar or math
local function get_NA_skip()
   local pm = Np.met
   local g, _, kn, kp, kh = new_jfm_glue(
      pm.char_type,
      fast_find_char_class(
        (Nq.id == id_math and -1 or (Nq.xspc>=2 and 'alchar' or 'nox_alchar')), pm), 
      Np.class)
   local k = ((Nq.xspc>=2) and (Np.xspc%2==1) and combine_spc 'auto_xspc')
       and get_xkanjiskip_low(false, pm, kn, kp, kh)
   return g, k
end
local function get_NB_skip()
   local qm = Nq.met
   local g, _, kn, kp, kh = new_jfm_glue(
      qm.char_type, Nq.class,
      fast_find_char_class(
        (Np.id == id_math and -1 or (Np.xspc%2==1 and 'alchar' or 'nox_alchar')), qm)
    )
   local k = ((Nq.xspc>=2) and (Np.xspc%2==1) and combine_spc 'auto_xspc')
         and get_xkanjiskip_low(false, qm, kn, kp, kh)
   return g, k
end

local function get_OA_skip(insert_ksp)
   local pm = Np.met
   local g, _, kn, kp, kh = new_jfm_glue(
      pm.char_type,
      fast_find_char_class(
        (((Nq.id==id_glue)or(Nq.id==id_kern)) and 'glue' or 'jcharbdd'), pm), 
      Np.class)
   local k
   if insert_ksp then
      k = (combine_spc 'auto_kspc') and get_kanjiskip_low(true, pm, kn, kp, kh)
   end
   return g, k
end
local function get_OB_skip(insert_ksp)
   local qm = Nq.met
   local g, _, kn, kp, kh = new_jfm_glue(
      qm.char_type, Nq.class,
      fast_find_char_class(
        (((Np.id==id_glue)or(Np.id==id_kern)) and 'glue' or 'jcharbdd'), qm))
   local k
   if insert_ksp then
      k = (combine_spc 'auto_kspc') and get_kanjiskip_low(true, qm, kn, kp, kh)
   end
   return g, k
end

-- (anything) .. jachar
local function handle_np_jachar(mode)
   local qid = Nq.id
   if qid==id_jglyph or ((qid==id_pbox or qid==id_pbox_w) and Nq.met) then
      local g, k
      if non_ihb_flag then g, k = calc_ja_ja_glue() end -- M->K
      if not g then g = get_kanjiskip() end
      handle_penalty_normal(Nq.post, Np.pre, g); 
      real_insert(g); real_insert(k)
   elseif Nq.met then  -- qid==id_hlist
      local g, k
      if non_ihb_flag then g, k = get_OA_skip(true) end -- O_A->K
      if not g then g = get_kanjiskip() end
      handle_penalty_normal(0, Np.pre, g); real_insert(g); real_insert(k)
   elseif Nq.pre then
      local g, k
      if non_ihb_flag then g, k = get_NA_skip() end -- N_A->X
      if not g then g = get_xkanjiskip(Np) end
      handle_penalty_normal((qid==id_hlist and 0 or Nq.post), Np.pre, g); 
      real_insert(g); real_insert(k)
   else
      local g = non_ihb_flag and (get_OA_skip()) -- O_A
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
      local g = non_ihb_flag and get_NB_skip() or get_xkanjiskip(Nq) -- N_B->X
      handle_penalty_normal(Nq.post, (Np.id==id_hlist and 0 or Np.pre), g); real_insert(g)
   else
      local g =non_ihb_flag and  (get_OB_skip()) -- O_B
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
   if qid==id_jglyph or ((qid==id_pbox or qid == id_pbox_w) and Nq.met) then
      local g = non_ihb_flag and get_OB_skip(true) or get_kanjiskip() -- O_B->K
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
local adjust_nq
do
   local adjust_nq_aux = {
      [id_glyph] = function() after_alchar(Nq) end, -- after_alchar(Nq)
      [id_hlist] = function() after_hlist(Nq) end,
      [id_pbox]  = function() after_hlist(Nq) end,
      [id_disc]  = function() after_hlist(Nq) end,
      [id_glue]  = function() 
                      luatexbase.call_callback("luatexja.jfmglue.special_jaglue_after", Nq.nuc)
                   end,
      [id_pbox_w]= function()
                      luatexbase.call_callback("luatexja.jfmglue.whatsit_after", false, Nq, Np)
                   end,
   }

   adjust_nq = function()
      local x = adjust_nq_aux[Nq.id]
      if x then x()  end
   end
end


-------------------- 開始・終了時の処理
do
local node_prev = node.direct.getprev
-- リスト末尾の処理
local function handle_list_tail(mode, last)
   adjust_nq()
   if mode then
      -- the current list is to be line-breaked.
      -- Insert \jcharwidowpenalty
      if widow_Np.first then handle_penalty_jwp() end
   else
      Np = Nq          
      -- the current list is the contents of a hbox
      local npi, pm = Np.id, Np.met
      if npi == id_jglyph or (npi==id_pbox and pm) then
         local g = new_jfm_glue(pm.char_type, Np.class, fast_find_char_class('boxbdd', pm))
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
   if npi == id_jglyph or (npi==id_pbox and pm) then
      if non_ihb_flag then
         local g = new_jfm_glue(pm.char_type, fast_find_char_class(par_indented, pm), Np.class)
         if g then
            set_attr(g, attr_icflag, BOXBDD)
            if getid(g)==id_glue and #Bp==0 then
               local h = node_new(id_penalty, nil, Np.nuc)
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
   local id_local = node.id 'local_par'
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
        post=nil, pre=nil, xspc=nil, gk=nil }, 
      { auto_kspc=nil, auto_xspc=nil, char=nil, class=nil,
        first=nil, id=nil, last=nil, met=nil, nuc=nil,
        post=nil, pre=nil, xspc=nil, gk=nil },
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
          kanji_skip, kanjiskip_jfm_flag = skip_table_to_glue(KSK)
          set_attr(kanji_skip, attr_icflag, KANJI_SKIP)
      end

      do
          xkanji_skip, xkanjiskip_jfm_flag = skip_table_to_glue(XSK)
          set_attr(xkanji_skip, attr_icflag, XKANJI_SKIP)
      end

      if mode then
         -- the current list is to be line-breaked:
         -- hbox from \parindent is skipped.
         local lp, par_indented, lpi, lps  = head, 'boxbdd', getid(head), getsubtype(head)
         while lp and 
            ((lpi==id_whatsit and lps~=sid_user)
               or ((lpi==id_hlist) and (lps==3))
               or (lpi==id_local)) do
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

-------------------- 外部から呼ばれる関数

local ensure_tex_attr = ltjb.ensure_tex_attr
local tex_getattr = tex.getattribute
-- main interface
function luatexja.jfmglue.main(ahead, mode, dir)
   if not ahead then return ahead end
   head = ahead;
   local lp, last, par_indented, TEMP = init_var(mode,dir)
   lp = calc_np(last, lp)
   if Np then
      handle_list_head(par_indented)
      lp = calc_np(last,lp); 
      while Np do
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
      handle_list_tail(mode, last)
   end
   -- adjust attr_icflag for avoiding error
   if tex_getattr(attr_icflag)~=0 then ensure_tex_attr(attr_icflag, 0) end
   node_free(kanji_skip); 
   node_free(xkanji_skip); node_free(TEMP)
   return head
end
end

do
   local IHB  = luatexja.userid_table.IHB 
   local BPAR = luatexja.userid_table.BPAR
   local BOXB = luatexja.userid_table.BOXB
   local node_prev = node.direct.getprev
   local node_write = node.direct.write

   -- \inhibitglue, \disinhibitglue
   local function ihb_node(v)
      local tn = node_new(id_whatsit, sid_user)
      setfield(tn, 'user_id', IHB)
      setfield(tn, 'type', 100)
      setfield(tn, 'value', v)
      node_write(tn)
   end
   function luatexja.jfmglue.create_inhibitglue_node()
      ihb_node(1)
   end
   function luatexja.jfmglue.create_disinhibitglue_node()
      ihb_node(0)
   end

   -- Node for indicating beginning of a paragraph
   -- (for ltjsclasses)
   function luatexja.jfmglue.create_beginpar_node()
      local tn = node_new(id_whatsit, sid_user)
      setfield(tn, 'user_id', BPAR)
      setfield(tn, 'type', 100)
      setfield(tn, 'value', 1)
      node_write(tn)
   end

   -- Node for indicating a head/end of a box
   function luatexja.jfmglue.create_boxbdd_node()
      local tn = node_new(id_whatsit, sid_user)
      setfield(tn, 'user_id', BOXB)
      setfield(tn, 'type', 100)
      setfield(tn, 'value', 1)
      node_write(tn)
   end

   local function whatsit_callback(Np, lp, Nq)
      if Np and Np.nuc then return Np
      elseif Np and getfield(lp, 'user_id') == BPAR then
         Np.first = lp; Np.nuc = lp; Np.last = lp
         return Np
      elseif Np and getfield(lp, 'user_id') == BOXB then
         Np.first = lp; Np.nuc = lp; Np.last = lp
         if Nq then
            if Nq.met then
               Np.class = fast_find_char_class('boxbdd', Nq.met)
            end
            Np.met = Nq.met; Np.pre = 0; Np.post = 0; Np.xspc = 0
            Np.auto_xspc, Np.auto_kspc = 0, 0
         end         
         return Np
      else
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
            Nq.auto_xspc, Nq.auto_kspc = 0, 0
         end
         head = node_remove(head, y)
         node_free(y)
       elseif not s and getfield(Nq.nuc, 'user_id') == BOXB then
         local x, y = node_prev(Nq.nuc), Nq.nuc
         Nq.first, Nq.nuc, Nq.last = x, x, x
         if Np then
            if Np.met then
               Nq.class = fast_find_char_class('boxbdd', Np.met)
            end
            Nq.met = Np.met; Nq.pre = 0; Nq.post = 0; Nq.xspc = 0
            Nq.auto_xspc, Nq.auto_kspc = 0, 0
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

do
   local node_prev = node.direct.getprev
   local node_write = node.direct.write
   local XKANJI_SKIP   = luatexja.icflag_table.XKANJI_SKIP
   local XKANJI_SKIP_JFM   = luatexja.icflag_table.XKANJI_SKIP_JFM
   local KANJI_SKIP   = luatexja.icflag_table.KANJI_SKIP
   local KANJI_SKIP_JFM   = luatexja.icflag_table.KANJI_SKIP_JFM
   local XSK  = luatexja.stack_table_index.XSK
   local KSK  = luatexja.stack_table_index.KSK
   local attr_yablshift = luatexbase.attributes['ltj@yablshift']
   local attr_tablshift = luatexbase.attributes['ltj@tablshift']
   local getcount, abs, scan_keyword = tex.getcount, math.abs, token.scan_keyword
   local get_current_jfont
   do
       local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
       local attr_curtfnt = luatexbase.attributes['ltj@curtfnt']
       local dir_tate = luatexja.dir_table.dir_tate
       local get_dir_count = ltjd.get_dir_count        
       function get_current_jfont()
           return tex.getattribute((get_dir_count()==dir_tate) and attr_curtfnt or attr_curjfnt)
       end
   end
   -- \insertxkanjiskip
   -- SPECIAL_JAGLUE のノード：
   -- * (X)KANJI_SKIP(_JFM): その場で値が決まっている
   -- * PROCESSED_BEGIN_FLAG + (X)KANJI_SKIP: 段落終了時に決める
   local function insert_k_skip_common(ind, name, ica, icb)
       if abs(tex.nest[tex.nest.ptr].mode) ~= ltjs.hmode then return end
       local g = node_new(id_glue); set_attr(g, attr_icflag, SPECIAL_JAGLUE)
       local is_late = scan_keyword("late")
       if not is_late then
           local st = ltjs.get_stack_skip(ind, getcount('ltj@@stack'))
           if st.width==1073741823 then
               local bk = ltjf_font_metric_table[get_current_jfont()][name]
               if bk then
                   setglue(g, bk[1] or 0, bk[2] or 0, bk[3] or 0, 0, 0)
               end
               set_attr(g, attr_yablshift, icb); node_write(g); return
           end
           setglue(g, st.width, st.stretch, st.shrink, st.stretch_order, st.shrink_order)
           set_attr(g, attr_yablshift, ica)
       else
           set_attr(g, attr_yablshift, PROCESSED_BEGIN_FLAG + ica)
           set_attr(g, attr_tablshift, get_current_jfont())               
       end
       node_write(g)
   end
   function luatexja.jfmglue.insert_xk_skip()
       insert_k_skip_common(XSK, "xkanjiskip", XKANJI_SKIP, XKANJI_SKIP_JFM)
   end
   function luatexja.jfmglue.insert_k_skip()
       insert_k_skip_common(KSK, "kanjiskip", KANJI_SKIP, KANJI_SKIP_JFM)
   end
   -- callback
   local getglue = luatexja.getglue
   local function special_jaglue(lx)
       local lxi = get_attr_icflag(lx)
       if lxi==SPECIAL_JAGLUE then
           non_ihb_flag = false; return false
       else
           return lx
       end
   end
   local function special_jaglue_after_inner(lx, lxi, lxi_jfm, kn, bk)
       local w, st, sh, sto, sho = getglue(kn)
       if w~=1073741823 then
           setglue(lx, w, st, sh, sto, sho); set_attr(lx, attr_icflag, lxi)
       else
           local m = ltjf_font_metric_table[has_attr(lx, attr_tablshift)]
           setglue(lx, bk[1], bk[2], bk[3], 0, 0)
           set_attr(lx, attr_icflag, lxi_jfm)
       end
   end
   local function special_jaglue_after(lx)
       if get_attr_icflag(lx)==SPECIAL_JAGLUE then
           lxi=has_attr(lx, attr_yablshift)
           if lxi>=PROCESSED_BEGIN_FLAG then
               lxi = lxi%PROCESSED_BEGIN_FLAG
               if lxi == KANJI_SKIP then
                   special_jaglue_after_inner(lx, lxi, KANJI_SKIP_JFM, kanji_skip, 
                     ltjf_font_metric_table[has_attr(lx, attr_tablshift)].kanjiskip or null_skip_table)
               else --  lxi == XKANJI_SKIP
                   special_jaglue_after_inner(lx, lxi, XKANJI_SKIP_JFM, xkanji_skip, 
                     ltjf_font_metric_table[has_attr(lx, attr_tablshift)].xkanjiskip or null_skip_table)
               end
           else
               set_attr(lx, attr_icflag, lxi)
           end
           Np.first = lx
           if node_prev(lx) then
               local lxp = node_prev(lx)
               if lxp and getid(lxp)==id_penalty and get_attr_icflag(lxp)==KINSOKU then
                   Bp[#Bp+1]=lxp
               end
           end
           non_ihb_flag = false; return false
       end
       return true
   end
   luatexbase.create_callback("luatexja.jfmglue.special_jaglue", "list",
                              special_jaglue)
   luatexbase.create_callback("luatexja.jfmglue.special_jaglue_after", "list",
                              special_jaglue_after)
end


luatexja.jfmglue.after_hlist = after_hlist
luatexja.jfmglue.check_box_high = check_box_high
