--
-- ltj-inputbuf.lua
--

luatexja.load_module 'base';      local ltjb = luatexja.base
luatexja.load_module 'charrange'; local ltjc = luatexja.charrange

local utflen = utf.len
local utfbyte = utf.byte
local utfchar = utf.char
local id_glyph = node.id 'glyph'
local getcatcode, getcount = tex.getcatcode, tex.getcount
local ltjc_is_japanese_char_curlist = ltjc.is_japanese_char_curlist
local cnt_lineend = luatexbase.registernumber 'ltjlineendcomment'
local substituter
do
    local uchar = utf.char
    local cd, cp = uchar(0x3099), uchar(0x309A)
    substituter = (utf.substituter or utf.subtituter)      -- typo in lualibs?
    {
      ['ウ'..cd] = 'ヴ', ['う'..cd] = uchar(0x30F4),
      ['か'..cd] = 'が', ['カ'..cd] = 'ガ',
      ['き'..cd] = 'ぎ', ['キ'..cd] = 'ギ',
      ['く'..cd] = 'ぐ', ['ク'..cd] = 'グ',
      ['け'..cd] = 'げ', ['ケ'..cd] = 'ゲ',
      ['こ'..cd] = 'ご', ['コ'..cd] = 'ゴ',
      --
      ['さ'..cd] = 'ざ', ['サ'..cd] = 'ザ',
      ['し'..cd] = 'じ', ['シ'..cd] = 'ジ',
      ['す'..cd] = 'ず', ['ス'..cd] = 'ズ',
      ['せ'..cd] = 'ぜ', ['セ'..cd] = 'ゼ',
      ['そ'..cd] = 'ぞ', ['ソ'..cd] = 'ゾ',
      --
      ['た'..cd] = 'だ', ['タ'..cd] = 'ダ',
      ['ち'..cd] = 'ぢ', ['チ'..cd] = 'ヂ',
      ['つ'..cd] = 'づ', ['ツ'..cd] = 'ヅ',
      ['て'..cd] = 'で', ['テ'..cd] = 'デ',
      ['と'..cd] = 'ど', ['ト'..cd] = 'ド',
      --
      ['は'..cd] = 'ば', ['ハ'..cd] = 'バ', ['は'..cp] = 'ぱ', ['ハ'..cp] = 'パ',
      ['ひ'..cd] = 'び', ['ヒ'..cd] = 'ビ', ['ひ'..cp] = 'ぴ', ['ヒ'..cp] = 'ピ',
      ['ふ'..cd] = 'ぶ', ['フ'..cd] = 'ブ', ['ふ'..cp] = 'ぷ', ['フ'..cp] = 'プ',
      ['へ'..cd] = 'べ', ['ヘ'..cd] = 'ベ', ['へ'..cp] = 'ぺ', ['ヘ'..cp] = 'ペ',
      ['ほ'..cd] = 'ぼ', ['ホ'..cd] = 'ボ', ['ほ'..cp] = 'ぽ', ['ホ'..cp] = 'ポ',
      --
      ['ゝ'..cd] = 'ゞ', ['ヽ'..cd] = 'ヾ',
      ['ワ'..cd] = uchar(0x30F7), ['ヰ'..cd] = uchar(0x30F8),
      ['ヱ'..cd] = uchar(0x30F9), ['ヲ'..cd] = uchar(0x30FA),
    }
end

--- the following function is modified from jafontspec.lua (by K. Maeda).
--- Instead of "%", we use U+FFFFF for suppressing spaces.
--DEBUG require"socket"
local time_line = 0
local start_time_measure, stop_time_measure
   = ltjb.start_time_measure, ltjb.stop_time_measure
local function add_comment(buffer)
   start_time_measure 'inputbuf'; buffer = substituter(buffer)
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
               local lec = getcount(cnt_lineend)
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
