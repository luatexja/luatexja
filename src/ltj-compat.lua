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

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('stack');     local ltjs = luatexja.stack

-- \kuten, \jis, \euc, \sjis, \ucs, \kansuji
function to_kansuji(num)
   if not num then num=0; return
   elseif num<0 then 
      num = -num; tex.write('-')
   end
   local s = ""
   while num~=0 do
      s = utf.char(
	 ltjs.get_penalty_table('ksj', num%10,
				'', tex.getcount('ltj@@stack'))) .. s
      num=math.floor(num/10)
   end
   tex.write(s)
end

-- \ucs: 単なる identity
function from_ucs(i)
   if type(i)~='number' then 
      ltjb.package_error('luatexja',
			 "invalid character code (".. tostring(i) .. ")",
			 "I'm going to use 0 instead of that illegal character code.")
      i=0 
   end
   tex.write(i)
end

-- \kuten: 面区点 （それぞれで16進2桁を使用）=> Unicharacter code 符号位置
function from_kuten(i)
   if type(i)~='number' then 
      ltjb.package_error('luatexja',
			 "invalid character code (".. tostring(i) .. ")",
			 "I'm going to use 0 instead of that illegal character code.")
      i=0 
   end
   tex.write(tostring(luatexja.jisx0208.table_jisx0208_uptex[i] or 0))
end

-- \euc: EUC-JP による符号位置 => Unicharacter code 符号位置
function from_euc(i)
   if type(i)~='number' then 
      ltjb.package_error('luatexja',
			 "invalid character code (".. tostring(i) .. ")",
			 "I'm going to use 0 instead of that illegal character code.")
      i=0
   elseif i>=0x10000 or i<0xa0a0 then 
      i=0
   end
   from_kuten(i-0xa0a0)
end

-- \jis: ISO-2022-JP による符号位置 => Unicharacter code 符号位置
function from_jis(i)
   if (type(i)~='number') or i>=0x10000 or i<0 then 
      ltjb.package_error('luatexja',
			 "invalid character code (".. tostring(i) .. ")",
			 "I'm going to use 0 instead of that illegal character code.")
      i=0
   end
   from_kuten(i-0x2020)
end

-- \sjis: Shift_JIS による符号位置 => Unicharacter code 符号位置
function from_sjis(i)
   if (type(i)~='number') or i>=0x10000 or i<0 then 
      ltjb.package_error('luatexja',
			 "invalid character code (".. tostring(i) .. ")",
			 "I'm going to use 0 instead of that illegal character code.")
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
	if c1>0x7f then i=0x40 else i=0x3f end
	c1 = c1 - i
     else
	c1 = c1 - 0x7e
     end
     from_kuten(c2*256+c1)
  end
end
