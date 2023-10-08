require 'lualibs'
------------------------------------------------------------------------
do
  local ipath = {}
  function luatexja.input_path_clear() for i in ipairs(ipath) do ipath[i]=nil end end
  function luatexja.input_path_add(s) ipath[#ipath+1]=s end
  function luatexja.load_lua(fn)
    local found = kpse.find_file(fn, 'tex')
    if not found then
      for _,v in ipairs(ipath) do
        found = kpse.find_file(v .. fn, 'tex'); if found then break end
      end
    end
    if not found then
      tex.error("LuaTeX-ja error: File `" .. fn .. "' not found")
    else
      texio.write_nl('(' .. found .. ')'); dofile(found)
    end
  end
end
function luatexja.load_module(name) require('ltj-' .. name.. '.lua') end

do
    local dnode = node.direct
    local getfield, traverse = dnode.getfield, dnode.traverse
    local node_new, set_attr, get_attr = dnode.new, dnode.set_attribute, dnode.get_attribute
    local set_attrlist, get_attrlist = dnode.setattributelist, dnode.getattributelist
    local unset_attr = dnode.unset_attribute
    local attr_icflag = luatexbase.attributes['ltj@icflag']
    local function node_inherit_attr(n, b, a)
        if b or a then
            local attrlist = get_attrlist(b or a)
            local nic = get_attr(n, attr_icflag)
            set_attrlist(n, attrlist); set_attr(n, attr_icflag, nic)
            if b and a then
                for na in traverse(attrlist) do
                    local id = getfield(na, 'number')
                    if id and id~=attr_icflag and getfield(na, 'value')~=get_attr(a, id) then
                        unset_attr(n, id)
                    end
                end
            end
        end
        return n
    end
    luatexja.node_inherit_attr = node_inherit_attr
    luatexja.dnode_new = function (id, subtype, b, a)
        return node_inherit_attr(node_new(id, subtype), b, a)
    end
end

--- 以下は全ファイルで共有される定数
local icflag_table = {}
luatexja.icflag_table = icflag_table
icflag_table.ITALIC          = 1
icflag_table.PACKED          = 2
icflag_table.KINSOKU         = 3
icflag_table.FROM_JFM        = 4
icflag_table.KANJI_SKIP      = 68 -- = 4+64
icflag_table.KANJI_SKIP_JFM  = 69
icflag_table.XKANJI_SKIP     = 70
icflag_table.XKANJI_SKIP_JFM = 71
icflag_table.LINEEND         = 72
icflag_table.PROCESSED       = 73
icflag_table.IC_PROCESSED    = 74
icflag_table.BOXBDD          = 75
icflag_table.SPECIAL_JAGLUE  = 76
-- 段落組版中のノードリストでは通常のノード (not whatsit) だが
-- 和文処理グルー挿入プロセスで長さが決定されるもの
icflag_table.PROCESSED_BEGIN_FLAG = 4096 -- sufficiently large power of 2

local stack_ind = {}
luatexja.stack_table_index = stack_ind
stack_ind.PRE  = 0x200000 -- characterごと
stack_ind.POST = 0x400000 -- characterごと
stack_ind.KCAT = 0x600000 -- characterごと
stack_ind.XSP  = 0x800000 -- characterごと
stack_ind.RIPRE  = 0xA00000 -- characterごと，ruby pre
stack_ind.RIPOST = 0xC00000 -- characterごと，ruby post
stack_ind.JWP  = 0 -- これだけ
stack_ind.KSK  = 1 -- これだけ
stack_ind.XSK  = 2 -- これだけ
stack_ind.MJT  = 0x100 -- 0--255
stack_ind.MJS  = 0x200 -- 0--255
stack_ind.MJSS = 0x300 -- 0--255
stack_ind.KSJ  = 0x400 -- 0--9

local uid_table = {}
luatexja.userid_table = uid_table
uid_table.IHB  = luatexbase.newuserwhatsitid('inhibitglue',  'luatexja') -- \inhibitglue
uid_table.STCK = luatexbase.newuserwhatsitid('stack_marker', 'luatexja') -- スタック管理
uid_table.BPAR = luatexbase.newuserwhatsitid('begin_par',    'luatexja') -- 「段落始め」
uid_table.DIR  = luatexbase.newuserwhatsitid('direction',    'luatexja') -- 組方向
uid_table.BOXB = luatexbase.newuserwhatsitid('box_boundary', 'luatexja') -- 「ボックス始め・終わり」
uid_table.JA_AL_BDD = luatexbase.newuserwhatsitid('ja_al_boundary', 'luatexja')

local dir_table = {}
luatexja.dir_table = dir_table
dir_table.dir_dtou = 1
dir_table.dir_tate = 3
dir_table.dir_yoko = 4
dir_table.dir_math_mod    = 8
dir_table.dir_node_auto   = 128 -- 組方向を合わせるために自動で作られたもの
dir_table.dir_node_manual = 256 -- 寸法代入によって作られたもの
dir_table.dir_utod = dir_table.dir_tate + dir_table.dir_math_mod
  -- 「縦数式ディレクション」 in pTeX
--- 定義終わり

local load_module = luatexja.load_module
load_module 'base';      local ltjb = luatexja.base
if tex.outputmode==0 then
  ltjb.package_error('luatexja',
    'DVI output is not supported in LuaTeX-ja',
    'Use lua*tex instead dvilua*tex.')
end
load_module 'rmlgbm';    local ltjr = luatexja.rmlgbm -- must be 1st
if luatexja_debug then load_module 'debug' end
load_module 'lotf_aux';  local ltju = luatexja.lotf_aux
load_module 'charrange'; local ltjc = luatexja.charrange
load_module 'stack';     local ltjs = luatexja.stack
load_module 'direction'; local ltjd = luatexja.direction -- +1 hlist +1 attr_list
load_module 'lineskip';  local ltjl = luatexja.lineskip -- +1 hlist +1 attr_list
load_module 'jfont';     local ltjf = luatexja.jfont
load_module 'inputbuf';  local ltji = luatexja.inputbuf
load_module 'pretreat';  local ltjp = luatexja.pretreat
load_module 'setwidth';  local ltjw = luatexja.setwidth
load_module 'jfmglue';   local ltjj = luatexja.jfmglue -- +1 glue +1 gs +1 attr_list
load_module 'math';      local ltjm = luatexja.math
load_module 'base';      local ltjb = luatexja.base

local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_jchar_code = luatexbase.attributes['ltj@charcode']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_yablshift = luatexbase.attributes['ltj@yablshift']
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_uniqid = luatexbase.attributes['ltj@uniqid']
local attr_dir = luatexbase.attributes['ltj@dir']
local cat_lp = luatexbase.catcodetables['latex-package']

-- Three aux. functions, borrowed from tex.web

local floor = math.floor
local function print_scaled(s)
   local out, delta = '', 10
   if s<0 then s, out = -s, out..'-' end
   out=out..tostring(floor(s/65536)) .. '.'
   s=10*(s%65536)+5
   repeat
      if delta>65536 then s=s+32768-50000 end
      out=out .. tostring(floor(s/65536))
      s=10*(s%65536); delta=delta*10
   until s<=delta
   return out
end
luatexja.print_scaled = print_scaled

local function print_glue(d,order)
   local out=print_scaled(d)
   if order>0 then
      out=out..'fi'
      while order>1 do out=out..'l'; order=order-1 end
   else out=out..'pt'
   end
   return out
end

local function print_spec(p)
   local out=print_scaled(p.width or p[1])..'pt'
   if (p.stretch or p[2])~=0 then
      out=out..' plus '..print_glue(p.stretch or p[2], p.stretch_order or p[4])
   end
   if (p.shrink or p[3])~=0 then
      out=out..' minus '..print_glue(p.shrink or p[3], p.shrink_order or p[5])
   end
return out
end


------------------------------------------------------------------------
-- CODE FOR GETTING/SETTING PARAMETERS
------------------------------------------------------------------------
local getcount, texwrite = tex.getcount, tex.write
local cnt_stack = luatexbase.registernumber 'ltj@@stack'

-- EXT: print parameters that don't need arguments
do
   local tex_getattr, getnest = tex.getattribute, tex.getnest
   local function getattr(a, d)
      local r = tex_getattr(a); d = d or 0
      return (r==-0x7FFFFFFF) and d or r
   end
   luatexja.unary_pars = {
      yalbaselineshift = function(t)
         return print_scaled(getattr('ltj@yablshift'))..'pt'
      end,
      yjabaselineshift = function(t)
         return print_scaled(getattr('ltj@ykblshift'))..'pt'
      end,
      talbaselineshift = function(t)
         return print_scaled(getattr('ltj@tablshift'))..'pt'
      end,
      tjabaselineshift = function(t)
         return print_scaled(getattr('ltj@tkblshift'))..'pt'
      end,
      kanjiskip = function(t)
         return print_spec(ltjs.get_stack_skip(stack_ind.KSK, t))
      end,
      xkanjiskip = function(t)
         return print_spec(ltjs.get_stack_skip(stack_ind.XSK, t))
      end,
      jcharwidowpenalty = function(t)
         return ltjs.get_stack_table(stack_ind.JWP, 0, t)
      end,
      autospacing = function(t)
         return getattr('ltj@autospc', 1)
      end,
      autoxspacing = function(t)
         return getattr('ltj@autoxspc', 1)
      end,
      differentjfm = function(t)
         local f, r = luatexja.jfmglue.diffmet_rule, '???'
         if f == math.max then r = 'large'
         elseif f == math.min then r = 'small'
         elseif f == math.two_average then r = 'average'
         elseif f == math.two_paverage then r = 'paverage'
         elseif f == math.two_pleft then r = 'pleft'
         elseif f == math.two_pright then r = 'pright'
         elseif f == math.two_add then r = 'both'
         end
         return r
      end,
      direction = function()
         local v = ltjd.get_dir_count()
         if math.abs(getnest().mode) == ltjs.mmode and v == dir_table.dir_tate then
            v = dir_table.dir_utod
         end
         return v
      end,
      adjustdir = ltjd.get_adjust_dir_count,
   }

   local unary_pars = luatexja.unary_pars
   local scan_arg = token.scan_argument
   function luatexja.ext_get_parameter_unary()
      local k= scan_arg()
      if unary_pars[k] then
         texwrite(tostring(unary_pars[k](getcount(cnt_stack))))
      end
      ltjb.stop_time_measure 'get_par'
   end
end


-- EXT: print parameters that need arguments
do
   luatexja.binary_pars = {
      jacharrange = function(c, t)
         if type(c)~='number' or c<-1 or c>31*ltjc.ATTR_RANGE then
            -- 0, -1 はエラーにしない（隠し）
            ltjb.package_error('luatexja',
                               'invalid character range number (' .. tostring(c) .. ')',
                               'A character range number should be in the range 1..'
                               .. 31*ltjc.ATTR_RANGE .. ",\n"..
                               'So I changed this one to ' .. 31*ltjc.ATTR_RANGE .. ".")
            c=0 -- external range 217 == internal range 0
         elseif c==31*ltjc.ATTR_RANGE then c=0
         end
         -- 負の値は <U+0080 の文字の文字範囲，として出てくる．この時はいつも欧文文字なので 1 を返す
         if c<0 then return 1 else return (ltjc.get_range_setting(c)==0) and 0 or 1 end
      end,
      prebreakpenalty = function(c, t)
         return ltjs.get_stack_table(stack_ind.PRE + ltjb.in_unicode(c, true), 0, t)
      end,
      postbreakpenalty = function(c, t)
         return ltjs.get_stack_table(stack_ind.POST + ltjb.in_unicode(c, true), 0, t)
      end,
      kcatcode = function(c, t)
         return ltjs.get_stack_table(stack_ind.KCAT + ltjb.in_unicode(c, false), 0, t)
      end,
      chartorange = function(c, t)
         return ltjc.char_to_range(ltjb.in_unicode(c, false))
      end,
      jaxspmode = function(c, t)
         return ltjs.get_stack_table(stack_ind.XSP + ltjb.in_unicode(c, true), 3, t)
      end,
      boxdir = function(c, t)
         if type(c)~='number' or c<0 or c>65535 then
            ltjb.package_error('luatexja',
                               'Bad register code (' .. tostring(c) .. ')',
                               'A register must be between 0 and 65535.\n'..
                               'I changed this one to zero.')
            c=0
         end
         return ltjd.get_register_dir(c)
      end,
   }
   local binary_pars = luatexja.binary_pars
   local scan_arg, scan_int = token.scan_argument, token.scan_int
   binary_pars.alxspmode = binary_pars.jaxspmode
   function luatexja.ext_get_parameter_binary(k, c)
      if binary_pars[k] then
         texwrite(tostring(binary_pars[k](c, getcount(cnt_stack))))
      end
      ltjb.stop_time_measure 'get_par'
   end
end

-- EXT: print \global if necessary
function luatexja.ext_print_global()
   if luatexja.isglobal=='global' then tex.sprint(cat_lp, '\\global') end
end


-- main process
do
   local start_time_measure, stop_time_measure
      = ltjb.start_time_measure, ltjb.stop_time_measure
   local nullfunc = function (n) return n end
   local to_node = node.direct.tonode
   local to_direct = node.direct.todirect
   local ensure_tex_attr = ltjb.ensure_tex_attr
   local slide = node.slide
   -- mode = true iff main_process is called from pre_linebreak_filter
   local function main_process(head, mode, dir, gc)
      ensure_tex_attr(attr_icflag, 0)
      if gc == 'fin_row' then return head
      else
            start_time_measure 'jfmglue'
            slide(head);
            local p = ltjj.main(to_direct(head),mode, dir)
            stop_time_measure 'jfmglue'
            return to_node(p)
      end
   end

   local function adjust_icflag(h)
      -- kern from luaotfload will have icflag = 1
      -- (same as italic correction)
      ensure_tex_attr(attr_icflag, 1)
      return h
   end

   -- callbacks
   ltjb.add_to_callback(
      'pre_linebreak_filter',
      function (head,groupcode)
         return main_process(head, true, tex.textdir, groupcode)
      end,'ltj.main',
      luatexbase.priority_in_callback('pre_linebreak_filter', 'luaotfload.node_processor')+1)
   ltjb.add_to_callback(
      'hpack_filter',
      function (head,groupcode,size,packtype, dir)
         return main_process(head, false, dir, groupcode)
      end,'ltj.main',
      luatexbase.priority_in_callback('hpack_filter', 'luaotfload.node_processor')+1)
   ltjb.add_to_callback('pre_linebreak_filter', adjust_icflag, 'ltj.adjust_icflag', 1)
   ltjb.add_to_callback('hpack_filter', adjust_icflag, 'ltj.adjust_icflag', 1)
end

-- lastnodechar
do
  local get_attr, traverse_glyph = node.get_attribute, node.traverse_glyph
  local getnest = tex.getnest
  local id_hlist = node.id 'hlist'
  local id_glyph = node.id 'glyph'
  local PACKED, PROCESSED_BEGIN_FLAG = icflag_table.PACKED, icflag_table.PROCESSED_BEGIN_FLAG
  function luatexja.pltx_composite_last_node_char()
    local n = getnest().tail
    local r = '-1'
    if n then
      if n.id==id_hlist
        and (get_attr(n, attr_icflag) or 0) % PROCESSED_BEGIN_FLAG == PACKED then
        for i in traverse_glyph(n.head) do n = i; break end
      end
      if n.id==id_glyph then
        while n.components and  n.subtype and n.subtype%4 >= 2 do
          n = node.tail(n)
        end
        r = tostring(n.char)
      end
    end
  tex.sprint(-2, r)
  end
end

do
    local cache_ver = 4 -- must be same as ltj-kinsoku.tex
    local cache_outdate_fn = function (t) return t.version~=cache_ver end
    local t = ltjs.charprop_stack_table
    function luatexja.load_kinsoku()
        for i,_ in pairs(t) do t[i]=nil end
        local kinsoku = ltjb.load_cache('ltj-kinsoku_default',cache_outdate_fn)
        if kinsoku and kinsoku[1] then
            t[0] = kinsoku[1]
        else
            t[0] = {}; tex.print(cat_lp, '\\input ltj-kinsoku.tex\\relax')
        end
        luatexja.load_kinsoku=nil
    end
end

-- debug

do

local node_type = node.type
local node_next = node.next
local get_attr = node.get_attribute

local id_penalty = node.id 'penalty'
local id_glyph = node.id 'glyph'
local id_glue = node.id 'glue'
local id_kern = node.id 'kern'
local id_hlist = node.id 'hlist'
local id_vlist = node.id 'vlist'
local id_rule = node.id 'rule'
local id_math = node.id 'math'
local id_whatsit = node.id 'whatsit'
local sid_user = node.subtype 'user_defined'

local prefix, inner_depth
local utfchar = utf.char
local function debug_show_node_X(p,print_fn, limit, inner_depth)
   local k = prefix
   local s
   local pt, pic = node_type(p.id), (get_attr(p, attr_icflag) or 0) % icflag_table.PROCESSED_BEGIN_FLAG
   local base = prefix .. '[' .. string.format('%7d', node.direct.todirect(p)) .. '] ' ..
     string.format('%X', pic) .. ' ' .. pt .. ' ' .. tostring(p.subtype) .. ' '
   if pt == 'glyph' then
      s = base .. ' '
          .. (p.char<0xF0000 and utfchar(p.char) or '')
          .. string.format(' (U+%X) ', p.char)
          .. tostring(p.font) .. ' (' .. print_scaled(p.height) .. '+'
          .. print_scaled(p.depth) .. ')x' .. print_scaled(p.width)
      if p.xoffset~=0 or p.yoffset~=0 then
         s = s .. ' off: (' .. print_scaled(p.xoffset)
               .. ',' .. print_scaled(p.yoffset) .. ')'
      end
      print_fn(s)
   elseif pt=='hlist' or pt=='vlist' or pt=='unset'or pt=='ins' then
      if pt=='ins' then
         s = base .. '(' .. print_scaled(p.height) .. '+'
            .. print_scaled(p.depth) .. ')'
            .. ', dir=' .. tostring(node.get_attribute(p, attr_dir))
      else
         s = base .. '(' .. print_scaled(p.height) .. '+'
            .. print_scaled(p.depth) .. ')x' .. print_scaled(p.width)
            .. ', dir=' .. tostring(node.get_attribute(p, attr_dir))
      end
      if (p.shift or 0)~=0 then
         s = s .. ', shifted ' .. print_scaled(p.shift)
      end
      if p.glue_set and p.glue_sign ==2 or ( p.glue_sign==1 and p.glue_set>0) then
         s = s .. ' glue set '
         if p.glue_sign == 2 then s = s .. '-' end
         s = s .. tostring(floor(p.glue_set*10000)/10000)
         if p.glue_order == 0 then s = s .. 'pt'
         else
            s = s .. 'fi'
            for i = 2, p.glue_order do s = s .. 'l' end
         end
      end
      if pic == icflag_table.PACKED then s = s .. ' (packed)' end
      print_fn(s);
      local bid = inner_depth
      prefix, inner_depth = prefix.. '.', inner_depth + 1
      if inner_depth < limit then
         for q in node.traverse(p.head) do
            debug_show_node_X(q, print_fn, limit, inner_depth)
         end
      end
      prefix=k
   elseif pt=='rule' then
      s = base .. '(' .. print_scaled(p.height) .. '+'
         .. print_scaled(p.depth) .. ')x' .. print_scaled(p.width)
         .. ', dir=' .. tostring(node.get_attribute(p, attr_dir))
      print_fn(s)
   elseif pt=='disc' then
      print_fn(s)
      local bid = inner_depth
      if inner_depth < limit then
         prefix, inner_depth = k.. 'p.', inner_depth + 1
         for q in node.traverse(p.pre) do
            debug_show_node_X(q, print_fn, limit, inner_depth)
         end
         prefix = k.. 'P.'
         for q in node.traverse(p.post) do
            debug_show_node_X(q, print_fn, limit, inner_depth)
         end
         prefix = k.. 'R.'
         for q in node.traverse(p.replace) do
            debug_show_node_X(q, print_fn, limit, inner_depth)
         end
      end
      prefix=k
   elseif pt == 'glue' then
      s = base .. ' ' ..  print_spec(p)
      if pic>icflag_table.KINSOKU and pic<icflag_table.KANJI_SKIP then
         s = s .. ' (from JFM: priority ' .. pic-icflag_table.FROM_JFM .. ')'
      elseif pic==icflag_table.KANJI_SKIP then
         s = s .. ' (kanjiskip)'
      elseif pic==icflag_table.KANJI_SKIP_JFM then
         s = s .. ' (kanjiskip, JFM specified)'
      elseif pic==icflag_table.XKANJI_SKIP then
         s = s .. ' (xkanjiskip)'
      elseif pic==icflag_table.XKANJI_SKIP_JFM then
         s = s .. ' (xkanjiskip, JFM specified)'
      end
      print_fn(s)
   elseif pt == 'kern' then
      s = base .. ' ' .. print_scaled(p.kern) .. 'pt'
      if p.subtype==2 then
         s = s .. ' (for accent)'
      elseif pic==icflag_table.IC_PROCESSED then
         s = s .. ' (italic correction)'
      elseif pic==icflag_table.LINEEND then
         s = s .. ' (end-of-line)'
      elseif pic>icflag_table.KINSOKU
         and pic<icflag_table.KANJI_SKIP then
         s = s .. ' (from JFM: priority ' .. pic-icflag_table.FROM_JFM .. ')'
      end
      print_fn(s)
   elseif pt == 'penalty' then
      s = base .. ' ' .. tostring(p.penalty)
      if pic==icflag_table.KINSOKU then s = s .. ' (for kinsoku)' end
      print_fn(s)
   elseif pt == 'dir' then
      print_fn(base .. ' ' .. tostring(p.dir) .. ' (level ' .. tostring(p.level) .. ')')
   elseif pt == 'whatsit' then
      s = base
      if p.subtype==sid_user then
         local t = tostring(p.user_id) .. ' (' ..
            luatexbase.get_user_whatsit_name(p.user_id) .. ') '
         if p.type ~= 110 then
            s = s .. ' userid:' .. t .. tostring(p.value)
            print_fn(s)
         else
            s = s .. ' userid:' .. t .. '(node list)'
            if p.user_id==uid_table.DIR then
               s = s .. ' dir: ' .. tostring(node.get_attribute(p, attr_dir))
            end
            print_fn(s)
            local bid = inner_depth
            prefix, inner_depth = prefix.. '.', inner_depth + 1
            if inner_depth < limit then
               for q in node.traverse(p.value) do
                  debug_show_node_X(q, print_fn, limit, inner_depth)
               end
            end
            prefix, inner_depth = k, bid
         end
      else
         s = s .. (node.subtype(p.subtype) or '')
         if p.subtype==1 then
            s = s .. ' stream=' .. p.stream
            print_fn(s)
            for i=1,#p.data do
               print_fn(s .. '  [' .. i .. '] = ' .. tostring(p.data[i] and p.date[i].csname))
            end
         elseif p.subtype==16 then
            s = s .. ' mode=' .. p.mode .. ', literal="' .. p.data .. '"'
            print_fn(s)
         else
            print_fn(s)
         end
      end
   -------- math node --------
   elseif pt=='noad' then
      print_fn(base)
      if p.nucleus then
         prefix = k .. 'N'; debug_show_node_X(p.nucleus, print_fn, limit, inner_depth);
      end
      if p.sup then
         prefix = k .. '^'; debug_show_node_X(p.sup, print_fn, limit, inner_depth);
      end
      if p.sub then
         prefix = k .. '_'; debug_show_node_X(p.sub, print_fn, limit, inner_depth);
      end
      prefix = k;
   elseif pt=='math_char' then
      s = base .. ' fam: ' .. p.fam .. ' , char = ' .. utfchar(p.char)
      print_fn(s)
   elseif pt=='sub_box' or pt=='sub_mlist' then
      print_fn(base)
      if p.head then
         prefix = k .. '.';
         for q in node.traverse(p.head) do
            debug_show_node_X(q, print_fn, limit, inner_depth)
         end
      end
   elseif pt == 'attribute' then
      s = base .. ' [' .. p.number .. '] = ' .. p.value
      print_fn(s)
   else
      print_fn(base)
   end
   p=node_next(p)
end
function luatexja.ext_show_node_list(head,depth,print_fn, lim)
  prefix = depth
  inner_depth = 0
  if head then
    while head do
      debug_show_node_X(head, print_fn, lim or 1/0, inner_depth); head = node_next(head)
    end
  else
    print_fn(prefix .. ' (null list)')
  end
end
function luatexja.ext_show_node(head,depth,print_fn, lim)
  prefix = depth
  inner_depth = 0
  if head then
    debug_show_node_X(head, print_fn, lim or 1/0, inner_depth)
  else
    print_fn(prefix .. ' (null list)')
  end
end

end
