require('unicode')

local id_glyph = node.id('glyph')
local has_attr = node.has_attribute
local identifiers = fonts.hashes.identifiers
local node_next = node.next
local node_remove = node.remove

local get_node_font, get_current_font
if luatexja then -- test if LuaTeX-ja is loaded
   luatexja.load_module('charrange'); local ltjc = luatexja.charrange
   local attr_curjfnt = luatexbase.attributes['ltj@curjfnt']
   local ltjc_is_ucs_in_japanese_char = ltjc.is_ucs_in_japanese_char
   get_node_font = function(p)
      return (ltjc_is_ucs_in_japanese_char(p) and (has_attr(p, attr_curjfnt) or 0) or p.font)
   end
   get_current_font = function() return tex.attribute[attr_curjfnt] or 0 end
else
   get_node_font = function(p) return p.font end
   get_current_font = font.current
end

local function do_ivs_repr(head)
  local p = head
  while p do
     local pid = p.id
     if pid==id_glyph then
        local pf = get_node_font(p)
        local pt = identifiers[pf]
        pt = pt and pt.resources; pt = pt and pt.variants
        if pt then
           local q = node_next(p) -- the next node of p
           if q and q.id==id_glyph then
              local qc = q.char
              if qc>=0xE0100 and qc<0xE01F0 then -- q is an IVS selector
                 pt = pt[qc];  pt = pt and  pt[p.char]
                 if pt then
                    p.char = pt or p.char
                 end
                 head = node_remove(head,q)
              end
           end
        end
     end
     p = node_next(p)
  end
  return head
end
-- callback
luatexbase.add_to_callback('hpack_filter', 
   function (head) return do_ivs_repr(head) end,'do_ivs', 1)
luatexbase.add_to_callback('pre_linebreak_filter', 
   function (head) return do_ivs_repr(head) end, 'do_ivs', 1)

ivs = {}

do
   local ubyte = unicode.utf8.byte
   local uchar = unicode.utf8.char
   local sort = table.sort
   function ivs.list_ivs(s)
      local c = ubyte(s)
      local pt = identifiers[get_current_font()]
      pt = pt and pt.resources; pt = pt and pt.variants
      if pt then
         local t = {}
         for i,v in pairs(pt) do
            if v[c] then t[1+#t]=i end
         end
         sort(t)
         for _,v in ipairs(t) do 
            tex.sprint('\\oalign{' .. s .. uchar(v) 
                          .. '\\crcr\\hss\\tiny' .. tostring(v-0xE0100) .. '\\hss\\crcr}') 
         end
      end
   end
end
