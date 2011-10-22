require('luatexja.base');      local ltjb = luatexja.base
require('luatexja.jfont');     local ltjf = luatexja.jfont

local round = tex.round

local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
local attr_jchar_class = luatexbase.attributes['ltj@charclass']
local attr_yablshift = luatexbase.attributes['ltj@yablshift']
local attr_ykblshift = luatexbase.attributes['ltj@ykblshift']

local ltjf_font_metric_table = ltjf.font_metric_table
local ltjf_find_char_class = ltjf.find_char_class

local function set_valign(fmtable, fn)
   local fi = fonts.ids[fn]
   local mt = ltjf.metrics[fmtable.jfm].char_type[0]
   local ma = mt.height / (mt.height + mt.depth) * (fi.ascender + fi.descender)
   fmtable.down_offset = round(fi.ascender - ma)
   print('loading :', fn, print_scaled(fmtable.down_offset)
      .. ' / ' .. print_scaled(fi.size))
   return fmtable
end
luatexbase.add_to_callback("luatexja.define_jfont", 
			   set_valign, "ltj.valign.define_jfont", 1)
--  �����ɤ߹��ޤ�Ƥ���ե���Ȥ��Ф��Ƥ⡤Ʊ�����Ȥ���ʤ��Ȥ����ʤ�
for fn, v in pairs(ltjf_font_metric_table) do
   ltjf_font_metric_table[fn] = set_valign(v, fn)
end

local function get_valign (fstable, fmtable, jchar_class) 
   local d = fmtable.down_offset or 0
   fstable.down = fstable.down + d
   return fstable
end

luatexbase.add_to_callback("luatexja.set_width", 
			   get_valign, "ltj.valign.define_jfont", 1)
