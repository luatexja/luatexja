--
-- luatexja/math.lua
--
luatexbase.provides_module({
  name = 'luatexja.math',
  date = '2011/08/14',
  version = '0.1',
  description = 'Handling routines for Japanese characters in math mode',
})
module('luatexja.math', package.seeall)

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('charrange'); local ltjc = luatexja.charrange
luatexja.load_module('jfont');     local ltjf = luatexja.jfont
luatexja.load_module('stack');     local ltjs = luatexja.stack
luatexja.load_module('setwidth');  local ltjw = luatexja.setwidth

local node_new = node.new
local node_next = node.next
local node_free = node.free
local has_attr = node.has_attribute
local set_attr = node.set_attribute

local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_jfam = luatexbase.attributes['jfam']
local attr_yablshift = luatexbase.attributes['ltj@yablshift']

local id_glyph = node.id('glyph')
local id_hlist = node.id('hlist')
local id_vlist = node.id('vlist')
local id_mchar = node.id('math_char')
local id_sub_box = node.id('sub_box')
local id_radical = node.id('radical')
local id_choice  = node.id('choice')
local id_accent  = node.id('accent')
local id_style   = node.id('style')
local id_frac    = node.id('fraction')
local id_simple  = node.id('noad')
local id_sub_mlist = node.id('sub_mlist')

local PROCESSED = 8

local ltjf_font_metric_table = ltjf.font_metric_table
local ltjf_find_char_class = ltjf.find_char_class

-- table of mathematical characters
is_math_letters = {}

local conv_jchar_to_hbox_A

-- sty : 0 (display or text), 1 (script), >=2 (scriptscript)
local function conv_jchar_to_hbox(head, sty)
   local p = head
   local bhead = head
   while p do
      if p.id == id_simple or p.id == id_accent then
	 p.nucleus = conv_jchar_to_hbox_A(p.nucleus, sty)
	 p.sub = conv_jchar_to_hbox_A(p.sub, sty + 1)
	 p.sup = conv_jchar_to_hbox_A(p.sup, sty + 1)
      elseif p.id == id_choice then
	 p.display = conv_jchar_to_hbox(p.display, 0)
	 p.text = conv_jchar_to_hbox(p.text, 0)
	 p.script = conv_jchar_to_hbox(p.script, 1)
	 p.scriptscript = conv_jchar_to_hbox(p.scriptscript, 2)
      elseif p.id == id_frac then
	 p.num = conv_jchar_to_hbox_A(p.num, sty + 1)
	 p.denom = conv_jchar_to_hbox_A(p.denom, sty + 1)
      elseif p.id == id_radical then
	 p.nucleus = conv_jchar_to_hbox_A(p.nucleus, sty)
	 p.sub = conv_jchar_to_hbox_A(p.sub, sty + 1)
	 p.sup = conv_jchar_to_hbox_A(p.sup, sty + 1)
	 if p.degree then
	    p.degree = conv_jchar_to_hbox_A(p.degree, sty + 1)
	 end
      elseif p.id == id_style then
	 if p.style == "display'" or  p.style == 'display'
	    or  p.style == "text'" or  p.style == 'text' then
	    sty = 0
	 elseif  p.style == "script'" or  p.style == 'script' then
	    sty = 1
	 else sty = 2
	 end
       end
       p = node.next(p)
   end 
   return head
end 

conv_jchar_to_hbox_A = 
function (p, sty)
   if not p then return nil
   elseif p.id == id_sub_mlist then
      if p.head then
	 p.head = conv_jchar_to_hbox(p.head, sty)
      end
   elseif p.id == id_mchar then
      local fam = has_attr(p, attr_jfam) or -1
      if (not is_math_letters[p.char]) and ltjc.is_ucs_in_japanese_char(p) and fam>=0 then
	 local mode = 'mjss'
	 if sty == 0 then mode = 'mjtext'
	 elseif sty == 1 then mode = 'mjscr'
	 end
	 local f = ltjs.get_penalty_table(mode, fam, -1, tex.getcount('ltj@@stack'))
	 if f ~= -1 then
	    local q = node_new(id_sub_box)
	    local r = node_new(id_glyph); r.next = nil
	    r.char = p.char; r.font = f; r.subtype = 256
	    set_attr(r, attr_icflag, PROCESSED)
	    set_attr(r, attr_yablshift, 0)
	    local met = ltjf_font_metric_table[f]
	    local class = ltjf_find_char_class(p.char, met)
	    set_attr(r, attr_jchar_class, class)
	    ltjw.char_data = ltjf.metrics[met.jfm].size_cache[met.size].char_type[class]
	    ltjw.head = r; ltjw.capsule_glyph(r, tex.mathdir , true, met, class);
	    q.head = ltjw.head; node_free(p); p=q;
	 end
      end
   end
   return p
end

luatexbase.add_to_callback('mlist_to_hlist', 
   function (n, display_type, penalties)
      local head = conv_jchar_to_hbox(n, 0);
      head = node.mlist_to_hlist(head, display_type, penalties)
      return head
   end,'ltj.mlist_to_hlist', 1)
