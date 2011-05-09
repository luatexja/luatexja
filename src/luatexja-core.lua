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

local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_yablshift = luatexbase.attributes['ltj@yablshift']
local attr_ykblshift = luatexbase.attributes['ltj@ykblshift']
local attr_icflag = luatexbase.attributes['ltj@icflag']
-- attr_icflag: 1: kern from \/, 2: 'lineend' kern from JFM

local lang_ja_token = token.create('ltj@japanese')
local lang_ja = lang_ja_token[2]

-- 
local rgjc_get_range_setting = ltj.int_get_range_setting 
local rgjc_char_to_range     = ltj.int_char_to_range
local rgjc_is_ucs_in_japanese_char = ltj.int_is_ucs_in_japanese_char
local ljfm_find_char_class = ltj.int_find_char_class


local ITALIC = 1
local TEMPORARY = 2
local FROM_JFM = 3
local KINSOKU = 4
local LINE_END = 5
local KANJI_SKIP = 6
local XKANJI_SKIP = 7

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

------------------------------------------------------------------------
-- CODE FOR STACK TABLE FOR CHARACTER PROPERTIES (prefix: cstb)
------------------------------------------------------------------------

---- table: charprop_stack_table [stack_level][chr_code].{pre|post|xsp}
local charprop_stack_table={}; charprop_stack_table[0]={}

local function cstb_get_stack_level()
  local i = tex.getcount('ltj@@stack')
  if tex.currentgrouplevel > tex.getcount('ltj@@group@level') then
    i = i+1 -- new stack level
    tex.setcount('ltj@@group@level', tex.currentgrouplevel)
    for j,v in pairs(charprop_stack_table) do -- clear the stack above i
      if j>=i then charprop_stack_table[j]=nil end
    end
    charprop_stack_table[i] = table.fastcopy(charprop_stack_table[i-1])
    tex.setcount('ltj@@stack', i)
  end
  return i
end

-- EXT
function ltj.ext_set_stack_table(g,m,c,p,lb,ub)
  local i = cstb_get_stack_level()
  if p<lb or p>ub then 
     ltj.error('Invalid code (' .. p .. '), should in the range '
	       .. tostring(lb) .. '..' .. tostring(ub) .. '.',
	    {"I'm going to use 0 instead of that illegal code value."})
     p=0
  elseif c<-1 or c>0x10FFFF then
     ltj.error('Invalid character code (' .. c
	       .. '), should in the range -1.."10FFFF.',{})
     return 
  elseif not charprop_stack_table[i][c] then 
     charprop_stack_table[i][c] = {} 
  end
  charprop_stack_table[i][c][m] = p
  if g=='global' then
    for j,v in pairs(charprop_stack_table) do 
      if not charprop_stack_table[j][c] then charprop_stack_table[j][c] = {} end
      charprop_stack_table[j][c][m] = p
    end
  end
end

local function cstb_get_penalty_table(m,c)
  local i = charprop_stack_table[tex.getcount('ltj@@stack')][c]
  if i then i=i[m] end
  return i or 0
end
ltj.int_get_penalty_table = cstb_get_penalty_table

local function cstb_get_inhibit_xsp_table(c)
  local i = charprop_stack_table[tex.getcount('ltj@@stack')][c]
  if i then i=i.xsp end
  return i or 3
end
ltj.int_get_inhibit_xsp_table = cstb_get_inhibit_xsp_table

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
      tex.write(print_spec(tex.getskip('kanjiskip')))
   elseif k == 'xkanjiskip' then
      tex.write(print_spec(tex.getskip('xkanjiskip')))
   elseif k == 'jcharwidowpenalty' then
      tex.write(tex.getcount('jcharwidowpenalty'))
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
      tex.write(rgjc_get_range_setting(c))
   else
      if c<0 or c>0x10FFFF then
	 ltj.error('Invalid character code (' .. c 
		   .. '), should in the range 0.."10FFFF.',
		{"I'm going to use 0 instead of that illegal character code."})
	 c=0
      end
      if k == 'prebreakpenalty' then
	 tex.write(cstb_get_penalty_table('pre',c))
      elseif k == 'postbreakpenalty' then
	 tex.write(cstb_get_penalty_table('post',c))
      elseif k == 'kcatcode' then
	 tex.write(cstb_get_penalty_table('kcat',c))
      elseif k == 'chartorange' then 
	 tex.write(rgjc_char_to_range(c))
      elseif k == 'jaxspmode' or k == 'alxspmode' then
	 tex.write(cstb_get_inhibit_xsp_table(c))
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

--- the following function is modified from jafontspec.lua (by K. Maeda).
--- Instead of "%", we use U+FFFFF for suppressing spaces.
local function main1_process_input_buffer(buffer)
   local c = utf.byte(buffer, utf.len(buffer))
   local p = node_new(id_glyph)
   p.char = c
   if utf.len(buffer) > 0 
   and rgjc_is_ucs_in_japanese_char(p) then
	buffer = buffer .. string.char(0xF3,0xBF,0xBF,0xBF) -- U+FFFFF
   end
   return buffer
end

local function main1_suppress_hyphenate_ja(head)
   local p
   for p in node.traverse(head) do
      if p.id == id_glyph then
	 if rgjc_is_ucs_in_japanese_char(p) then
	    local v = has_attr(p, attr_curjfnt)
	    if v then 
	       p.font = v 
	       node.set_attribute(p,attr_jchar_class,
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
   end
   lang.hyphenate(head)
   return head
end

-- CALLBACKS
luatexbase.add_to_callback('process_input_buffer', 
   function (buffer)
     return main1_process_input_buffer(buffer)
   end,'ltj.process_input_buffer')
luatexbase.add_to_callback('hpack_filter', 
  function (head,groupcode,size,packtype)
     return main1_suppress_hyphenate_ja(head)
  end,'ltj.hpack_filter_pre',0)
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
   elseif pt == 'whatsit' then
      print_fn(debug_depth.. ' whatsit', p.subtype)
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
