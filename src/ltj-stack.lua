--
-- ltj-stack.lua
--
luatexbase.provides_module({
  name = 'luatexja.stack',
  date = '2020-07-30',
  description = 'LuaTeX-ja stack system',
})
luatexja.stack = {}
local ltjs=luatexja.stack
luatexja.load_module 'base';      local ltjb = luatexja.base

--------------------------------------------------------------------------------
-- stack table (obeys TeX's grouping)
--------------------------------------------------------------------------------
local node_new = node.new
local id_whatsit = node.id 'whatsit'
local sid_user = node.subtype 'user_defined'
local STCK = luatexja.userid_table.STCK
local fastcopy = table.fastcopy
local setcount, getcount = tex.setcount, tex.getcount
local scan_int, scan_keyword = token.scan_int, token.scan_keyword
ltjs.hmode = 0 -- dummy

local charprop_stack_table={};
ltjs.charprop_stack_table = charprop_stack_table
charprop_stack_table[0]={}

local function get_stack_level()
   local i = getcount 'ltj@@stack'
   local j = tex.currentgrouplevel
   if j > getcount 'ltj@@group@level' then
      i = i+1 -- new stack level
      local gd = tex.globaldefs
      if gd~=0 then tex.globaldefs = 0 end
      --  'tex.globaldefs = 0' is local even if \globaldefs > 0.
      setcount('ltj@@group@level', j)
      for k,v in pairs(charprop_stack_table) do -- clear the stack above i
         if k>=i then charprop_stack_table[k]=nil end
      end
      charprop_stack_table[i] = fastcopy(charprop_stack_table[i-1])
      setcount('ltj@@stack', i)
      if gd~=0 then tex.globaldefs = gd end
      if  tex.nest[tex.nest.ptr].mode == -ltjs.hmode then -- rest. hmode のみ
         local g = node_new(id_whatsit, sid_user)
         g.user_id=STCK; g.type=100; g.value=j; node.write(g)
      end
   end
   return i
end
ltjs.get_stack_level = get_stack_level

local function set_stack_table(m, p)
   local i = get_stack_level()
   charprop_stack_table[i][m] = p
   if luatexja.isglobal=='global' then
      for j,v in pairs(charprop_stack_table) do
         charprop_stack_table[j][m] = p
      end
   end
end
ltjs.set_stack_table = set_stack_table

-- EXT
function ltjs.set_stack_perchar(m,lb,ub, getter)
   local c = scan_int()
   scan_keyword(',')
   local p = tonumber((getter or scan_int)())
   if p<lb or p>ub then
      ltjb.package_error('luatexja',
                         "invalid code (".. tostring(p) .. ")",
                         "The code should in the range "..tostring(lb) .. '..' ..
                         tostring(ub) .. ".\n" ..
                        "I'm going to use 0 instead of that illegal code value.")
      p=0
   end
   set_stack_table(m+ltjb.in_unicode(c, true), p)
end

-- EXT
function ltjs.set_stack_font(m,c,p)
   if type(c)~='number' or c<0 or c>255 then
      ltjb.package_error('luatexja',
                         "invalid family number (".. tostring(c) .. ")",
                         "The family number should in the range 0 .. 255.\n" ..
                          "I'm going to use 0 instead of that illegal family number.")
      c=0
   end
   set_stack_table(m+c, p)
end

-- EXT: sp: glue_spec
function ltjs.set_stack_skip(m,sp)
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
  if luatexja.isglobal=='global' then
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
-- list_dir and orig_char_table are used in other lua files.
local orig_char_table = {}
ltjs.orig_char_table = orig_char_table
ltjs.list_dir = nil -- dummy
ltjs.table_current_stack = nil -- dummy
function ltjs.report_stack_level(bsl)
   ltjs.table_current_stack = charprop_stack_table[bsl]
   return bsl
end
function ltjs.fast_get_stack_skip(m)
   return ltjs.table_current_stack[m]
      or { width = 0, stretch = 0, shrink = 0, stretch_order = 0, shrink_order = 0 }
end

-- For other situations, use the following instead:
function ltjs.get_stack_skip(m, idx)
   return charprop_stack_table[idx][m]
      or { width = 0, stretch = 0, shrink = 0, stretch_order = 0, shrink_order = 0 }
end
function ltjs.get_stack_table(mc, d, idx)
   local i = charprop_stack_table[idx][mc]
   return i or d
end


-- EOF
