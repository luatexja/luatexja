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
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_uniqid = luatexbase.attributes['ltj@uniqid']

local ltjf_font_metric_table = ltjf.font_metric_table

local PACKED = 2

char_data = {}
head = nil

-- return true if and only if p is a Japanese character node
local function is_japanese_glyph_node(p)
   return p.font==has_attr(p, attr_curjfnt)
end

luatexbase.create_callback("luatexja.set_width", "data", 
			   function (fstable, fmtable, jchar_class) 
			      return fstable 
			   end)

local fshift =  { down = 0, left = 0}
-- mode: true iff p will be always encapsuled by a hbox
function capsule_glyph(p, dir, mode, met, class)
   local h, box, q, fwidth
   if char_data.width ~= 'prop' then
      fwidth = char_data.width
   else fwidth = p.width end
   local fheight = char_data.height
   local fdepth = char_data.depth
   fshift.down = char_data.down; fshift.left = char_data.left
   fshift = luatexbase.call_callback("luatexja.set_width", fshift, met, class)
--   local ti = 
   p.xoffset= p.xoffset - fshift.left
   if mode or p.width ~= fwidth or p.height ~= fheight or p.depth ~= fdepth then
      local y_shift = - p.yoffset + (has_attr(p,attr_yablshift) or 0)
      p.yoffset = -fshift.down
      head, q = node.remove(head, p)
      local total = fwidth - p.width
      if total == 0 then
	 h = p; p.next = nil
      else
	 h = node_new(id_kern); h.subtype = 0
	 if char_data.align=='right' then
	    h.kern = total; p.next = nil; h.next = p
	 elseif char_data.align=='middle' then
	    h.kern = round(total/2); p.next = h
	    h = node_new(id_kern); h.subtype = 0
	    h.kern = total - round(total/2); h.next = p
	 else -- left
	    h.kern = total; p.next = h; h = p
	 end
      end
      box = node_new(id_hlist); 
      box.width = fwidth; box.height = fheight; box.depth = fdepth
      box.glue_set = 0; box.glue_order = 0; box.head = h
      box.shift = y_shift; box.dir = dir or 'TLT'
      set_attr(box, attr_icflag, PACKED)
      set_attr(box, attr_uniqid, has_attr(p, attr_uniqid) or 0)
      if q then
	 head = node_insert_before(head, q, box)
      else
	 head = node_insert_after(head, node_tail(head), box)
      end
      return q
   else
      p.yoffset = p.yoffset - (has_attr(p, attr_yablshift) or 0) - fshift.down
      return node_next(p)
   end
end

function set_ja_width(ahead, dir)
   local p = ahead; head  = ahead
   local m = false -- is in math mode?
   while p do
      if p.id==id_glyph then
	 if is_japanese_glyph_node(p) then
	    local met = ltjf_font_metric_table[p.font]
	    local class = has_attr(p, attr_jchar_class)
	    char_data = ltjf.metrics[met.jfm].size_cache[met.size].char_type[class]
            if char_data then
               p = capsule_glyph(p, dir, false, met, class)
            else
               p = node_next(p)
            end
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
