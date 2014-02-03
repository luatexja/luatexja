--
-- luatexja/ltj-math.lua
--

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('charrange'); local ltjc = luatexja.charrange
luatexja.load_module('jfont');     local ltjf = luatexja.jfont
luatexja.load_module('stack');     local ltjs = luatexja.stack
luatexja.load_module('setwidth');  local ltjw = luatexja.setwidth

local Dnode = node.direct or node

local setfield = (Dnode ~= node) and Dnode.setfield or function(n, i, c) n[i] = c end
local getfield = (Dnode ~= node) and Dnode.getfield or function(n, i) return n[i] end
local getid = (Dnode ~= node) and Dnode.getid or function(n) return n.id end
-- getlist cannot be used for sub_box nodes. Use instead λp. getfield(p, 'head')
local getchar = (Dnode ~= node) and Dnode.getchar or function(n) return n.char end

local nullfunc = function(n) return n end
local to_node = (Dnode ~= node) and Dnode.tonode or nullfunc
local to_direct = (Dnode ~= node) and Dnode.todirect or nullfunc

local node_traverse = Dnode.traverse
local node_new = Dnode.new
local node_next = (Dnode ~= node) and Dnode.getnext or node.next
local node_free = Dnode.free
local has_attr = Dnode.has_attribute
local set_attr = Dnode.set_attribute
local tex_getcount = tex.getcount

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

local PROCESSED  = luatexja.icflag_table.PROCESSED

local ltjf_font_metric_table = ltjf.font_metric_table
local ltjf_find_char_class = ltjf.find_char_class

-- table of mathematical characters
local is_math_letters = {}

local conv_jchar_to_hbox_A

-- sty : 0 (display or text), 1 (script), >=2 (scriptscript)
local function conv_jchar_to_hbox(head, sty)
   for p in node_traverse(head) do
      local pid = getid(p)
      if pid == id_simple or pid == id_accent then
	 setfield(p, 'nucleus', conv_jchar_to_hbox_A(getfield(p, 'nucleus'), sty))
	 setfield(p, 'sub', conv_jchar_to_hbox_A(getfield(p, 'sub'), sty+1))
	 setfield(p, 'sup', conv_jchar_to_hbox_A(getfield(p, 'sup'), sty+1))
      elseif pid == id_choice then
	 setfield(p, 'display', conv_jchar_to_hbox_A(getfield(p, 'display'), 0))
	 setfield(p, 'text', conv_jchar_to_hbox_A(getfield(p, 'text'), 0))
	 setfield(p, 'script', conv_jchar_to_hbox_A(getfield(p, 'script'), 1))
	 setfield(p, 'scriptscript', conv_jchar_to_hbox_A(getfield(p, 'scriptscript'), 2))
      elseif pid == id_frac then
	 setfield(p, 'num', conv_jchar_to_hbox_A(getfield(p, 'num'), sty+1))
	 setfield(p, 'denom', conv_jchar_to_hbox_A(getfield(p, 'denom'), sty+1))
      elseif pid == id_radical then
	 setfield(p, 'nucleus', conv_jchar_to_hbox_A(getfield(p, 'nucleus'), sty))
	 setfield(p, 'sub', conv_jchar_to_hbox_A(getfield(p, 'sub'), sty+1))
	 setfield(p, 'sup', conv_jchar_to_hbox_A(getfield(p, 'sup'), sty+1))
	 if getfield(p, 'degree') then
	    setfield(p, 'degree', conv_jchar_to_hbox_A(getfield(p, 'degree'), sty + 1))
	 end
      elseif pid == id_style then
	 local ps = getfield(p, 'style')
	 if ps == "display'" or  ps == 'display'
	    or  ps == "text'" or  ps == 'text' then
	    sty = 0
	 elseif  ps == "script'" or  ps == 'script' then
	    sty = 1
	 else sty = 2
	 end
       end
   end 
   return head
end 

local MJT  = luatexja.stack_table_index.MJT
local MJS  = luatexja.stack_table_index.MJS
local MJSS = luatexja.stack_table_index.MJSS
local capsule_glyph_math = ltjw.capsule_glyph_math
local is_ucs_in_japanese_char = ltjc.is_ucs_in_japanese_char_direct

conv_jchar_to_hbox_A = 
function (p, sty)
   if not p then return nil
   else
      local pid = getid(p)
      if pid == id_sub_mlist then
         if getfield(p, 'head') then
            setfield(p, 'head', conv_jchar_to_hbox(getfield(p, 'head'), sty))
         end
      elseif pid == id_mchar then
         local fam = has_attr(p, attr_jfam) or -1
	 local pc = getchar(p)
         if (not is_math_letters[pc]) and is_ucs_in_japanese_char(p) and fam>=0 then
            local f = ltjs.get_stack_table(MJT + 0x100 * sty + fam, -1, tex_getcount('ltj@@stack'))
            if f ~= -1 then
               local q = node_new(id_sub_box)
               local r = node_new(id_glyph); setfield(r, 'next', nil)
               setfield(r, 'char', pc); setfield(r, 'font', f); setfield(r, 'subtype', 256)
               local k = has_attr(r,attr_ykblshift) or 0 
               set_attr(r, attr_ykblshift, 0)
               -- ltj-setwidth 内で実際の位置補正はおこなうので，補正量を退避
               local met = ltjf_font_metric_table[f]
               r = capsule_glyph_math(r, met, ltjf_find_char_class(pc, met));
               setfield(q, 'head', r); node_free(p); p=q;
               set_attr(r, attr_yablshift, k)
            end
         end
      elseif pid == id_sub_box and getfield(p, 'head') then
         -- \hbox で直に与えられた内容は上下位置を補正する必要はない
         set_attr(getfield(p, 'head'), attr_icflag, PROCESSED)
      end
   end
   return p
end

luatexbase.add_to_callback('mlist_to_hlist', 
   function (n, display_type, penalties)
      local head = to_node(conv_jchar_to_hbox(to_direct(n), 0))
      head = node.mlist_to_hlist(head, display_type, penalties)
      return head
   end,'ltj.mlist_to_hlist', 1)

luatexja.math = { is_math_letters = is_math_letters }
