
require('lualibs')
tableunpack = table.unpack

------------------------------------------------------------------------
local function load_lua(fn)
   local found = kpse.find_file(fn, 'tex')
   if not found then
      tex.error("LuaTeX-ja error: File `" .. fn .. "' not found")
   else
      texio.write_nl('(' .. found .. ')')
      dofile(found)
   end
end
luatexja.load_lua = load_lua
function luatexja.load_module(name)
   require('ltj-' .. name.. '.lua')
end

do
    local setfield = node.direct.setfield
    luatexja.setglue = node.direct.setglue or
    function(g,w,st,sh,sto,sho)
	setfield(g,'width', w or 0)
	setfield(g,'stretch',st or 0)
	setfield(g,'shrink', sh or 0)
	setfield(g,'stretch_order',sto or 0)
	setfield(g,'shrink_order', sho or 0)
    end
    local getfield = node.direct.getfield
    luatexja.getglue = node.direct.getglue or
    function(g)
	return getfield(g,'width'),
	       getfield(g,'stretch'),
	       getfield(g,'shrink'),
	       getfield(g,'stretch_order'),
	       getfield(g,'shrink_order')
    end
end

--- 以下は全ファイルで共有される定数
local icflag_table = {}
luatexja.icflag_table = icflag_table
icflag_table.ITALIC          = 1
icflag_table.PACKED          = 2
icflag_table.KINSOKU         = 3
icflag_table.FROM_JFM        = 4
-- FROM_JFM: 4, 5, 6, 7, 8 →優先度高（伸びやすく，縮みやすい）
-- 6 が標準
icflag_table.KANJI_SKIP      = 68 -- = 4+64
icflag_table.KANJI_SKIP_JFM  = 69
icflag_table.XKANJI_SKIP     = 70
icflag_table.XKANJI_SKIP_JFM = 71
icflag_table.LINEEND         = 72
icflag_table.PROCESSED       = 73
icflag_table.IC_PROCESSED    = 74
icflag_table.BOXBDD          = 75
icflag_table.PROCESSED_BEGIN_FLAG = 4096 -- sufficiently large power of 2

local stack_table_index = {}
luatexja.stack_table_index = stack_table_index
stack_table_index.PRE  = 0x200000 -- characterごと
stack_table_index.POST = 0x400000 -- characterごと
stack_table_index.KCAT = 0x600000 -- characterごと
stack_table_index.XSP  = 0x800000 -- characterごと
stack_table_index.RIPRE  = 0xA00000 -- characterごと，ruby pre
stack_table_index.RIPOST = 0xC00000 -- characterごと，ruby post
stack_table_index.JWP  = 0 -- これだけ
stack_table_index.KSK  = 1 -- これだけ
stack_table_index.XSK  = 2 -- これだけ
stack_table_index.MJT  = 0x100 -- 0--255
stack_table_index.MJS  = 0x200 -- 0--255
stack_table_index.MJSS = 0x300 -- 0--255
stack_table_index.KSJ  = 0x400 -- 0--9

local userid_table = {}
luatexja.userid_table = userid_table
userid_table.IHB  = luatexbase.newuserwhatsitid('inhibitglue',  'luatexja') -- \inhibitglue
userid_table.STCK = luatexbase.newuserwhatsitid('stack_marker', 'luatexja') -- スタック管理
userid_table.BPAR = luatexbase.newuserwhatsitid('begin_par',    'luatexja') -- 「段落始め」
userid_table.DIR  = luatexbase.newuserwhatsitid('direction',    'luatexja') -- 組方向
userid_table.BOXB = luatexbase.newuserwhatsitid('box_boundary', 'luatexja') -- 「ボックス始め・終わり」

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
load_module('base');      local ltjb = luatexja.base
load_module('rmlgbm');    local ltjr = luatexja.rmlgbm -- must be 1st

if luatexja_debug then load_module('debug') end

load_module('charrange'); local ltjc = luatexja.charrange
load_module('stack');     local ltjs = luatexja.stack
load_module('direction'); local ltjd = luatexja.direction -- +1 hlist +1 attr_list
load_module('lineskip');  local ltjl = luatexja.lineskip -- +1 hlist +1 attr_list
load_module('jfont');     local ltjf = luatexja.jfont
load_module('inputbuf');  local ltji = luatexja.inputbuf
load_module('pretreat');  local ltjp = luatexja.pretreat
load_module('setwidth');  local ltjw = luatexja.setwidth
load_module('jfmglue');   local ltjj = luatexja.jfmglue -- +1 glue +1 gs +1 attr_list
load_module('math');      local ltjm = luatexja.math
load_module('base');      local ltjb = luatexja.base


local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_jchar_code = luatexbase.attributes['ltj@charcode']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_yablshift = luatexbase.attributes['ltj@yablshift']
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_uniqid = luatexbase.attributes['ltj@uniqid']
local attr_dir = luatexbase.attributes['ltj@dir']
local cat_lp = luatexbase.catcodetables['latex-package']

-- Three aux. functions, bollowed from tex.web

local unity=65536
local floor = math.floor

local function print_scaled(s)
   local out=''
   local delta=10
   if s<0 then
      out=out..'-'; s=-s
   end
   out=out..tostring(floor(s/unity)) .. '.'
   s=10*(s%unity)+5
   repeat
      if delta>unity then s=s+32768-50000 end
      out=out .. tostring(floor(s/unity))
      s=10*(s%unity)
      delta=delta*10
   until s<=delta
   return out
end
luatexja.print_scaled = print_scaled

local function print_glue(d,order)
   local out=print_scaled(d)
   if order>0 then
      out=out..'fi'
      while order>1 do
	 out=out..'l'; order=order-1
      end
   else
      out=out..'pt'
   end
   return out
end

local function print_spec(p)
   local out=print_scaled(p.width)..'pt'
   if p.stretch~=0 then
      out=out..' plus '..print_glue(p.stretch,p.stretch_order)
   end
   if p.shrink~=0 then
      out=out..' minus '..print_glue(p.shrink,p.shrink_order)
   end
return out
end


------------------------------------------------------------------------
-- CODE FOR GETTING/SETTING PARAMETERS
------------------------------------------------------------------------

-- EXT: print parameters that don't need arguments
do
   local tex_getattr = tex.getattribute
   local function getattr(a)
      local r = tex.getattribute(a)
      return (r==-0x7FFFFFFF) and 0 or r
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
	 return print_spec(ltjs.get_stack_skip(stack_table_index.KSK, t))
      end,
      xkanjiskip = function(t)
	 return print_spec(ltjs.get_stack_skip(stack_table_index.XSK, t))
      end,
      jcharwidowpenalty = function(t)
	 return ltjs.get_stack_table(stack_table_index.JWP, 0, t)
      end,
      autospacing = function(t)
	 return getattr('ltj@autospc')
      end,
      autoxspacing = function(t)
	 return getattr('ltj@autoxspc')
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
	 if math.abs(tex.nest[tex.nest.ptr].mode) == ltjs.mmode and v == dir_table.dir_tate then
	    v = dir_table.dir_utod
	 end
	 return v
      end,
      adjustdir = ltjd.get_adjust_dir_count,
   }

   local unary_pars = luatexja.unary_pars
   function luatexja.ext_get_parameter_unary(k)
      if unary_pars[k] then
	 tex.write(tostring(unary_pars[k](tex.getcount('ltj@@stack'))))
      end
      ltjb.stop_time_measure('get_par')
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
	 return (c<0) and 1 or ltjc.get_range_setting(c)
      end,
      prebreakpenalty = function(c, t)
	 return ltjs.get_stack_table(stack_table_index.PRE
					  + ltjb.in_unicode(c, true), 0, t)
      end,
      postbreakpenalty = function(c, t)
	 return ltjs.get_stack_table(stack_table_index.POST
					  + ltjb.in_unicode(c, true), 0, t)
      end,
      kcatcode = function(c, t)
	 return ltjs.get_stack_table(stack_table_index.KCAT
					  + ltjb.in_unicode(c, false), 0, t)
      end,
      chartorange = function(c, t)
	 return ltjc.char_to_range(ltjb.in_unicode(c, false))
      end,
      jaxspmode = function(c, t)
	 return ltjs.get_stack_table(stack_table_index.XSP
					  + ltjb.in_unicode(c, true), 3, t)
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

   binary_pars.alxspmode = binary_pars.jaxspmode
   function luatexja.ext_get_parameter_binary(k,c)
      if binary_pars[k] then
	 tex.write(tostring(binary_pars[k](c,tex.getcount('ltj@@stack'))))
      end
      ltjb.stop_time_measure('get_par')
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

   -- mode = true iff main_process is called from pre_linebreak_filter
   local function main_process(head, mode, dir, gc)
      ensure_tex_attr(attr_icflag, 0)
      if gc == 'fin_row' then return head
      else
            --luatexja.ext_show_node_list(head, 'T> ', print)
	    start_time_measure('jfmglue')
	    local p = ltjj.main(to_direct(head),mode, dir)
	    stop_time_measure('jfmglue')
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

-- cleanup process
function luatexja.ext_cleanup()
   ltjf.cleanup_size_cache()
   ltjd.remove_end_whatsit()
end


-- lastnodechar
do
   local id_glyph = node.id('glyph')
   function luatexja.pltx_composite_last_node_char()
      local n = tex.nest[tex.nest.ptr].tail
      local r = '-1'
      if n then
	 if n.id==id_glyph then
	    while n.componetns and  n.subtype and n.subtype%4 >= 2 do
	       n = node.tail(n)
	    end
	    r = tostring(n.char)
	 end
      end
      tex.sprint(r)
   end
end

-- debug

do

local node_type = node.type
local node_next = node.next
local has_attr = node.has_attribute

local id_penalty = node.id('penalty')
local id_glyph = node.id('glyph')
local id_glue = node.id('glue')
local id_kern = node.id('kern')
local id_hlist = node.id('hlist')
local id_vlist = node.id('vlist')
local id_rule = node.id('rule')
local id_math = node.id('math')
local id_whatsit = node.id('whatsit')
local sid_user = node.subtype('user_defined')

local function get_attr_icflag(p)
   return (has_attr(p, attr_icflag) or 0) % icflag_table.PROCESSED_BEGIN_FLAG
end

local prefix, inner_depth

local function debug_show_node_X(p,print_fn, limit)
   local k = prefix
   local s
   local pt=node_type(p.id)
   local base = prefix .. string.format('%X', get_attr_icflag(p))
   .. ' ' .. pt .. ' ' .. tostring(p.subtype) .. ' '
   if pt == 'glyph' then
      s = base .. ' ' .. 
         (p.char>=0xF0000 and string.format('(U+%X)', p.char) or utf.char(p.char)) .. ' '
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
	    .. ', dir=' .. tostring(node.has_attribute(p, attr_dir))
      else
	 s = base .. '(' .. print_scaled(p.height) .. '+'
	    .. print_scaled(p.depth) .. ')x' .. print_scaled(p.width)
	    .. ', dir=' .. tostring(node.has_attribute(p, attr_dir))
      end
      if (p.shift or 0)~=0 then
         s = s .. ', shifted ' .. print_scaled(p.shift)
      end
      if p.glue_set and p.glue_sign ==2 or ( p.glue_sign==1 and p.glue_set>0) then
         s = s .. ' glue set '
         if p.glue_sign == 2 then s = s .. '-' end
         s = s .. tostring(floor(p.glue_set*10000)/10000)
         if p.glue_order == 0 then
            s = s .. 'pt'
         else
            s = s .. 'fi'
            for i = 2,  p.glue_order do s = s .. 'l' end
         end
      end
      if get_attr_icflag(p) == icflag_table.PACKED then
         s = s .. ' (packed)'
      end
      print_fn(s);
      local bid = inner_depth
      prefix, inner_depth = prefix.. '.', inner_depth + 1
      if inner_depth < limit then
	 for q in node.traverse(p.head) do
	    debug_show_node_X(q, print_fn, limit)
	 end
      end
      prefix=k
   elseif pt=='rule' then
      s = base .. '(' .. print_scaled(p.height) .. '+'
         .. print_scaled(p.depth) .. ')x' .. print_scaled(p.width)
	 .. ', dir=' .. tostring(node.has_attribute(p, attr_dir))
      print_fn(s)
   elseif pt=='disc' then
      print_fn(s)
      local bid = inner_depth
      if inner_depth < limit then
         prefix, inner_depth = k.. 'p.', inner_depth + 1
	 for q in node.traverse(p.pre) do
	    debug_show_node_X(q, print_fn, limit)
	 end
         prefix = k.. 'P.'
	 for q in node.traverse(p.post) do
	    debug_show_node_X(q, print_fn, limit)
	 end
         prefix = k.. 'R.'
	 for q in node.traverse(p.replace) do
	    debug_show_node_X(q, print_fn, limit)
	 end
      end
      prefix=k
   elseif pt == 'glue' then
      s = base .. ' ' ..  print_spec(p)
      if get_attr_icflag(p)>icflag_table.KINSOKU
         and get_attr_icflag(p)<icflag_table.KANJI_SKIP then
         s = s .. ' (from JFM: priority ' .. get_attr_icflag(p)-icflag_table.FROM_JFM .. ')'
      elseif get_attr_icflag(p)==icflag_table.KANJI_SKIP then
	 s = s .. ' (kanjiskip)'
      elseif get_attr_icflag(p)==icflag_table.KANJI_SKIP_JFM then
	 s = s .. ' (kanjiskip, JFM specified)'
      elseif get_attr_icflag(p)==icflag_table.XKANJI_SKIP then
	 s = s .. ' (xkanjiskip)'
      elseif get_attr_icflag(p)==icflag_table.XKANJI_SKIP_JFM then
	 s = s .. ' (xkanjiskip, JFM specified)'
      end
      print_fn(s)
   elseif pt == 'kern' then
      s = base .. ' ' .. print_scaled(p.kern) .. 'pt'
      if p.subtype==2 then
	 s = s .. ' (for accent)'
      elseif get_attr_icflag(p)==icflag_table.IC_PROCESSED then
	 s = s .. ' (italic correction)'
      elseif get_attr_icflag(p)==icflag_table.LINEEND then
	 s = s .. ' (end-of-line)'
         -- elseif get_attr_icflag(p)==ITALIC then
         --    s = s .. ' (italic correction)'
      elseif get_attr_icflag(p)>icflag_table.KINSOKU
         and get_attr_icflag(p)<icflag_table.KANJI_SKIP then
	 s = s .. ' (from JFM: priority ' .. get_attr_icflag(p)-icflag_table.FROM_JFM .. ')'
      end
      print_fn(s)
   elseif pt == 'penalty' then
      s = base .. ' ' .. tostring(p.penalty)
      if get_attr_icflag(p)==icflag_table.KINSOKU then
	 s = s .. ' (for kinsoku)'
      end
      print_fn(s)
   elseif pt == 'whatsit' then
      s = base
      if p.subtype==sid_user then
	 local t = tostring(p.user_id) .. ' (' ..
	    luatexbase.get_user_whatsit_name(p.user_id) .. ') '
         if p.type ~= 110 then
            s = s .. ' userid:' .. t .. p.value
            print_fn(s)
         else
            s = s .. ' userid:' .. t .. '(node list)'
	    if p.user_id==userid_table.DIR then
	       s = s .. ' dir: ' .. tostring(node.has_attribute(p, attr_dir))
	    end
            print_fn(s)
	    local bid = inner_depth
            prefix, inner_depth =prefix.. '.', inner_depth + 1
            if inner_depth < limit then
	       for q in node.traverse(p.value) do
		  debug_show_node_X(q, print_fn, limit)
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
	       print_fn(s .. '  [' .. i .. '] = ' .. tostring(p.data[i].csname))
	    end
	 else
	    print_fn(s)
	 end
      end
   -------- math node --------
   elseif pt=='noad' then
      s = base ; print_fn(s)
      if p.nucleus then
         prefix = k .. 'N'; debug_show_node_X(p.nucleus, print_fn, limit);
      end
      if p.sup then
         prefix = k .. '^'; debug_show_node_X(p.sup, print_fn, limit);
      end
      if p.sub then
         prefix = k .. '_'; debug_show_node_X(p.sub, print_fn, limit);
      end
      prefix = k;
   elseif pt=='math_char' then
      s = base .. ' fam: ' .. p.fam .. ' , char = ' .. utf.char(p.char)
      print_fn(s)
   elseif pt=='sub_box' or pt=='sub_mlist' then
      print_fn(base)
      if p.head then
         prefix = k .. '.';
	 for q in node.traverse(p.head) do
	    debug_show_node_X(q, print_fn)
	 end
      end
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
         debug_show_node_X(head, print_fn, lim or 1/0); head = node_next(head)
      end
   else
      print_fn(prefix .. ' (null list)')
   end
end
function luatexja.ext_show_node(head,depth,print_fn, lim)
   prefix = depth
   inner_depth = 0
   if head then
      debug_show_node_X(head, print_fn, lim or 1/0)
   else
      print_fn(prefix .. ' (null list)')
   end
end

end
