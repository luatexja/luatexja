--
-- ltj-inputbuf.lua
--

luatexja.load_module 'base';      local ltjb = luatexja.base
luatexja.load_module 'charrange'; local ltjc = luatexja.charrange

local utflen = utf.len
local utfbyte = utf.byte
local utfchar = utf.char
local node_new = node.new
local node_free = node.free
local id_glyph = node.id 'glyph'
local getcatcode, getcount = tex.getcatcode, tex.getcount
local ltjc_is_japanese_char_curlist = ltjc.is_japanese_char_curlist

--- the following function is modified from jafontspec.lua (by K. Maeda).
--- Instead of "%", we use U+FFFFF for suppressing spaces.
--DEBUG require"socket"
local time_line = 0
local start_time_measure, stop_time_measure
   = ltjb.start_time_measure, ltjb.stop_time_measure
local function add_comment(buffer)
   start_time_measure 'inputbuf'
   local i = utflen(buffer)
   local c = utfbyte(buffer, i)
   while (i>0) and (getcatcode(c)==1 or getcatcode(c)==2) do
      i=i-1; if (i>0) then c = utfbyte(buffer, i) end;
   end
   if i>0 then
      if c>=0x80 then
         local te = tex.endlinechar
         -- Is the catcode of endline character is 5 (end-of-line)?
         if (te ~= -1) and (getcatcode(te)==5) then
            local ct = getcatcode(c)
            if (ct==11) or (ct==12) then
               local lec = getcount 'ltjlineendcomment'
               -- Is the catcode of \ltjlineendcomment (new comment char) is 14 (comment)?
               if ltjc_is_japanese_char_curlist(c) and (getcatcode(lec)==14) then
                  stop_time_measure 'inputbuf'; return buffer .. utfchar(lec)
               end
            end
         end
      end
   end
   stop_time_measure 'inputbuf'
   return buffer
end

luatexbase.add_to_callback('process_input_buffer',
   add_comment,'ltj.process_input_buffer')

--EOF
