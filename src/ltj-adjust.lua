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

luatexja.load_module('jfont');     local ltjf = luatexja.jfont

local id_glyph = node.id('glyph')
local id_kern = node.id('kern')
local id_hlist = node.id('hlist')
local id_glue  = node.id('glue')
local id_glue_spec = node.id('glue_spec')
local has_attr = node.has_attribute
local set_attr = node.set_attribute
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']

local ltjf_font_metric_table = ltjf.font_metric_table

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

-- step 1: 行末に kern を挿入（句読点，中点用）
local function aw_step1(p, res, total)
   local x = node.tail(p.head); if not x then return false end
   local x = node.prev(x)     ; if not x then return false end
   -- 本当の行末の node を格納
   if x.id == id_glue and x.subtype == 15 then 
      -- 段落最終行のときは，\penalty10000 \parfillskip が入るので，
      -- その前の node が本来の末尾文字となる
      x = node.prev(node.prev(x)) 
   end

   local xc
   if x.id == id_glyph and has_attr(x, attr_curjfnt) == x.font then
      -- 和文文字
      xc = x
   elseif x.id == id_hlist and get_attr_icflag(x) == PACKED then
      -- packed JAchar
      xc = x.head
   else
     return false-- それ以外は対象外．
   end
   local xk = ltjf_font_metric_table -- 
     [xc.font].size_cache.char_type[has_attr(xc, attr_jchar_class) or 0]
     ['end_' .. res.name] or 0
     print(res.name, total, xk, unicode.utf8.char(xc.char))

   if xk>0 and total>=xk then
      print("ADDED")
      total = total - xk
      local kn = node.new(id_kern)
      kn.kern = (res.name=='shrink' and -1 or 1) * xk
      set_attr(kn, attr_icflag, FROM_JFM)
      node.insert_after(p.head, x, kn)
      return true
   else return false
   end
end

-- step 2: 行中の glue を変える
local function aw_step2(p, res, total, added_flag)
   if total == 0 then -- もともと伸縮の必要なし
      if added_flag then -- 行末に kern 追加したので，それによる補正
	 local f = node.hpack(p.head, p.width, 'exactly')
	 f.head, p.glue_set, p.glue_sign, p.glue_order 
	    = nil, f.glue_set, f.glue_sign, f.glue_order
	 node.free(f); return
      end
   elseif total <= res[0] then -- 和文処理グルー以外で足りる
      for _,v in pairs(priority_table) do clear_stretch(p, v, res.name) end
      local f = node.hpack(p.head, p.width, 'exactly')
      f.head, p.glue_set, p.glue_sign, p.glue_order 
         = nil, f.glue_set, f.glue_sign, f.glue_order
      node.free(f)
   else
      total, i = total - res[0], 1
      while i <= #priority_table do
         local v = priority_table[i]
         if total <= res[v] then
            for j = i+1,#priority_table do
               clear_stretch(p, priority_table[j], res.name)
            end
            set_stretch(p, total, res[v], v, res.name)
            i = #priority_table + 9 -- ループから抜けさせたいため
         end
         total, i= total - res[v], i+1
      end
      if i == #priority_table + 10 or added_flag then
	 local f = node.hpack(p.head, p.width, 'exactly')
	 f.head, p.glue_set, p.glue_sign, p.glue_order 
	    = nil, f.glue_set, f.glue_sign, f.glue_order
	 node.free(f)
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
         local added_flag = aw_step1(p, res, total)
         aw_step2(p, res, total, added_flag)
      end
   end
   return head
end

