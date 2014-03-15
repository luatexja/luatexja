
require('lualibs')

------------------------------------------------------------------------
-- naming:
--    ext_... : called from \directlua{}
--    int_... : called from other Lua codes, but not from \directlua{}
--    (other)     : only called from this file
function luatexja.load_module(name)
   require('ltj-' .. name.. '.lua')
end
function luatexja.load_lua(fn)
   local found = kpse.find_file(fn, 'tex')
   if not found then
      tex.error("LuaTeX-ja error: File `" .. fn .. "' not found")
   else 
      texio.write_nl('(' .. found .. ')')
      dofile(found)
   end
end

--- 以下は全ファイルで共有される定数
local icflag_table = {}
luatexja.icflag_table = icflag_table
icflag_table.ITALIC          = 1
icflag_table.PACKED          = 2
icflag_table.KINSOKU         = 3
icflag_table.FROM_JFM        = 6
-- FROM_JFM: 4, 5, 6, 7, 8 →優先度高（伸びやすく，縮みやすい）
-- 6 が標準
icflag_table.KANJI_SKIP      = 9
icflag_table.KANJI_SKIP_JFM  = 10
icflag_table.XKANJI_SKIP     = 11
icflag_table.XKANJI_SKIP_JFM = 12
icflag_table.PROCESSED       = 13
icflag_table.IC_PROCESSED    = 14
icflag_table.BOXBDD          = 15
icflag_table.PROCESSED_BEGIN_FLAG = 128

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

------------------------------------------------------------------------
-- FIX node.remove
------------------------------------------------------------------------
do
   local node_remove, node_next, node_prev = node.remove, node.next, node.prev
   function luatexja.node_remove (head, current)
      if head==current then
         local q, r = node_next(current), node_prev(current)
         if q then q.prev = r end
         if r and node_next(r)==current then 
            r.next = q
         end
         return q, q
      else
         return node_remove(head, current)
      end
   end
   local Dnode = node.direct or node
   if Dnode~=node then
      local Dnode_remove, setfield = Dnode.remove, Dnode.setfield
      local Dnode_next, Dnode_prev = Dnode.getnext, Dnode.getprev
      function luatexja.Dnode_remove (head, current)
         if head==current then
            local q, r = Dnode_next(current), Dnode_prev(current)
            if q then setfield(q, 'prev', r) end
            if r and Dnode_next(r) == current then
               setfield(r, 'next', q)
            end
            return q, q
         else
            return Dnode_remove(head, current)
         end
      end
   else
      luatexja.Dnode_remove = luatexja.node_remove 
   end
end

--- 定義終わり

local load_module = luatexja.load_module
load_module('base');      local ltjb = luatexja.base
load_module('rmlgbm');    local ltjr = luatexja.rmlgbm -- must be 1st
load_module('charrange'); local ltjc = luatexja.charrange
load_module('jfont');     local ltjf = luatexja.jfont
load_module('inputbuf');  local ltji = luatexja.inputbuf
load_module('stack');     local ltjs = luatexja.stack
load_module('pretreat');  local ltjp = luatexja.pretreat
load_module('jfmglue');   local ltjj = luatexja.jfmglue
load_module('setwidth');  local ltjw = luatexja.setwidth
load_module('math');      local ltjm = luatexja.math
load_module('tangle');    local ltjb = luatexja.base

local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_yablshift = luatexbase.attributes['ltj@yablshift']
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_uniqid = luatexbase.attributes['ltj@uniqid']
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
   luatexja.unary_pars = {
      yalbaselineshift = function(t) 
	 return print_scaled(tex.getattribute('ltj@yablshift'))..'pt'
      end,
      yjabaselineshift = function(t) 
	 return print_scaled(tex.getattribute('ltj@ykblshift'))..'pt'
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
	 return tex.getattribute('ltj@autospc')
      end,
      autoxspacing = function(t)
	 return tex.getattribute('ltj@autoxspc')
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
      end
   }

   local unary_pars = luatexja.unary_pars
   function luatexja.ext_get_parameter_unary(k)
      if unary_pars[k] then
	 tex.write(tostring(unary_pars[k](tex.getcount('ltj@@stack'))))
      end
   end
end


-- EXT: print parameters that need arguments
do
   luatexja.binary_pars = {
      jacharrange = function(c, t)
	 if type(c)~='number' or c<0 or c>31*ltjc.ATTR_RANGE then
	    -- 0 はエラーにしない（隠し）
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
   }
   local binary_pars = luatexja.binary_pars 

   binary_pars.alxspmode = binary_pars.jaxspmode
   function luatexja.ext_get_parameter_binary(k,c)
      if binary_pars[k] then
	 tex.write(tostring(binary_pars[k](c,tex.getcount('ltj@@stack'))))
      end
   end
end

-- EXT: print \global if necessary
function luatexja.ext_print_global()
   if luatexja.isglobal=='global' then tex.sprint(cat_lp, '\\global') end
end

-- main process
do
   local Dnode = node.direct or node
   local nullfunc = function (n) return n end
   local to_node = (Dnode ~= node) and Dnode.tonode or nullfunc
   local to_direct = (Dnode ~= node) and Dnode.todirect or nullfunc
   -- mode = true iff main_process is called from pre_linebreak_filter
   local function main_process(head, mode, dir)
      tex.setattribute('global', attr_icflag, 0)
      local p = to_direct(head)
      p = ltjj.main(p,mode)
      if p then p = ltjw.set_ja_width(p, dir) end
      return to_node(p)
   end

   local function adjust_icflag(h)
      -- kern from luaotfload will have icflag = 1
      -- (same as italic correction)
      tex.setattribute('global', attr_icflag, 1)
      return h
   end

   -- callbacks
   
   luatexbase.add_to_callback(
      'pre_linebreak_filter', 
      function (head,groupcode)
	 return main_process(head, true, tex.textdir)
      end,'ltj.pre_linebreak_filter',
      luatexbase.priority_in_callback('pre_linebreak_filter',
				      'luaotfload.node_processor') + 1)
   luatexbase.add_to_callback(
      'hpack_filter', 
      function (head,groupcode,size,packtype, dir)
	 return main_process(head, false, dir)
      end,'ltj.hpack_filter',
      luatexbase.priority_in_callback('hpack_filter',
				      'luaotfload.node_processor') + 1)
   luatexbase.add_to_callback('pre_linebreak_filter', adjust_icflag, 'adjust_icflag', 1)
   luatexbase.add_to_callback('hpack_filter', adjust_icflag, 'adjust_icflag', 1)

end

-- define_font
do
   local otfl_fdr = fonts.definers.read
   local ltjr_font_callback = ltjr.font_callback
   function luatexja.font_callback(name, size, id)
      return ltjf.font_callback(
	 name, size, id, 
	 function (name, size, id) return ltjr_font_callback(name, size, id, otfl_fdr) end
      )
   end
   luatexbase.add_to_callback('define_font',luatexja.font_callback,"luatexja.font_callback", 1)
end




-- debug

do

local node_type = node.type
local node_next = node.next
local has_attr = node.has_attribute

local id_penalty = node.id('penalty')
local id_glyph = node.id('glyph')
local id_glue_spec = node.id('glue_spec')
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

local debug_depth

local function debug_show_node_X(p,print_fn)
   local k = debug_depth
   local s
   local pt=node_type(p.id)
   local base = debug_depth .. string.format('%X', get_attr_icflag(p))
   .. ' ' .. pt .. ' ' .. tostring(p.subtype) .. ' '
   if pt == 'glyph' then
      s = base .. ' ' .. utf.char(p.char) .. ' '  .. tostring(p.font)
         .. ' (' .. print_scaled(p.height) .. '+' 
         .. print_scaled(p.depth) .. ')x' .. print_scaled(p.width)
      print_fn(s)
   elseif pt=='hlist' or pt=='vlist' then
      s = base .. '(' .. print_scaled(p.height) .. '+' 
         .. print_scaled(p.depth) .. ')x' .. print_scaled(p.width) .. p.dir
      if p.shift~=0 then
         s = s .. ', shifted ' .. print_scaled(p.shift)
      end
      if p.glue_sign >= 1 then 
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
      print_fn(s); debug_depth=debug_depth.. '.'
      for q in node.traverse(p.head) do
         debug_show_node_X(q, print_fn)
      end
      debug_depth=k
   elseif pt == 'glue' then
      s = base .. ' ' ..  print_spec(p.spec)
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
      s = base .. ' subtype: ' ..  tostring(p.subtype)
      if p.subtype==sid_user then
         if p.type ~= 110 then 
            s = s .. ' user_id: ' .. p.user_id .. ' ' .. p.value
            print_fn(s)
         else
            s = s .. ' user_id: ' .. p.user_id .. ' (node list)'
            print_fn(s)
            local q = p.value
            debug_depth=debug_depth.. '.'
            while q do 
               debug_show_node_X(q, print_fn); q = node_next(q)
            end
            debug_depth=k
         end
      else
         s = s .. node.subtype(p.subtype); print_fn(s)
      end
   -------- math node --------
   elseif pt=='noad' then
      s = base ; print_fn(s)
      if p.nucleus then
         debug_depth = k .. 'N'; debug_show_node_X(p.nucleus, print_fn); 
      end
      if p.sup then
         debug_depth = k .. '^'; debug_show_node_X(p.sup, print_fn); 
      end
      if p.sub then
         debug_depth = k .. '_'; debug_show_node_X(p.sub, print_fn); 
      end
      debug_depth = k;
   elseif pt=='math_char' then
      s = base .. ' fam: ' .. p.fam .. ' , char = ' .. utf.char(p.char)
      print_fn(s)
   elseif pt=='sub_box' or pt=='sub_mlist' then
      print_fn(base)
      if p.head then
         debug_depth = k .. '.'; 
	 for q in node.traverse(p.head) do
	    debug_show_node_X(q, print_fn)
	 end
      end
   else
      print_fn(base)
   end
   p=node_next(p)
end
function luatexja.ext_show_node_list(head,depth,print_fn)
   debug_depth = depth
   if head then
      while head do
         debug_show_node_X(head, print_fn); head = node_next(head)
      end
   else
      print_fn(debug_depth .. ' (null list)')
   end
end
function luatexja.ext_show_node(head,depth,print_fn)
   debug_depth = depth
   if head then
      debug_show_node_X(head, print_fn)
   else
      print_fn(debug_depth .. ' (null list)')
   end
end

end
