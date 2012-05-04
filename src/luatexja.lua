
local floor = math.floor

require('lualibs')

------------------------------------------------------------------------
-- naming:
--    ext_... : called from \directlua{}
--    int_... : called from other Lua codes, but not from \directlua{}
--    (other)     : only called from this file
function luatexja.error(s,t)
   tex.error('LuaTeX-ja error: ' .. s ,t) 
end
function luatexja.load_module(name)
   if not package.loaded['luatexja.' .. name] then
      local fn = 'ltj-' .. name .. '.lua'
      local found = kpse.find_file(fn, 'tex')
      if not found then
	 luatexja.error("File `" .. fn .. "' not found", 
			{'This file ' .. fn .. ' is required for LuaTeX-ja.', 'Please check your installation.'})
      else 
	 texio.write('(' .. found .. ')\n')
	 dofile(found)
      end
   end
end
function luatexja.load_lua(fn)
   local found = kpse.find_file(fn, 'tex')
   if not found then
      error("File `" .. fn .. "' not found")
   else 
      texio.write('(' .. found .. ')\n')
      dofile(found)
   end
end

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


local node_type = node.type
local node_new = node.new
local node_prev = node.prev
local node_next = node.next
local has_attr = node.has_attribute
local node_insert_before = node.insert_before
local node_insert_after = node.insert_after
local node_hpack = node.hpack

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

local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_yablshift = luatexbase.attributes['ltj@yablshift']
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_uniqid = luatexbase.attributes['ltj@uniqid']
local cat_lp = luatexbase.catcodetables['latex-package']

local ITALIC = 1
local PACKED = 2
local KINSOKU = 3
local FROM_JFM = 4
local LINE_END = 5
local KANJI_SKIP = 6
local XKANJI_SKIP = 7
local PROCESSED = 8
local IC_PROCESSED = 9
local BOXBDD = 15


-- Three aux. functions, bollowed from tex.web
local unity=65536
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

function math.two_add(a,b) return a+b end
function math.two_average(a,b) return (a+b)/2 end

---- table: charprop_stack_table [stack_level].{pre|post|xsp}[chr_code]

------------------------------------------------------------------------
-- CODE FOR GETTING/SETTING PARAMETERS 
------------------------------------------------------------------------

-- EXT: print parameters that don't need arguments
function luatexja.ext_get_parameter_unary(k)
   if k == 'yalbaselineshift' then
      tex.write(print_scaled(tex.getattribute('ltj@yablshift'))..'pt')
   elseif k == 'yjabaselineshift' then
      tex.write(print_scaled(tex.getattribute('ltj@ykblshift'))..'pt')
   elseif k == 'kanjiskip' then
      tex.write(print_spec(ltjs.get_skip_table('kanjiskip', tex.getcount('ltj@@stack'))))
   elseif k == 'xkanjiskip' then
      tex.write(print_spec(ltjs.get_skip_table('xkanjiskip', tex.getcount('ltj@@stack'))))
   elseif k == 'jcharwidowpenalty' then
      tex.write(ltjs.get_penalty_table('jwp', 0, 0, tex.getcount('ltj@@stack')))
   elseif k == 'autospacing' then
      tex.write(tex.getattribute('ltj@autospc'))
   elseif k == 'autoxspacing' then
      tex.write(tex.getattribute('ltj@autoxspc'))
   elseif k == 'differentjfm' then
      if luatexja.jfmglue.diffmet_rule == math.max then
	 tex.write('large')
      elseif luatexja.jfmglue.diffmet_rule == math.min then
	 tex.write('small')
      elseif luatexja.jfmglue.diffmet_rule == math.two_average then
	 tex.write('average')
      elseif luatexja.jfmglue.diffmet_rule == math.two_add then
	 tex.write('both')
      else -- This can't happen.
	 tex.write('???')
      end
   end
end


-- EXT: print parameters that need arguments
function luatexja.ext_get_parameter_binary(k,c)
   if type(c)~='number' then
      ltjb.package_error('luatexja',
			 'invalid the second argument (' .. tostring(c) .. ')',
			 'I changed this one to zero.')
      c=0
   end
   if k == 'jacharrange' then
      if c<0 or c>216 then 
	 ltjb.package_error('luatexja',
			    'invalid character range number (' .. c .. ')',
			    'A character range number should be in the range 0..216,\n'..
			     'So I changed this one to zero.')
	 c=0
      end
      tex.write(ltjc.get_range_setting(c))
   else
      if c<0 or c>0x10FFFF then
	 ltjb.package_error('luatexja',
			    'bad character code (' .. c .. ')',
			    'A character number must be between -1 and 0x10ffff.\n'..
			       "(-1 is used for denoting `math boundary')\n"..
			       'So I changed this one to zero.')
	 c=0
      end
      if k == 'prebreakpenalty' then
	 tex.write(ltjs.get_penalty_table('pre', c, 0, tex.getcount('ltj@@stack')))
      elseif k == 'postbreakpenalty' then
	 tex.write(ltjs.get_penalty_table('post', c, 0, tex.getcount('ltj@@stack')))
      elseif k == 'kcatcode' then
	 tex.write(ltjs.get_penalty_table('kcat', c, 0, tex.getcount('ltj@@stack')))
      elseif k == 'chartorange' then 
	 tex.write(ltjc.char_to_range(c))
      elseif k == 'jaxspmode' or k == 'alxspmode' then
	 tex.write(ltjs.get_penalty_table('xsp', c, 3, tex.getcount('ltj@@stack')))
      end
   end
end

-- EXT: print \global if necessary
function luatexja.ext_print_global()
  if isglobal=='global' then tex.sprint(cat_lp, '\\global') end
end

-- main process
-- mode = true iff main_process is called from pre_linebreak_filter
local function main_process(head, mode, dir)
   local p = head
   p = ltjj.main(p,mode)
   if p then p = ltjw.set_ja_width(p, dir) end
   return p
end

-- callbacks

luatexbase.add_to_callback('pre_linebreak_filter', 
   function (head,groupcode)
      return main_process(head, true, tex.textdir)
   end,'ltj.pre_linebreak_filter',
   luatexbase.priority_in_callback('pre_linebreak_filter',
				   'luaotfload.pre_linebreak_filter') + 1)
luatexbase.add_to_callback('hpack_filter', 
  function (head,groupcode,size,packtype, dir)
     return main_process(head, false, dir)
  end,'ltj.hpack_filter',
   luatexbase.priority_in_callback('hpack_filter',
				   'luaotfload.hpack_filter') + 1)

-- debug
local debug_depth

local function debug_show_node_X(p,print_fn)
   local k = debug_depth
   local s
   local pt=node_type(p.id)
   local base = debug_depth .. string.format('%X', has_attr(p,attr_icflag) or 0)
       .. ' ' .. tostring(p)
   if pt == 'glyph' then
      s = base .. ' ' .. utf.char(p.char) .. ' ' .. tostring(p.font)
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
      if has_attr(p, attr_icflag, PACKED) then
         s = s .. ' (packed)'
      end
      print_fn(s)
      local q = p.head
      debug_depth=debug_depth.. '.'
      while q do 
         debug_show_node_X(q, print_fn); q = node_next(q)
      end
      debug_depth=k
   elseif pt == 'glue' then
      s = base .. ' ' ..  print_spec(p.spec)
      if has_attr(p, attr_icflag)==FROM_JFM then
         s = s .. ' (from JFM)'
      elseif has_attr(p, attr_icflag)==KANJI_SKIP then
	 s = s .. ' (kanjiskip)'
      elseif has_attr(p, attr_icflag)==XKANJI_SKIP then
	 s = s .. ' (xkanjiskip)'
      end
      print_fn(s)
   elseif pt == 'kern' then
      s = base .. ' ' .. print_scaled(p.kern) .. 'pt'
      if p.subtype==2 then
	 s = s .. ' (for accent)'
      elseif has_attr(p, attr_icflag)==IC_PROCESSED then
	 s = s .. ' (italic correction)'
         -- elseif has_attr(p, attr_icflag)==ITALIC then
         --    s = s .. ' (italic correction)'
      elseif has_attr(p, attr_icflag)==FROM_JFM then
	 s = s .. ' (from JFM)'
      elseif has_attr(p, attr_icflag)==LINE_END then
	 s = s .. " (from 'lineend' in JFM)"
      end
      print_fn(s)
   elseif pt == 'penalty' then
      s = base .. ' ' .. tostring(p.penalty)
      if has_attr(p, attr_icflag)==KINSOKU then
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
   elseif pt=='sub_box' then
      print_fn(base)
      if p.head then
         debug_depth = k .. '.'; debug_show_node_X(p.head, print_fn); 
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