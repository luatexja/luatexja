--
-- luatexja/otf.lua
--
luatexbase.provides_module({
  name = 'luatexja.adjust',
  date = '2012/09/27',
  version = '0.1',
  description = 'Advanced line adjustment for LuaTeX-ja',
})
module('luatexja.adjust', package.seeall)

local id_hlist = node.id('hlist')
local id_glue  = node.id('glue')
local id_glue_spec = node.id('glue_spec')
local attr_icflag = luatexbase.attributes['ltj@icflag']

local PACKED = 2
local FROM_JFM = 6
local KANJI_SKIP = 9
local XKANJI_SKIP = 10

local priority_table = {
   XKANJI_SKIP,
   FROM_JFM + 2,
   FROM_JFM + 1,
   FROM_JFM,
   FROM_JFM - 1,
   FROM_JFM - 2,
   KANJI_SKIP
}

local PROCESSED_BEGIN_FLAG = 32
local function get_attr_icflag(p)
   return (node.has_attribute(p, attr_icflag) or 0) % PROCESSED_BEGIN_FLAG
end

-- box 内で伸縮された glue の合計値を計算

local function get_stretched(q, go, gs)
   local qs = q.spec
   if not qs.writable then return 0 end
   if gs == 1 then -- stretching
      if qs.stretch_order == go then return qs.stretch end
   else -- shrinking
      if qs.shrink_order == go then return qs.shrink end
   end
end

local function get_total_stretched(p)
   local go, gf, gs = p.glue_order, p.glue_set, p.glue_sign
   local res = {
      [0] = 0,
      glue_set = gf, name = (gs==1) and 'stretch' or 'shrink'
   }
   for i=1,#priority_table do res[priority_table[i]]=0 end
   if go ~= 0 then return nil end
   if gs ~= 1 and gs ~= 2 then return res end
   for q in node.traverse_id(id_glue, p.head) do
      local a, ic = get_stretched(q, go, gs), get_attr_icflag(q)
      --print(ic)
      if   type(res[ic]) == 'number' then res[ic] = res[ic] + a
      else                                res[0]  = res[0]  + a
      end
   end
   return res
end

local function clear_stretch(p, ic, name)
   --print('clear ' .. ic)
   for q in node.traverse_id(id_glue, p.head) do
      if get_attr_icflag(q) == ic then
         local qs = q.spec
         if qs.writable then
            qs[name..'_order'], qs[name] = 0, 0
         end
      end
   end
end

local function set_stretch(p, after, before, ic, name)
   if before > 0 then
      --print (ic, before, after)
      local ratio = after/before
      for q in node.traverse_id(id_glue, p.head) do
         if get_attr_icflag(q) == ic then
            local qs = q.spec
            if qs.writable and qs[name..'_order'] == 0 then
               qs[name] = qs[name]*ratio
            end
         end
      end
   end
end


function adjust_width(head) 
   if not head then return head end
   for p in node.traverse_id(id_hlist, head) do
      local res = get_total_stretched(p)
      --print(table.serialize(res))
      if res then
         -- 調整量の合計
         local total = 0
         for i,v in pairs(res) do 
            if type(i)=='number' then
               total = total + v
            end
         end; total = tex.round(total * res.glue_set)
         if total <= res[0] then -- 和文処理グルー以外で足りる
            for _,v in pairs(priority_table) do clear_stretch(p, v, res.name) end
            local f = node.hpack(p.head, p.width, 'exactly')
            f.head, p.glue_set, p.glue_sign, p.glue_order 
               = nil, f.glue_set, f.glue_sign, f.glue_order
            node.free(f)
         else
            total = total - res[0]
            for i = 1, #priority_table do
               local v = priority_table[i]
               if total <= res[v] then
                  for j = i+1,#priority_table do
                     clear_stretch(p, priority_table[j], res.name)
                  end
                  set_stretch(p, total, res[v], v, res.name)
                  local f = node.hpack(p.head, p.width, 'exactly')
                  f.head, p.glue_set, p.glue_sign, p.glue_order 
                     = nil, f.glue_set, f.glue_sign, f.glue_order
                  node.free(f)
                  --print(p.glue_set, p.glue_sign, p.glue_order)
                  return head
               end
               total = total - res[v]
            end
         end
      end
   end
   return head
end

