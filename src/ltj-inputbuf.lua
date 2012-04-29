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

--- the following function is modified from jafontspec.lua (by K. Maeda).
--- Instead of "%", we use U+FFFFF for suppressing spaces.
function add_comment(buffer)
   local i = utf.len(buffer)
   while (i>0) and (tex.getcatcode(utf.byte(buffer, i))==1 
		 or tex.getcatcode(utf.byte(buffer, i))==2) do
      i=i-1
   end
   if i>0 then
      local c = utf.byte(buffer, i)
      local ct = tex.getcatcode(c)
      local ctl = tex.getcatcode(13) -- endline character
      local ctc = tex.getcatcode(0xFFFFF) -- new comment character
      if ((ct==11) or (ct==12)) and (ctl==5) and (ctc==14) then
	 local p =  node_new(id_glyph)
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