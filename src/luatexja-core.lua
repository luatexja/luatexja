local node_type = node.type
local node_new = node.new
local node_prev = node.prev
local node_next = node.next
local has_attr = node.has_attribute
local node_insert_before = node.insert_before
local node_insert_after = node.insert_after
local node_hpack = node.hpack
local round = tex.round

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
local attr_ykblshift = luatexbase.attributes['ltj@ykblshift']
local attr_icflag = luatexbase.attributes['ltj@icflag']

local lang_ja_token = token.create('ltj@japanese')
local lang_ja = lang_ja_token[2]

-- 
local ljfm_find_char_class = ltj.int_find_char_class


local ITALIC = 1
local TEMPORARY = 2
local FROM_JFM = 3
local KINSOKU = 4
local LINE_END = 5
local KANJI_SKIP = 6
local XKANJI_SKIP = 7
local PACKED = 8

------------------------------------------------------------------------
-- naming:
--    ltj.ext_... : called from \directlua{}
--    ltj.int_... : called from other Lua codes, but not from \directlua{}
--    (other)     : only called from this file

-- error messages
function ltj.error(s,t)
  tex.error('LuaTeX-ja error: ' .. s ,t) 
end

-- Three aux. functions, bollowed from tex.web
local unity=65536
local function print_scaled(s)
   local out=''
   local delta=10
   if s<0 then 
      out=out..'-'; s=-s
   end
   out=out..tostring(math.floor(s/unity)) .. '.'
   s=10*(s%unity)+5
   repeat
      if delta>unity then s=s+32768-50000 end
      out=out .. tostring(math.floor(s/unity)) 
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

-- return true if and only if p is a Japanese character node
local function is_japanese_glyph_node(p)
   return p and (p.id==id_glyph) 
   and (p.font==has_attr(p,attr_curjfnt))
end

function math.two_add(a,b) return a+b end
function math.two_average(a,b) return (a+b)/2 end

---- table: charprop_stack_table [stack_level][chr_code].{pre|post|xsp}

------------------------------------------------------------------------
-- CODE FOR GETTING/SETTING PARAMETERS 
------------------------------------------------------------------------

-- EXT: print parameters that don't need arguments
function ltj.ext_get_parameter_unary(k)
   if k == 'yalbaselineshift' then
      tex.write(print_scaled(tex.getattribute('ltj@yablshift'))..'pt')
   elseif k == 'yjabaselineshift' then
      tex.write(print_scaled(tex.getattribute('ltj@ykblshift'))..'pt')
   elseif k == 'kanjiskip' then
      tex.write(print_spec(luatexja.stack.get_skip_table('kanjiskip', tex.getcount('ltj@@stack'))))
   elseif k == 'xkanjiskip' then
      tex.write(print_spec(luatexja.stack.get_skip_table('xkanjiskip', tex.getcount('ltj@@stack'))))
   elseif k == 'jcharwidowpenalty' then
      tex.write(luatexja.stack.get_penalty_table('jwp', 0, 0, tex.getcount('ltj@@stack')))
   elseif k == 'autospacing' then
      tex.write(tex.getattribute('ltj@autospc'))
   elseif k == 'autoxspacing' then
      tex.write(tex.getattribute('ltj@autoxspc'))
   elseif k == 'differentjfm' then
      if ltj.ja_diffmet_rule == math.max then
	 tex.write('large')
      elseif ltj.ja_diffmet_rule == math.min then
	 tex.write('small')
      elseif ltj.ja_diffmet_rule == math.two_average then
	 tex.write('average')
      elseif ltj.ja_diffmet_rule == math.two_add then
	 tex.write('both')
      else -- This can't happen.
	 tex.write('???')
      end
   end
end

-- EXT: print parameters that need arguments
function ltj.ext_get_parameter_binary(k,c)
   if k == 'jacharrange' then
      if c<0 or c>216 then c=0 end
      tex.write(luatexja.charrange.get_range_setting(c))
   else
      if c<0 or c>0x10FFFF then
	 ltj.error('Invalid character code (' .. c 
		   .. '), should in the range 0.."10FFFF.',
		{"I'm going to use 0 instead of that illegal character code."})
	 c=0
      end
      if k == 'prebreakpenalty' then
	 tex.write(luatexja.stack.get_penalty_table('pre', c, 0, tex.getcount('ltj@@stack')))
      elseif k == 'postbreakpenalty' then
	 tex.write(luatexja.stack.get_penalty_table('post', c, 0, tex.getcount('ltj@@stack')))
      elseif k == 'kcatcode' then
	 tex.write(luatexja.stack.get_penalty_table('kcat', c, 0, tex.getcount('ltj@@stack')))
      elseif k == 'chartorange' then 
	 tex.write(luatexja.charrange.char_to_range(c))
      elseif k == 'jaxspmode' or k == 'alxspmode' then
	 tex.write(luatexja.stack.get_penalty_table('xsp', c, 3, tex.getcount('ltj@@stack')))
      end
   end
end

-- EXT: print \global if necessary
function ltj.ext_print_global()
  if ltj.isglobal=='global' then tex.sprint('\\global') end
end


------------------------------------------------------------------------
-- MAIN PROCESS STEP 1: replace fonts (prefix: main1)
------------------------------------------------------------------------
ltj.box_stack_level = 0
-- This is used in Step 2 (JFM glue/kern) and Step 3 (\[x]kanjiskip).

local function main1_suppress_hyphenate_ja(head)
   for p in node.traverse_id(id_glyph, head) do
      if luatexja.charrange.is_ucs_in_japanese_char(p) then
	 local v = has_attr(p, attr_curjfnt)
	 if v then 
	    p.font = v 
	    node.set_attribute(p, attr_jchar_class,
			       ljfm_find_char_class(p.char, ltj.font_metric_table[v].jfm))
	 end
	 v = has_attr(p, attr_ykblshift)
	 if v then 
	    node.set_attribute(p, attr_yablshift, v)
	 else
	    node.unset_attribute(p, attr_yablshift)
	 end
	 p.lang=lang_ja
      end
   end
   lang.hyphenate(head)
   return head
end

-- mode: true iff this function is called from hpack_filter
local function main1_set_box_stack_level(head, mode)
   local box_set = false
   local p = head
   local cl = tex.currentgrouplevel + 1
   while p do
      if p.id==id_whatsit and p.subtype==sid_user and p.user_id==30112 then
	 local g = p
	 if mode and g.value==cl then box_set = true end
	 head, p = node.remove(head, g)
      else p = node_next(p)
      end
   end
   if box_set then 
      ltj.box_stack_level = tex.getcount('ltj@@stack') + 1 
   else 
      ltj.box_stack_level = tex.getcount('ltj@@stack') 
   end
   if not head then -- prevent that the list is null
      head = node_new(id_kern); head.kern = 0; head.subtype = 1
   end
   return head
end

-- CALLBACKS
luatexbase.add_to_callback('hpack_filter', 
   function (head)
     return main1_set_box_stack_level(head, true)
   end,'ltj.hpack_filter_pre',1)
luatexbase.add_to_callback('pre_linebreak_filter', 
  function (head)
     return main1_set_box_stack_level(head, false)
  end,'ltj.pre_linebreak_filter_pre',1)
luatexbase.add_to_callback('hyphenate', 
 function (head,tail)
    return main1_suppress_hyphenate_ja(head)
 end,'ltj.hyphenate')


------------------------------------------------------------------------
-- MAIN PROCESS STEP 4: width of japanese chars (prefix: main4)
------------------------------------------------------------------------

-- TeX's \hss
local function main4_get_hss()
   local hss = node_new(id_glue)
   local fil_spec = node_new(id_glue_spec)
   fil_spec.width = 0
   fil_spec.stretch = 65536
   fil_spec.stretch_order = 2
   fil_spec.shrink = 65536
   fil_spec.shrink_order = 2
   hss.spec = fil_spec
   return hss
end

local function main4_set_ja_width(head)
   local p = head
   local met_tb, t, s, g, q, a, h
   local m = false -- is in math mode?
   while p do
      local v=has_attr(p,attr_yablshift) or 0
      if p.id==id_glyph then
	 p.yoffset = p.yoffset-v
	 if is_japanese_glyph_node(p) then
	    met_tb = ltj.font_metric_table[p.font]
	    t = ltj.metrics[met_tb.jfm]
	    s = t.char_type[has_attr(p,attr_jchar_class)]
	    if s.width ~= 'prop' and
	       not(s.left==0.0 and s.down==0.0 and s.align=='left' 
		   and round(s.width*met_tb.size)==p.width) then
	       -- must be encapsuled by a \hbox
	       head, q = node.remove(head,p)
	       p.next = nil
	       p.yoffset=round(p.yoffset-met_tb.size*s.down)
	       p.xoffset=round(p.xoffset-met_tb.size*s.left)
	       if s.align=='middle' or s.align=='right' then
		  h = node_insert_before(p, p, main4_get_hss())
	       else h=p end
	       if s.align=='middle' or s.align=='left' then
		  node_insert_after(h, p, main4_get_hss())
	       end
	       g = node_hpack(h, round(met_tb.size*s.width), 'exactly')
	       g.height = round(met_tb.size*s.height)
	       g.depth = round(met_tb.size*s.depth)
	       node.set_attribute(g, attr_icflag, PACKED)
	       if q then
		  head = node_insert_before(head, q, g)
	       else
		  head = node_insert_after(head, node.tail(head), g)
	       end
	       p = q
	    else p=node_next(p)
	    end
	 else p=node_next(p)
	 end
      elseif p.id==id_math then
	 m=(p.subtype==0); p=node_next(p)
      else
	 if m then
	    if p.id==id_hlist or p.id==id_vlist then
	       p.shift=p.shift+v
	    elseif p.id==id_rule then
	       p.height=p.height-v; p.depth=p.depth+v 
	    end
	 end
	 p=node_next(p)
      end
   end
return head
end

-- main process
-- mode = true iff main_process is called from pre_linebreak_filter
local function main_process(head, mode)
   local p = head
   p = ltj.int_insert_jfm_glue(p,mode)
   p = ltj.int_insert_kanji_skip(p)
   p = main4_set_ja_width(p)
   return p
end


-- debug
local debug_depth
function ltj.ext_show_node_list(head,depth,print_fn)
   debug_depth = depth
   if head then
      while head do
	 debug_show_node_X(head, print_fn); head = node_next(head)
      end
   else
      print_fn(debug_depth .. ' (null list)')
   end
end
function ltj.ext_show_node(head,depth,print_fn)
   debug_depth = depth
   if head then
      debug_show_node_X(head, print_fn)
   else
      print_fn(debug_depth .. ' (null list)')
   end
end
function debug_show_node_X(p,print_fn)
   local k = debug_depth
   local s
   local pt=node_type(p.id)
   if pt == 'glyph' then
      print_fn(debug_depth.. ' GLYPH  ', p.subtype, utf.char(p.char), p.font)
   elseif pt=='hlist' then
      s = debug_depth .. ' hlist  ' ..  p.subtype
	 .. '(' .. print_scaled(p.height) .. '+' .. print_scaled(p.depth) .. ')x'
         .. print_scaled(p.width)
      if p.glue_sign >= 1 then 
	 s = s .. ' glue set '
	 if p.glue_sign == 2 then s = s .. '-' end
	 s = s .. tostring(math.floor(p.glue_set*10000)/10000)
	 if p.glue_order == 0 then 
	    s = s .. 'pt' 
	 else 
	    s = s .. 'fi'
	    for i = 2,  p.glue_order do s = s .. 'l' end
	 end
      end
      print_fn(s)
      local q = p.head
      debug_depth=debug_depth.. '.'
      while q do 
	 debug_show_node_X(q, print_fn); q = node_next(q)
      end
      debug_depth=k
   elseif pt == 'glue' then
      s = debug_depth.. ' glue   ' ..  p.subtype 
	 .. ' ' ..  print_spec(p.spec)
      if has_attr(p, attr_icflag)==TEMPORARY then
	 s = s .. ' (might be replaced)'
      elseif has_attr(p, attr_icflag)==FROM_JFM then
	    s = s .. ' (from JFM)'
      elseif has_attr(p, attr_icflag)==KANJI_SKIP then
	 s = s .. ' (kanjiskip)'
      elseif has_attr(p, attr_icflag)==XKANJI_SKIP then
	 s = s .. ' (xkanjiskip)'
      end
      print_fn(s)
   elseif pt == 'kern' then
      s = debug_depth.. ' kern   ' ..  p.subtype
	 .. ' ' .. print_scaled(p.kern) .. 'pt'
      if has_attr(p, attr_icflag)==ITALIC then
	 s = s .. ' (italic correction)'
      elseif has_attr(p, attr_icflag)==TEMPORARY then
	 s = s .. ' (might be replaced)'
      elseif has_attr(p, attr_icflag)==FROM_JFM then
	 s = s .. ' (from JFM)'
      elseif has_attr(p, attr_icflag)==LINE_END then
	 s = s .. " (from 'lineend' in JFM)"
      end
      print_fn(s)
   elseif pt == 'penalty' then
      s = debug_depth.. ' penalty ' ..  tostring(p.penalty)
      if has_attr(p, attr_icflag)==KINSOKU then
	 s = s .. ' (for kinsoku)'
      end
      print_fn(s)
   elseif pt == 'whatsit' then
      s = debug_depth.. ' whatsit ' ..  tostring(p.subtype)
      if p.subtype==sid_user then
	 s = s .. ' user_id: ' .. p.user_id .. ' ' .. p.value
      else
	 s = s .. node.subtype(p.subtype)
      end
      print_fn(s)
   else
      print_fn(debug_depth.. ' ' .. node.type(p.id), p.subtype)
   end
   p=node_next(p)
end


-- callbacks
luatexbase.add_to_callback('pre_linebreak_filter', 
   function (head,groupcode)
     return main_process(head, true)
   end,'ltj.pre_linebreak_filter',2)
luatexbase.add_to_callback('hpack_filter', 
  function (head,groupcode,size,packtype)
     return main_process(head, false)
  end,'ltj.hpack_filter',2)
