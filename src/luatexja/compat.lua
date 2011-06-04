--
-- luatexja/compat.lua
--
luatexbase.provides_module({
  name = 'luatexja.compat',
  date = '2011/06/03',
  version = '0.1',
  description = 'Partial implementation of primitives of pTeX',
})
module('luatexja.compat', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

-- \kuten, \jis, \euc, \sjis, \ucs, \kansuji
function to_kansuji(num)
   if not num then num=0; return
   elseif num<0 then 
      num = -num; tex.write('-')
   end
   local s = ""
   while num~=0 do
      s = utf.char(
	 luatexja.stack.get_penalty_table('ksj', num%10,
					  '', tex.getcount('ltj@@stack'))) .. s
      num=math.floor(num/10)
   end
   tex.write(s)
end


-- jisx0213.lua: JIS X 0213:2004 から Unicode への対応テーブル．
-- 次のファイルより自動生成した：
--   "JIS X 0213:2004 8-bit code vs Unicode mapping table".
--   (by Project X0213, http://x0213.org/codetable/jisx0213-2004-8bit-std.txt)

-- \kuten: 面区点 （それぞれで16進2桁を使用）=> Unicode 符号位置
function from_kuten(i)
   if not i then i=0 end
   tex.write(luatexja.jisx0213.table_jisx0213_2004[i] or 0)
end

-- \euc: EUC-JIS-2004 による符号位置 => Unicode 符号位置
-- 第2面の文字は 0x8f で始まる 16進6桁で指定
-- JIS X 0201 （0x8e に続く1バイト）はサポートせず．
function from_euc(i)
   -- EUC-JIS-2004: (8f)a1a1 => 1(2) 
   if not i then i=0
   elseif i>=0x8f0000 then 
      i=i-0x8e0000 
   elseif i>=0x10000 or i<0 then 
      i=0
   end
   from_kuten(i-0xa0a0)
end

-- \jis: ISO-2011-JP-2004 による符号位置 => Unicode 符号位置
-- エスケープシーケンスはサポートせず，第1面の文字のみ指定可能．
function from_jis(i)
   -- ISO-2022-JP
   if (not i) or i>=0x10000 or i<0 then 
      i=0
   end
   from_kuten(i-0x2020)
end

-- \sjis: Shift JIS-2004 による符号位置 => Unicode 符号位置
-- JIS X 0201 はサポートせず．
function from_sjis(i)
   -- Shift JIS
   if (not i) or i>=0x10000 or i<0 then 
      tex.write('0'); return 
   end
   local c2 = math.floor(i/256)
   local c1 = i%256
   local shift_jisx0213_s1a3_table = {
      { [false]= 1, [true]= 8}, 
      { [false]= 3, [true]= 4}, 
      { [false]= 5, [true]=12}, 
      { [false]=13, [true]=14}, 
      { [false]=15 } }
   if c2 >= 0x81 then
      if c2 >= 0xF0 then
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
	if c1>0x7f then i=0x40 else i=0x3f end
	c1 = c1 - i
     else
	c1 = c1 - 0x7e
     end
     from_kuten(c2*256+c1)
  end
end
