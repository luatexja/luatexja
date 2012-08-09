--
-- luatexja/setwidth.lua
--
luatexbase.provides_module({
  name = 'luatexja.setwidth',
  date = '2012/07/19',
  version = '0.2',
  description = '',
})
module('luatexja.setwidth', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('jfont');     local ltjf = luatexja.jfont

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
local attr_ykblshift = luatexbase.attributes['ltj@ykblshift']
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_uniqid = luatexbase.attributes['ltj@uniqid']

local ltjf_font_metric_table = ltjf.font_metric_table

local PACKED = 2
local PROCESSED = 8
local IC_PROCESSED = 9

head = nil

luatexbase.create_callback("luatexja.set_width", "data", 
			   function (fstable, fmtable, jchar_class) 
			      return fstable 
			   end)

local fshift =  { down = 0, left = 0}

-- mode: true iff p will be always encapsuled by a hbox
function capsule_glyph(p, dir, mode, met, class)
   local char_data = met.size_cache.char_type[class]
   if not char_data then return node_next(p) end
   local fwidth = (char_data.width ~= 'prop') and char_data.width or p.width
   local fheight, fdepth = char_data.height, char_data.depth
   fshift.down = char_data.down; fshift.left = char_data.left
   fshift = luatexbase.call_callback("luatexja.set_width", fshift, met, class)
   if (mode or p.width ~= fwidth or p.height ~= fheight or p.depth ~= fdepth) then
      local y_shift, total = - p.yoffset + (has_attr(p,attr_ykblshift) or 0), fwidth - p.width
      local q; head, q = node.remove(head, p)
      p.yoffset, p.next = -fshift.down, nil
      if total ~= 0 and char_data.align~='left' then
	 p.xoffset = p.xoffset - fshift.left
	    + (((char_data.align=='right') and total) or round(total*0.5))
      else
	 p.xoffset = p.xoffset - fshift.left
      end
      local box = node_new(id_hlist); 
      box.width, box.height, box.depth = fwidth, fheight, fdepth
      box.head, box.shift, box.dir = p, y_shift, (dir or 'TLT')
      box.glue_set, box.glue_order = 0, 0
      set_attr(box, attr_icflag, PACKED)
      set_attr(box, attr_uniqid, has_attr(p, attr_uniqid) or 0)
      head = q and node_insert_before(head, q, box) 
               or node_insert_after(head, node_tail(head), box)
      return q
   else
      p.xoffset = p.xoffset - fshift.left
      p.yoffset = p.yoffset - (has_attr(p, attr_ykblshift) or 0) - fshift.down
      return node_next(p)
   end
end

function set_ja_width(ahead, dir)
   local p = ahead; head  = ahead
   local m = false -- is in math mode?
   while p do
      if (p.id==id_glyph) and (has_attr(p, attr_icflag) or 0)<=0 then
	 if p.font == has_attr(p, attr_curjfnt) then
	    set_attr(p, attr_icflag, PROCESSED)
	    p = capsule_glyph(p, dir, false, ltjf_font_metric_table[p.font], 
			      has_attr(p, attr_jchar_class))
	 else
	    set_attr(p, attr_icflag, PROCESSED) 
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
   tex.setattribute('global', attr_icflag, 0)
   return head
end
