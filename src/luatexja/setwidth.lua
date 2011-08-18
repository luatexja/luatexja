--
-- luatexja/setwidth.lua
--
luatexbase.provides_module({
  name = 'luatexja.setwidth',
  date = '2011/06/28',
  version = '0.1',
  description = '',
})
module('luatexja.setwidth', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

require('luatexja.base');      local ltjb = luatexja.base
require('luatexja.jfont');     local ltjf = luatexja.jfont

local node_type = node.type
local node_new = node.new
local node_tail = node.tail
local node_next = node.next
local has_attr = node.has_attribute
local set_attr = node.set_attribute
local node_insert_before = node.insert_before
local node_insert_after = node.insert_after
local round = tex.round

local id_glyph = node.id('glyph')
local id_kern = node.id('kern')
local id_hlist = node.id('hlist')
local id_vlist = node.id('vlist')
local id_rule = node.id('rule')
local id_math = node.id('math')

local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_yablshift = luatexbase.attributes['ltj@yablshift']
local attr_icflag = luatexbase.attributes['ltj@icflag']

local PACKED = 2

local met_tb = {}
local char_data = {}
local head

-- return true if and only if p is a Japanese character node
local function is_japanese_glyph_node(p)
   return p.font==has_attr(p, attr_curjfnt)
end

local function capsule_glyph(p, dir)
   local h, box, q, fwidth, fheight, fdepth
   p.xoffset= p.xoffset - round(met_tb.size*char_data.left)
   if char_data.width ~= 'prop' then
      fwidth = round(char_data.width*met_tb.size)
   else fwidth = p.width end
   fheight = round(met_tb.size*char_data.height)
   fdepth = round(met_tb.size*char_data.depth)
   if p.width ~= fwidth or p.height ~= fheight or p.depth ~= fdepth then
      local y_shift = - p.yoffset + (has_attr(p,attr_yablshift) or 0)
      p.yoffset = -round(met_tb.size*char_data.down)
      head, q = node.remove(head, p)
      local total = fwidth - p.width
      if total == 0 then
	 h = p; p.next = nil
      else
	 h = node_new(id_kern); h.subtype = 0
	 if char_data.align=='left' then
	    h.kern = total; p.next = h; h = p
	 elseif char_data.align=='right' then
	    h.kern = total; p.next = nil; h.next = p
	 elseif char_data.align=='middle' then
	    h.kern = round(total/2); p.next = h
	    h = node_new(id_kern); h.subtype = 0
	    h.kern = total - round(total/2); h.next = p
	 end
      end
      box = node_new(id_hlist); 
      box.width = fwidth; box.height = fheight; box.depth = fdepth
      box.glue_set = 0; box.glue_order = 0; box.head = h
      box.shift = y_shift; box.dir = dir or 'TLT'
      set_attr(box, attr_icflag, PACKED)
      if q then
	 head = node_insert_before(head, q, box)
      else
	 head = node_insert_after(head, node_tail(head), box)
      end
      return q
   else
      p.yoffset = p.yoffset - (has_attr(p, attr_yablshift) or 0) - round(met_tb.size*char_data.down)
      return node_next(p)
   end
end

function set_ja_width(ahead, dir)
   local p = ahead; head  = ahead
   local m = false -- is in math mode?
   while p do
      if p.id==id_glyph then
	 if is_japanese_glyph_node(p) then
	    met_tb = ltjf.font_metric_table[p.font]
	    char_data = ltjf.metrics[met_tb.jfm].char_type[has_attr(p, attr_jchar_class)]
	    p = capsule_glyph(p, dir)
	 else 
	    p.yoffset = p.yoffset - (has_attr(p,attr_yablshift) or 0); p = node_next(p)
	 end
      elseif p.id==id_math then
	 m = (p.subtype==0); p = node_next(p)
      else
	 if m then
	    if p.id==id_hlist or p.id==id_vlist then
	       p.shift = p.shift + (has_attr(p,attr_yablshift) or 0)
	    elseif p.id==id_rule then
	       local v = has_attr(p,attr_yablshift) or 0
	       p.height = p.height - v; p.depth = p.depth + v 
	    end
	 end
	 p = node_next(p)
      end
   end
   -- adjust attr_icflag
   tex.attribute[attr_icflag] = -(0x7FFFFFFF)
   return head
end
