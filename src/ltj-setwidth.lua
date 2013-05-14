--
-- luatexja/setwidth.lua
--
luatexbase.provides_module({
  name = 'luatexja.setwidth',
  date = '2013/03/14',
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

local ltjf_font_metric_table = ltjf.font_metric_table

local PACKED = 2
local PROCESSED = 11
local IC_PROCESSED = 12
local PROCESSED_BEGIN_FLAG = 32

do
   local floor = math.floor
   function get_pr_begin_flag(p)
      local i = has_attr(p, attr_icflag) or 0
      return i - i%PROCESSED_BEGIN_FLAG
   end
end
local get_pr_begin_flag = get_pr_begin_flag

head = nil

luatexbase.create_callback("luatexja.set_width", "data", 
			   function (fstable, fmtable, jchar_class) 
			      return fstable 
			   end)

local fshift =  { down = 0, left = 0}

-- mode: true iff p will be always encapsuled by a hbox
function capsule_glyph(p, dir, mode, met, class)
   local char_data = met.char_type[class]
   if not char_data then return node_next(p) end
   local fwidth, pwidth = char_data.width, p.width
   fwidth = (fwidth ~= 'prop') and fwidth or pwidth
   local fheight, fdepth = char_data.height, char_data.depth
   fshift.down = char_data.down; fshift.left = char_data.left
   fshift = luatexbase.call_callback("luatexja.set_width", fshift, met, class)
   if (mode or pwidth ~= fwidth or p.height ~= fheight or p.depth ~= fdepth) then
      local y_shift, ca
         = - p.yoffset + (has_attr(p,attr_ykblshift) or 0), char_data.align
      local q; head, q = node.remove(head, p)
      p.yoffset, p.next = -fshift.down, nil
      if total ~= 0 and ca~='left'  then
	 p.xoffset = p.xoffset - fshift.left
	    + (((ca=='right') and fwidth - pwidth) or round((fwidth - pwidth)*0.5))
      else
	 p.xoffset = p.xoffset - fshift.left
      end
      local box = node_new(id_hlist); 
      box.width, box.height, box.depth = fwidth, fheight, fdepth
      box.head, box.shift, box.dir = p, y_shift, (dir or 'TLT')
      --box.glue_set, box.glue_order = 0, 0 not needed
      set_attr(box, attr_icflag, PACKED + get_pr_begin_flag(p))
      head = q and node_insert_before(head, q, box) 
               or node_insert_after(head, node_tail(head), box)
      return q
   else
      set_attr(p, attr_icflag, PROCESSED + get_pr_begin_flag(p))
      p.xoffset = p.xoffset - fshift.left
      p.yoffset = p.yoffset - (has_attr(p, attr_ykblshift) or 0) - fshift.down
      return node_next(p)
   end
end

function set_ja_width(ahead, dir)
   local p = ahead; head  = ahead
   local m = false -- is in math mode?
   while p do
      if (p.id==id_glyph) 
      and ((has_attr(p, attr_icflag) or 0)%PROCESSED_BEGIN_FLAG)<=0 then
      local pf = p.font
	 if pf == has_attr(p, attr_curjfnt) then
	    p = capsule_glyph(p, dir, false, ltjf_font_metric_table[pf], 
			      has_attr(p, attr_jchar_class))
	 else
	    set_attr(p, attr_icflag, PROCESSED + get_pr_begin_flag(p))
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
