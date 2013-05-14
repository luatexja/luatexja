--
-- luatexja/stack.lua
--
luatexbase.provides_module({
  name = 'luatexja.stack',
  date = '2013/04/13',
  description = 'LuaTeX-ja stack system',
})
module('luatexja.stack', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

luatexja.load_module('base');      local ltjb = luatexja.base

local node_new = node.new
local id_whatsit = node.id('whatsit')
local sid_user = node.subtype('user_defined')
local STCK = luatexja.userid_table.STCK
hmode = 0 -- dummy 

charprop_stack_table={}; 
local charprop_stack_table = charprop_stack_table
charprop_stack_table[0]={}


function get_stack_level()
   local i = tex.getcount('ltj@@stack')
   local j = tex.currentgrouplevel
   if j > tex.getcount('ltj@@group@level') then
      i = i+1 -- new stack level
      local gd = tex.globaldefs
      if gd>0 then tex.globaldefs = 0 end
      --  'tex.globaldefs = 0' is local even if \globaldefs > 0.
      tex.setcount('ltj@@group@level', j)
      for k,v in pairs(charprop_stack_table) do -- clear the stack above i
	 if k>=i then charprop_stack_table[k]=nil end
      end
      charprop_stack_table[i] = table.fastcopy(charprop_stack_table[i-1])
      tex.setcount('ltj@@stack', i)
      if gd>0 then tex.globaldefs = gd end
      if tex.nest[tex.nest.ptr].mode == hmode or
	 tex.nest[tex.nest.ptr].mode == -hmode then
	 local g = node_new(id_whatsit, sid_user)
	 g.user_id=STCK; g.type=100; g.value=j; node.write(g)
      end
   end
   return i
end

-- local function table_to_str(v) 
--    local s = ''
--    for i, a in pairs(v) do
--       s = s .. i .. "=" .. tostring(a) .. ', '
--    end
--    return s
-- end
-- function print_stack_table(i)
--    print('\n>>> get_stack_level:')
--    for k, v in pairs(charprop_stack_table[i]) do
--       print("  " , k, type(k), table_to_str(v));
--    end
-- end


-- EXT
function set_stack_table(g,m,c,p,lb,ub)
   local i = get_stack_level()
   if type(p)~='number' or p<lb or p>ub then
      ltjb.package_error('luatexja',
			 "invalid code (".. tostring(p) .. ")",
			 "The code should in the range "..tostring(lb) .. '..' ..
			 tostring(ub) .. ".\n" ..
		      "I'm going to use 0 instead of that illegal code value.")
      p=0
   elseif type(c)~='number' or c<-1 or c>0x10ffff then
      ltjb.package_error('luatexja',
			 'bad character code (' .. tostring(c) .. ')',
			 'A character number must be between -1 and 0x10ffff.\n' ..
			 "(-1 is used for denoting `math boundary')\n" ..
			 'So I changed this one to zero.')
      c=0
   end
   charprop_stack_table[i][c+m] = p
  if g=='global' then
     for j,v in pairs(charprop_stack_table) do 
	charprop_stack_table[j][c+m] = p
     end
  end
end

-- EXT
function set_stack_font(g,m,c,p)
   local i = get_stack_level()
   if type(c)~='number' or c<0 or c>255 then 
      ltjb.package_error('luatexja',
			 "invalid family number (".. tostring(c) .. ")",
			 "The family number should in the range 0 .. 255.\n" ..
			  "I'm going to use 0 instead of that illegal family number.")
      c=0
   end
   charprop_stack_table[i][c+m] = p
   if g=='global' then
     for j,v in pairs(charprop_stack_table) do 
	charprop_stack_table[j][c+m] = p
     end
  end
end

-- EXT: store \ltj@tempskipa
function set_stack_skip(g,m,sp)
  local i = get_stack_level()
  if not sp then return end
  if not charprop_stack_table[i][m] then 
     charprop_stack_table[i][m] = {} 
  end
  charprop_stack_table[i][m].width   = sp.width
  charprop_stack_table[i][m].stretch = sp.stretch
  charprop_stack_table[i][m].shrink  = sp.shrink
  charprop_stack_table[i][m].stretch_order = sp.stretch_order
  charprop_stack_table[i][m].shrink_order  = sp.shrink_order
  if g=='global' then
     for j,v in pairs(charprop_stack_table) do 
	if not charprop_stack_table[j][m] then charprop_stack_table[j][m] = {} end
	charprop_stack_table[j][m].width   = sp.width
	charprop_stack_table[j][m].stretch = sp.stretch
	charprop_stack_table[j][m].shrink  = sp.shrink
	charprop_stack_table[j][m].stretch_order = sp.stretch_order
	charprop_stack_table[j][m].shrink_order  = sp.shrink_order
     end
  end
end

-- These three functions are used in ltj-jfmglue.lua.
function report_stack_level(bsl)
   table_current_stack = charprop_stack_table[bsl]
end
function fast_get_skip_table(m)
   return table_current_stack[m] 
      or { width = 0, stretch = 0, shrink = 0, stretch_order = 0, shrink_order = 0 }
end

-- For other situations, use the following instead:
function get_skip_table(m, idx)
   return charprop_stack_table[idx][m] 
      or { width = 0, stretch = 0, shrink = 0, stretch_order = 0, shrink_order = 0 }
end
function get_penalty_table(mc, d, idx)
   local i = charprop_stack_table[idx][mc]
   return i or d
end


-- EOF
