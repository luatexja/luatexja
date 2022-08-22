--
-- ltj-stack.lua
--
luatexbase.provides_module({
  name = 'luatexja.stack',
  date = '2022-08-20',
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
local getnest = tex.getnest
local cnt_stack = luatexbase.registernumber 'ltj@@stack'
local cnt_grplvl = luatexbase.registernumber 'ltj@@group@level'
ltjs.hmode = 0 -- dummy

local charprop_stack_table={}
ltjs.charprop_stack_table = charprop_stack_table
charprop_stack_table[0]={}

local function get_stack_level()
   local i = getcount(cnt_stack)
   local j = tex.currentgrouplevel
   if j > getcount(cnt_grplvl) then
      i = i+1 -- new stack level
      local gd = tex.globaldefs
      if gd~=0 then tex.globaldefs = 0 end
      --  'tex.globaldefs = 0' is local even if \globaldefs > 0.
      setcount(cnt_grplvl, j)
      for k,v in pairs(charprop_stack_table) do -- clear the stack above i
         if k>=i then charprop_stack_table[k]=nil end
      end
      charprop_stack_table[i] = fastcopy(charprop_stack_table[i-1])
      setcount(cnt_stack, i)
      if gd~=0 then tex.globaldefs = gd end
      if getnest().mode == -ltjs.hmode then -- rest. hmode のみ
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
      for j,v in pairs(charprop_stack_table) do v[m] = p end
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
local getglue = node.getglue
function ltjs.set_stack_skip(m,sp)
  local i = get_stack_level()
  if not sp then return end
  local w,st,sh,sto,sho = getglue(sp)
  if charprop_stack_table[i][m] then
     local c = charprop_stack_table[i][m]
     c[1], c[2], c[3], c[4], c[5] = w, st, sh, sto, sho
  else
     charprop_stack_table[i][m] = { w,st,sh,sto,sho }
  end
  if luatexja.isglobal=='global' then
     for j,v in pairs(charprop_stack_table) do
        if not v[m] then v[m] = { true,true,true,true,true } end
        local c = v[m]
        c[1], c[2], c[3], c[4], c[5] = w, st, sh, sto, sho
     end
  end
end

-- These three functions are used in ltj-jfmglue.lua.
-- list_dir and orig_char_table are used in other lua files.
local orig_char_table = {}
ltjs.orig_char_table = orig_char_table
ltjs.list_dir = nil -- dummy
ltjs.table_current_stack = nil -- dummy
local dummy_skip_table = { 0,0,0,0,0 }
function ltjs.report_stack_level(bsl)
   ltjs.table_current_stack = charprop_stack_table[bsl]
   return bsl
end
function ltjs.fast_get_stack_skip(m)
   return ltjs.table_current_stack[m] or dummy_skip_table
end

-- For other situations, use the following instead:
function ltjs.get_stack_skip(m, idx)
   return charprop_stack_table[idx][m] or dummy_skip_table
end
function ltjs.get_stack_table(mc, d, idx)
   return charprop_stack_table[idx][mc] or d
end


-- EOF
