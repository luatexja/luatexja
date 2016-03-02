--
-- luatexja/ltj-inputbuf.lua
--

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('charrange'); local ltjc = luatexja.charrange

require("unicode")
local utflen = unicode.utf8.len
local utfbyte = unicode.utf8.byte
local utfchar = unicode.utf8.char
local node_new = node.new
local node_free = node.free
local id_glyph = node.id('glyph')
local getcatcode, getcount = tex.getcatcode, tex.getcount
local ltjc_is_japanese_char_curlist = ltjc.is_japanese_char_curlist

--- the following function is modified from jafontspec.lua (by K. Maeda).
--- Instead of "%", we use U+FFFFF for suppressing spaces.
--DEBUG require"socket"
local time_line = 0
local start_time_measure, stop_time_measure
   = ltjb.start_time_measure, ltjb.stop_time_measure
local function add_comment(buffer)
   start_time_measure('inputbuf')
   local i = utflen(buffer)
   while (i>0) and (getcatcode(utfbyte(buffer, i))==1
		 or getcatcode(utfbyte(buffer, i))==2) do
      i=i-1
   end
   if i>0 then
      local c = utfbyte(buffer, i)
      if c>=0x80 then
	 local ct = getcatcode(c)
	 local te = tex.endlinechar
	 local ctl = (te ~= -1) and (getcatcode(te)==5) and (getcatcode(getcount('ltjlineendcomment'))==14)
	 -- Is the catcode of endline character is 5 (end-of-line)?
	 -- Is the catcode of \ltjlineendcomment (new comment char) is 14 (comment)?
	 if ((ct==11) or (ct==12)) and ctl then
	    if ltjc_is_japanese_char_curlist(c) then
	       buffer = buffer .. utfchar(getcount('ltjlineendcomment'))
	    end
	 end
      end
   end
   stop_time_measure('inputbuf')
   return buffer
end

luatexbase.add_to_callback('process_input_buffer',
   add_comment,'ltj.process_input_buffer')

--EOF
