--
-- luatexja/inputbuf.lua
--
luatexbase.provides_module({
  name = 'luatexja.inputbuf',
  date = '2011/04/01',
  version = '0.1',
  description = 'Supressing a space by newline after Japanese characters',
})
module('luatexja.inputbuf', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

luatexja.load_module('charrange'); local ltjc = luatexja.charrange

local node_new = node.new
local id_glyph = node.id('glyph')
local getcatcode = tex.getcatcode

--- the following function is modified from jafontspec.lua (by K. Maeda).
--- Instead of "%", we use U+FFFFF for suppressing spaces.
function add_comment(buffer)
   local i = utf.len(buffer)
   while (i>0) and (getcatcode(utf.byte(buffer, i))==1 
		 or getcatcode(utf.byte(buffer, i))==2) do
      i=i-1
   end
   if i>0 then
      local c = utf.byte(buffer, i)
      local ct = getcatcode(c)
      local te = tex.endlinechar
      local ctl = (te ~= -1) and (getcatcode(te)==5) and (getcatcode(0xFFFFF)==14)
      -- Is the catcode of endline character is 5 (end-of-line)?
      -- Is the catcode of U+FFFFF (new comment char) is 14 (comment)?
      if ((ct==11) or (ct==12)) and ctl then
	 local p = node_new(id_glyph)
	 p.char = c
	 if ltjc.is_ucs_in_japanese_char(p) then
	    buffer = buffer .. string.char(0xF3,0xBF,0xBF,0xBF) -- U+FFFFF
	 end
	 node.free(p)
      end
   end
   return buffer
end

luatexbase.add_to_callback('process_input_buffer', 
   add_comment,'ltj.process_input_buffer')

--EOF