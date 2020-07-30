--
-- ltj-math.lua
--

luatexja.load_module 'base';      local ltjb = luatexja.base
luatexja.load_module 'direction'; local ltjd = luatexja.direction
luatexja.load_module 'charrange'; local ltjc = luatexja.charrange
luatexja.load_module 'jfont';     local ltjf = luatexja.jfont
luatexja.load_module 'stack';     local ltjs = luatexja.stack
luatexja.load_module 'setwidth';  local ltjw = luatexja.setwidth

local setfield = node.direct.setfield
local getfield = node.direct.getfield
local getid = node.direct.getid
local getsubtype = node.direct.getsubtype
local getlist = node.direct.getlist
-- getlist cannot be used for sub_box nodes. Use instead λp. getfield(p, 'head')
local getchar = node.direct.getchar

local to_node = node.direct.tonode
local to_direct = node.direct.todirect

local node_traverse = node.direct.traverse
local node_new = node.direct.new
local node_next = node.direct.getnext
local node_remove = node.direct.remove
local node_free = node.direct.free
local has_attr = node.direct.has_attribute
local set_attr = node.direct.set_attribute
local tex_getcount = tex.getcount

local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_dir = luatexbase.attributes['ltj@dir']
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_jfam = luatexbase.attributes['jfam']
local attr_yablshift = luatexbase.attributes['ltj@yablshift']

local id_glyph   = node.id 'glyph'
local id_hlist   = node.id 'hlist'
local id_vlist   = node.id 'vlist'
local id_mchar   = node.id 'math_char'
local id_sub_box = node.id 'sub_box'
local id_radical = node.id 'radical'
local id_choice  = node.id 'choice'
local id_accent  = node.id 'accent'
local id_style   = node.id 'style'
local id_frac    = node.id 'fraction'
local id_simple  = node.id 'noad'
local id_sub_mlist = node.id 'sub_mlist'
local id_whatsit = node.id 'whatsit'
local sid_user = node.subtype 'user_defined'
local DIR  = luatexja.userid_table.DIR
local dir_node_auto   = luatexja.dir_table.dir_node_auto

local PROCESSED  = luatexja.icflag_table.PROCESSED

local ltjf_font_metric_table = ltjf.font_metric_table
local ltjf_find_char_class = ltjf.find_char_class
local ltjd_get_dir_count = ltjd.get_dir_count
local ltjd_make_dir_whatsit = ltjd.make_dir_whatsit

-- table of mathematical characters
local is_math_letters = {}
local list_dir

-- vcenter noad は軸に揃えるため，欧文ベースライン補正がかかる
local function conv_vcenter(sb)
   local h = getfield(sb, 'head'); local hd = getlist(h)
   if getid(hd)==id_whatsit and getsubtype(hd)==sid_user 
      and getfield(hd, 'user_id')==DIR then
      local d = node_next(hd)
      if getid(d)==id_vlist and has_attr(d, attr_dir)>=dir_node_auto then
         node_free(hd); setfield(h, 'head', nil); node_free(h)
         setfield(sb, 'head', d);  set_attr(d, attr_icflag, 0)
      end
   end
   return sb
end

local cjhh_A
-- sty : 0 (display or text), 1 (script), >=2 (scriptscript)
local function conv_jchar_to_hbox(head, sty)
   for p in node_traverse(head) do
      local pid = getid(p)
      if pid == id_simple or pid == id_accent then
         if getsubtype(p)==12 then
            conv_vcenter(getfield(p, 'nucleus'))
         else
            setfield(p, 'nucleus', cjh_A(getfield(p, 'nucleus'), sty))
         end
         setfield(p, 'sub', cjh_A(getfield(p, 'sub'), sty+1))
         setfield(p, 'sup', cjh_A(getfield(p, 'sup'), sty+1))
      elseif pid == id_choice then
         setfield(p, 'display', cjh_A(getfield(p, 'display'), 0))
         setfield(p, 'text', cjh_A(getfield(p, 'text'), 0))
         setfield(p, 'script', cjh_A(getfield(p, 'script'), 1))
         setfield(p, 'scriptscript', cjh_A(getfield(p, 'scriptscript'), 2))
      elseif pid == id_frac then
         setfield(p, 'num', cjh_A(getfield(p, 'num'), sty+1))
         setfield(p, 'denom', cjh_A(getfield(p, 'denom'), sty+1))
      elseif pid == id_radical then
         setfield(p, 'nucleus', cjh_A(getfield(p, 'nucleus'), sty))
         setfield(p, 'sub', cjh_A(getfield(p, 'sub'), sty+1))
         setfield(p, 'sup', cjh_A(getfield(p, 'sup'), sty+1))
         if getfield(p, 'degree') then
            setfield(p, 'degree', cjh_A(getfield(p, 'degree'), sty + 1))
         end
      elseif pid == id_style then
         local ps = getfield(p, 'style')
         if ps == "display'" or  ps == 'display' or ps == "text'" or ps == 'text' then
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

cjh_A = function (p, sty)
   if not p then return nil
   else
      local pid = getid(p)
      if pid == id_sub_mlist then
         if getfield(p, 'head') then
            setfield(p, 'head', conv_jchar_to_hbox(getfield(p, 'head'), sty))
         end
      elseif pid == id_mchar then
         local pc, fam = getchar (p), has_attr(p, attr_jfam) or -1
         if (not is_math_letters[pc]) and is_ucs_in_japanese_char(p) and fam>=0 then
            local f = ltjs.get_stack_table(MJT + 0x100 * sty + fam, -1, tex_getcount('ltj@@stack'))
            if f ~= -1 then
               local q = node_new(id_sub_box)
               local r = node_new(id_glyph); setfield(r, 'next', nil)
               setfield(r, 'char', pc); setfield(r, 'font', f); setfield(r, 'subtype', 256)
               local k = has_attr(r,attr_ykblshift) or 0; set_attr(r, attr_ykblshift, 0)
               -- ltj-setwidth 内で実際の位置補正はおこなうので，補正量を退避
               local met = ltjf_font_metric_table[f]
               r = capsule_glyph_math(r, met, met.char_type[ltjf_find_char_class(pc, met)]);
               setfield(q, 'head', r); node_free(p); p=q; set_attr(r, attr_yablshift, k)
            end
         end
      elseif pid == id_sub_box and getfield(p, 'head') then
         -- \hbox で直に与えられた内容は上下位置を補正する必要はない
         local h = getfield(p, 'head'); h = ltjd_make_dir_whatsit(h, h, list_dir, 'math')
         setfield(p, 'head', h); set_attr(h, attr_icflag, PROCESSED)
      end
   end
   return p
end

do
  local function mlist_callback_ltja(n)
    local n = to_direct(n); list_dir = ltjd_get_dir_count()
    if getid(n)==id_whatsit and getsubtype(n)==sid_user and getfield(n, 'user_id') == DIR then
      local old_n = n; n = node_remove(n, n)
      node_free(old_n); if not n then return nil end
    end
    return to_node(conv_jchar_to_hbox(n, 0))
  end
  -- LaTeX 2020-02-02 seems to have pre_mlist_to_hlist_filter callback
  if luatexbase.callbacktypes['pre_mlist_to_hlist_filter'] then
    luatexbase.add_to_callback('pre_mlist_to_hlist_filter',
      mlist_callback_ltja, 'ltj.mlist_to_hlist_pre', 1)
  else
    local mlist_to_hlist = node.mlist_to_hlist
    luatexbase.add_to_callback('mlist_to_hlist',
      function (n, display_type, penalties)
        return mlist_to_hlist(mlist_callback_ltja(n),display_type, penalties)
      end,'ltj.mlist_to_hlist', 1)
  end
end

luatexja.math = { is_math_letters = is_math_letters }
