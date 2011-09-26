--
-- luatexja/stack.lua
--
luatexbase.provides_module({
  name = 'luatexja.stack',
  date = '2011/04/01',
  version = '0.1',
  description = 'LuaTeX-ja stack system',
})
module('luatexja.stack', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

require('luatexja.base');      local ltjb = luatexja.base

local node_new = node.new
local id_whatsit = node.id('whatsit')
local sid_user = node.subtype('user_defined')

local charprop_stack_table={}; charprop_stack_table[0]={}

function get_stack_level()
   local i = tex.getcount('ltj@@stack')
   if tex.nest[tex.nest.ptr].mode == 127 or
      tex.nest[tex.nest.ptr].mode == -127 then
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
	 local g = node_new(id_whatsit, sid_user)
	 g.user_id=30112; g.type=100; g.value=j; node.write(g)
      end
   end
   return i
end

-- EXT
function set_stack_table(g,m,c,p,lb,ub)
   local i = get_stack_level()
   if p<lb or p>ub then 
      ltjb.package_error('luatexja',
			 "invalid code (".. p .. ")",
			 {"The code should in the range "..tostring(lb) ..'..'.. tostring(ub) .. ".",
			  "I'm going to use 0 instead of that illegal code value."})
      p=0
   elseif c<-1 or c>0x10ffff then 
      ltjb.package_error('luatexja',
			 'bad character code (' .. c .. ')',
			 {'A character number must be between -1 and 0x10ffff.',
			  "(-1 is used for denoting `math boundary')",
			  'So I changed this one to zero.'})
      c=0
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

-- EXT
function set_stack_font(g,m,c,p)
   local i = get_stack_level()
   if c<0 or c>255 then 
      ltjb.package_error('luatexja',
			 "invalid family number (".. p .. ")",
			 {"The family number should in the range 0 .. 255.",
			  "I'm going to use 0 instead of that illegal family number."})
      c=0
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

-- EXT: store \ltj@tempskipa
function set_stack_skip(g,c,sp)
  local i = get_stack_level()
  if not sp then return end
  if not charprop_stack_table[i][c] then 
     charprop_stack_table[i][c] = {} 
  end
  charprop_stack_table[i][c].width   = sp.width
  charprop_stack_table[i][c].stretch = sp.stretch
  charprop_stack_table[i][c].shrink  = sp.shrink
  charprop_stack_table[i][c].stretch_order = sp.stretch_order
  charprop_stack_table[i][c].shrink_order  = sp.shrink_order
  if g=='global' then
     for j,v in pairs(charprop_stack_table) do 
	if not charprop_stack_table[j][c] then charprop_stack_table[j][c] = {} end
	charprop_stack_table[j][c].width   = sp.width
	charprop_stack_table[j][c].stretch = sp.stretch
	charprop_stack_table[j][c].shrink  = sp.shrink
	charprop_stack_table[j][c].stretch_order = sp.stretch_order
	charprop_stack_table[j][c].shrink_order  = sp.shrink_order
     end
  end
end

-- mode: nil iff it is called in callbacks
function get_skip_table(m, idx)
   local i = charprop_stack_table[idx][m]
   return i or { width = 0, stretch = 0, shrink = 0,
		 stretch_order = 0, shrink_order = 0 }
end

function get_penalty_table(m,c,d, idx)
   local i = charprop_stack_table[idx][c]
   if i then i=i[m] end
   return i or d
end

-- EOF
