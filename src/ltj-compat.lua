--
-- ltj-compat.lua
--

luatexja.load_module 'base';   local ltjb = luatexja.base
luatexja.load_module 'stack';  local ltjs = luatexja.stack

-- load jisx0208 table
local cache_ver = 3

local cache_outdate_fn = function (t) return t.version~=cache_ver end
local jisx0208 = ltjb.load_cache('ltj-jisx0208',cache_outdate_fn)
if not jisx0208 then -- make cache
   jisx0208 = require 'ltj-jisx0208.lua'
   ltjb.save_cache_luc('ltj-jisx0208', jisx0208)
end


-- \kuten, \jis, \euc, \sjis, \ucs, \kansuji
local utfchar, floor = utf.char, math.floor
local texwrite, getcount = tex.write, tex.getcount
local cnt_stack = luatexbase.registernumber 'ltj@@stack'
local KSJ = luatexja.stack_table_index.KSJ
local get_stack_table = ltjs.get_stack_table
local function to_kansuji(num)
   if not num then num=0; return
   elseif num<0 then num = -num; texwrite '-' 
   end
   local s = ""
   repeat
      s = utfchar(get_stack_table(KSJ + num%10, '', getcount(cnt_stack))) .. s
      num=num//10
   until num==0
   texwrite(s)
end

local function error_invalid_charcode(i)
   ltjb.package_error('luatexja',
      "invalid character code (".. tostring(i) .. ")",
      "I'm going to use 0 instead of that illegal character code.")
end

-- \ucs: 単なる identity
local function from_ucs(i)
   if type(i)~='number' then error_invalid_charcode(i); i=0 end
   texwrite(i)
end

-- \kuten: 面区点 （それぞれで16進2桁を使用）=> Unicode 符号位置
local function from_kuten(i)
   if type(i)~='number' then error_invalid_charcode(i); i=0 end
   if (i%256==0)or(i%256>94) then
     texwrite '0'
   else
     texwrite(tostring(jisx0208.table_jisx0208_uptex[(i//256)*94+(i%256)-94] or 0))
   end
end

-- \euc: EUC-JP による符号位置 => Unicode 符号位置
local function from_euc(i)
   if type(i)~='number' then
     error_invalid_charcode(i); i=0
   elseif i>=0x10000 or i<0xa0a0 then
      i=0
   end
   from_kuten(i-0xa0a0)
end

-- \jis: ISO-2022-JP による符号位置 => Unicode 符号位置
local function from_jis(i)
   if type(i)~='number' then error_invalid_charcode(i); i=0 end
   from_kuten(i-0x2020)
end

-- \sjis: Shift_JIS による符号位置 => Unicode 符号位置
local function from_sjis(i)
   if (type(i)~='number') or i>=0x10000 or i<0 then
      error_invalid_charcode(i); texwrite '0'; return
   end
   local c2, c1 = i//256, i%256
   local shift_jisx0213_s1a3_table = {
      { [false]= 1, [true]= 8},
      { [false]= 3, [true]= 4},
      { [false]= 5, [true]=12},
      { [false]=13, [true]=14},
      { [false]=15 } }
   if c2 >= 0x81 then
      if c2 >= 0xF0 then -- this if block won't be true
         if (c2 <= 0xF3 or (c2 == 0xF4 and c1 < 0x9F)) then
            c2 = 0x100 + shift_jisx0213_s1a3_table[c2 - 0xF0 + 1][(0x9E < c1)];
         else -- 78<=k<=94
            c2 = c2 * 2 - 413 + 0x100; if 0x9E < c1 then c2=c2+1 end
         end
     else
        if c2<=0x9f then i=0x101 else i=0x181 end
        c2 = c2 + c2 - i; if 0x9E < c1 then c2=c2+1 end
     end
     if c1 < 0x9F then
        if c1>0x7f then i=0x40 else i=0x3f end; c1 = c1 - i
     else
        c1 = c1 - 0x9e
     end
     from_kuten(c2*256+c1)
  end
end

luatexja.binary_pars.kansujichar = function(c, t)
   if type(c)~='number' or c<0 or c>9 then
      ltjb.package_error('luatexja',
                         'Invalid KANSUJI number (' .. tostring(c) .. ')',
                         'A KANSUJI number should be in the range 0..9.\n'..
                        'So I changed this one to zero.')
      c=0
   end
   return get_stack_table(KSJ + c, 0, t)
end


local t = {
   from_euc   = from_euc,   from_kuten = from_kuten,
   from_jis   = from_jis,   from_sjis  = from_sjis,
   from_ucs   = from_ucs,   to_kansuji = to_kansuji,
}
luatexja.compat = t
