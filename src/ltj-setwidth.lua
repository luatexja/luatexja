--
-- src/ltj-setwidth.lua
--

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('jfont');     local ltjf = luatexja.jfont

local Dnode = node.direct or node
local setfield = (Dnode ~= node) and Dnode.setfield or function(n, i, c) n[i] = c end
local getfield = (Dnode ~= node) and Dnode.getfield or function(n, i) return n[i] end
local getid = (Dnode ~= node) and Dnode.getid or function(n) return n.id end
local getfont = (Dnode ~= node) and Dnode.getfont or function(n) return n.font end
local getlist = (Dnode ~= node) and Dnode.getlist or function(n) return n.head end
local getchar = (Dnode ~= node) and Dnode.getchar or function(n) return n.char end
local getsubtype = (Dnode ~= node) and Dnode.getsubtype or function(n) return n.subtype end

local node_traverse = Dnode.traverse
local node_new = Dnode.new
local node_remove = luatexja.Dnode_remove -- Dnode.remove
local node_tail = Dnode.tail
local node_next = (Dnode ~= node) and Dnode.getnext or node.next
local has_attr = Dnode.has_attribute
local set_attr = Dnode.set_attribute
local node_insert_before = Dnode.insert_before
local node_insert_after = Dnode.insert_after
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

local PACKED       = luatexja.icflag_table.PACKED
local PROCESSED    = luatexja.icflag_table.PROCESSED
local IC_PROCESSED = luatexja.icflag_table.IC_PROCESSED
local PROCESSED_BEGIN_FLAG = luatexja.icflag_table.PROCESSED_BEGIN_FLAG

local get_pr_begin_flag
do
   local floor = math.floor
   get_pr_begin_flag = function (p)
      local i = has_attr(p, attr_icflag) or 0
      return i - i%PROCESSED_BEGIN_FLAG
   end
end

local head, dir
local ltjw = {} --export
luatexja.setwidth = ltjw

luatexbase.create_callback("luatexja.set_width", "data", 
			   function (fstable, fmtable, jchar_class) 
			      return fstable 
			   end)
local call_callback = luatexbase.call_callback

local fshift =  { down = 0, left = 0}

-- mode: true iff p will be always encapsuled by a hbox
local function capsule_glyph(p, met, class)
   local char_data = met.char_type[class]
   if not char_data then return node_next(p) end
   local fwidth, pwidth = char_data.width, getfield(p, 'width')
   fwidth = (fwidth ~= 'prop') and fwidth or pwidth
   fshift.down = char_data.down; fshift.left = char_data.left
   fshift = call_callback("luatexja.set_width", fshift, met, class)
   local fheight, fdepth = char_data.height, char_data.depth
   if (pwidth ~= fwidth or getfield(p, 'height') ~= fheight or getfield(p, 'depth') ~= fdepth) then
      local y_shift
         = - getfield(p, 'yoffset') + (has_attr(p,attr_ykblshift) or 0)
      local q
      head, q = node_remove(head, p)
      setfield(p, 'yoffset', -fshift.down); setfield(p, 'next', nil)
      setfield(p, 'xoffset', getfield(p, 'xoffset') + char_data.align*(fwidth-pwidth) - fshift.left)
      local box = node_new(id_hlist)
      setfield(box, 'width', fwidth)
      setfield(box, 'height', fheight)
      setfield(box, 'depth', fdepth)
      setfield(box, 'head', p)
      setfield(box, 'shift', y_shift)
      setfield(box, 'dir', dir)
      set_attr(box, attr_icflag, PACKED + get_pr_begin_flag(p))
      head = q and node_insert_before(head, q, box) 
               or node_insert_after(head, node_tail(head), box)
      return q
   else
      set_attr(p, attr_icflag, PROCESSED + get_pr_begin_flag(p))
      setfield(p, 'xoffset', getfield(p, 'xoffset') - fshift.left)
      setfield(p, 'yoffset', getfield(p, 'yoffset') 
		  - (has_attr(p, attr_ykblshift) or 0) - fshift.down)
      return node_next(p)
   end
end
luatexja.setwidth.capsule_glyph = capsule_glyph

local function capsule_glyph_math(p, met, class)
   local char_data = met.char_type[class]
   if not char_data then return nil end
   local fwidth, pwidth = char_data.width, getfield(p, 'width')
   fwidth = (fwidth ~= 'prop') and fwidth or pwidth
   fshift.down = char_data.down; fshift.left = char_data.left
   fshift = call_callback("luatexja.set_width", fshift, met, class)
   local fheight, fdepth = char_data.height, char_data.depth
   local y_shift, ca
      = - getfield(p, 'yoffset') + (has_attr(p,attr_ykblshift) or 0), char_data.align
   setfield(p, 'yoffset', -fshift.down)
   setfield(p, 'xoffset', getfield(p, 'xoffset') + char_data.align*(fwidth-pwidth) - fshift.left)
   local box = node_new(id_hlist); 
   setfield(box, 'width', fwidth)
   setfield(box, 'height', fheight)
   setfield(box, 'depth', fdepth)
   setfield(box, 'head', p)
   setfield(box, 'shift', y_shift)
   setfield(box, 'dir', tex.mathdir)
   set_attr(box, attr_icflag, PACKED + get_pr_begin_flag(p))
   return box
end
luatexja.setwidth.capsule_glyph_math = capsule_glyph_math

function luatexja.setwidth.set_ja_width(ahead, adir)
   local p = ahead; head  = p; dir = adir or 'TLT'
   local m = false -- is in math mode?
   while p do
      local pid = getid(p)
      if (pid==id_glyph) 
      and ((has_attr(p, attr_icflag) or 0)%PROCESSED_BEGIN_FLAG)<=0 then
         local pf = getfont(p)
	 if pf == has_attr(p, attr_curjfnt) then
	    p = capsule_glyph(p, ltjf_font_metric_table[pf], 
			      has_attr(p, attr_jchar_class))
	 else
	    set_attr(p, attr_icflag, PROCESSED + get_pr_begin_flag(p))
	    setfield(p, 'yoffset',
		     getfield(p, 'yoffset') - (has_attr(p,attr_yablshift) or 0))
	    p = node_next(p)
	 end
      elseif pid==id_math then
	 m = (getsubtype(p)==0); p = node_next(p)
      else
	 if m then
            -- 数式の位置補正
	    if pid==id_hlist or pid==id_vlist then
               if (has_attr(p, attr_icflag) or 0) ~= PROCESSED then
                  setfield(p, 'shift', getfield(p, 'shift') +  (has_attr(p,attr_yablshift) or 0))
               end
	    elseif pid==id_rule then
	       if (has_attr(p, attr_icflag) or 0) ~= PROCESSED then
		  local v = has_attr(p,attr_yablshift) or 0
                  setfield(p, 'height', getfield(p, 'height')-v)
                  setfield(p, 'depth', getfield(p, 'depth')+v)
		  set_attr(p, attr_icflag, PROCESSED + get_pr_begin_flag(p))
	       end
	    end
	 end
	 p = node_next(p)
      end
   end
   -- adjust attr_icflag
   tex.setattribute('global', attr_icflag, 0)
   return head
end

