#!/usr/bin/env texlua

local stderr = io.stderr
local function show_usage(s)
  stderr:write('Error: ' .. s .. '\n'); 
  stderr:write('Usage: texlua jfm-convert [-J|-U] <ptex_jfm>\n'); 
  stderr:write('-J: JIS mode, -U: UCS mode \n'); 
  stderr:write(' * The output will be written to stdout.\n'); 
  stderr:write(' * I do not read  virtual fonts which corresponded to <ptex_jfm>.\n'); 
  stderr:write("   You will need to adjust 'align', 'left', 'down' entries by hand.\n");
  stderr:write(" * In JIS mode, characters which are not included in JIS X 0208\n");
  stderr:write("   (e.g., 0x2257) are written as 0x202577.\n");
  os.exit(1)
end

kpse.set_program_name('luatex')
require('lualibs'); local uchar = utf.char
jisx0208 = require('ltj-jisx0208.lua').table_jisx0208_uptex
local function pass_ucs(s)
   return  "'" .. uchar(s) .. "'" 
end
local function jis_to_ucs(s)
   local i = s - 0x2020
   local a = jisx0208[math.floor(i/256)*94+(i%256)-94] or 0
   return a and pass_ucs(a) or string.format('0x%X',s+0x200000)
end

-------- 引数解釈 --------


local filename
local mode

for i=1,#arg do
   if arg[i]=='-u' or arg[i]=='-U' then
      mode = pass_ucs
   elseif arg[i]=='-j' or arg[i]=='-J' then
      mode = jis_to_ucs
   elseif filename then
      show_usage('Multiple JFM files.')
   else
      filename = arg[i]
   end
end

if not filename then show_usage('Missing JFM file argument.') end
kpse.set_program_name('ptex')
local nf = kpse.find_file(filename, 'tfm')
if not nf then show_usage("JFM file can't be opened: " .. filename) end

-------- OPEN --------

local jfm_ptex = io.open(nf, 'rb')
local function get_word()
   local d = table.pack(string.byte(jfm_ptex:read(4),1,4))
   return d[1]*16777216+d[2]*65536+d[3]*256+d[4]
end
local function get_signed_word()
   local d = get_word()
   return  (d>=2147483648) and -(4294967296-d) or d
end
local extract = bit32.extract
local function get_two()
   local d = get_word()
   return extract(d,16,16), extract(d,0,16)
end
local function get_four()
   local d = get_word()
   return extract(d,24,8), extract(d,16,8), extract(d,8,8), extract(d,0,8)
end

local id, nt = get_two()
local lf, lh = get_two()
local bc, ec = get_two()
local nw, nh = get_two()
local nd, ni = get_two()
local nl, nk = get_two()
local ng, np = get_two()

if bc~=0 or
   lf~= 7 + lh + nt + (ec - bc + 1) + nw + nh + nd + ni + nl + nk + ng + np or
   (id~=11 and id~=9) then
      stderr:write('Bad JFM "' .. filename .. '".\n'); jfm_ptex:close(); os.exit(1)
end

local result = {}
result.dir = (id==11) and 'yoko' or 'tate'

-------- HEADER --------

_ = get_word() -- checksum, unused
local designsize = get_word()/1048576 -- ignored

local encoding
if lh>=3 then
   encoding   = ''
   for i=1,math.min(10,lh-2) do encoding = encoding .. jfm_ptex:read(4) end
   encoding = encoding:sub(2, 1+string.byte(encoding))
end
if not encoding then encoding = 'UNSPECIFIED' end

local family = ''
if lh>=13 then
   for i=1,math.min(5,lh-12) do family = family .. jfm_ptex:read(4) end
   family = family:sub(2, 1+string.byte(family))
end

local face = 0
if lh>=18 then
   _, _, _, face = get_four()
   for i=1,lh-19 do jfm_ptex:read(4) end -- ignored
end

-------- CHAR_TYPE --------
result[0] = {}
local all_ctype = {}
for i=1,nt do
   local ccode, ctype = get_two()
   if ccode~=0 then 
      all_ctype[#all_ctype+1] = ccode
   end
   if ctype~=0 then
      if not result[ctype] then result[ctype] = {} end
      if not result[ctype].chars then result[ctype].chars = {} end
      local t = result[ctype].chars
      t[#t+1] = ccode
   end
end

-------- CHAR_INFO --------
for i=0,ec do
   if not result[i] then result[i] = {} end
   local t, info = result[i], get_word()
   t.align, t.left, t.down  = 'left', 0, 0
   t.width  = extract(info, 24, 8)
   t.height = extract(info, 20, 4)
   t.depth  = extract(info, 16, 4)
   t.italic = extract(info, 10, 6)
   t.tag = extract(info, 8, 2)
   t.rem = extract(info, 0, 8)
end

local wi, hi, di, ii = {}, {}, {}, {}
for i=0,nw-1 do wi[i] = get_signed_word() end
for i=0,nh-1 do hi[i] = get_signed_word() end
for i=0,nd-1 do di[i] = get_signed_word() end
for i=0,ni-1 do ii[i] = get_signed_word() end


-------- GLUE/KERN --------

local gk_table = {}
for i=0,nl-1 do  gk_table[i] = table.pack(get_four()) end

local kerns = {}
for i=0,nk-1 do kerns[i] = get_signed_word() end

local glues = {}
for i=0,ng/3-1 do glues[i] = { get_signed_word(), get_signed_word(), get_signed_word() } end


-------- PARAM --------
local param = {}
for i=1,math.min(9, np) do param[i] = get_word() end
local zw = param[6]
result.kanjiskip = {
   param[2]/zw, param[3]/zw, param[4]/zw
}
result.xkanjiskip = {
   param[7]/zw, param[8]/zw, param[9]/zw
}
result.zw, result.zh = 1.0, param[5]/zw



-------- 各種 index の解決 --------
for i=0,ec do
   local t = result[i]
   t.width  = wi[t.width]/zw
   t.height = hi[t.height]/zw
   t.depth  = di[t.depth]/zw
   t.italic = ii[t.italic]/zw
   if t.tag==1 then
      local j = t.rem
      while j do
	 local gkp = gk_table[j]
	 j = (gkp[1]<128) and j+gkp[1]+1 or nil
	 if gkp[3]<128 then
	    if not t.glue then t.glue = {} end
	    t.glue[gkp[2]] = {
	       glues[gkp[4]][1]/zw, 
	       glues[gkp[4]][2]/zw, 
	       glues[gkp[4]][3]/zw, 
	    }
	 else
	    if not t.kern then t.kern = {} end
	    t.kern[gkp[2]] = kerns[gkp[4]]/zw
	 end
      end
   end
   t.tag, t.rem  = nil, nil
end

jfm_ptex:close()


-------- モード判定 --------
if not mode then
   mode = jis_to_ucs
   for i=1, #all_ctype do
      local i = all_ctype[i]-0x2020
      if not jisx0208[math.floor(i/256)*94+(i%256)-94] then
	 mode = pass_ucs; break
      end
   end
end

-------- 出力 --------
local function S(a)
   if type(a)=='number' then
      return tostring(math.floor(a*1000000+0.5)/1000000)
   elseif type(a)=='table' then -- glue
      return '{ ' .. S(a[1]) .. ', ' .. S(a[2]) .. ', ' .. S(a[3]) .. '},'
   elseif type(a)=='string' then
      return "'" .. a .. "'"
   else
      tostring(a)
   end
end

print('-- -*- coding: utf-8 -*-')
print('-- converted from ' .. filename .. ' by jfm_convert.lua')
print('-- assumed encoding:  ' .. (mode==jis_to_ucs and 'JIS' or 'UCS') .. '\n')
print('luatexja.jfont.define_jfm {')
print('   -- original design size = ' .. S(designsize))
print('   -- original encoding    = (' .. encoding .. ')')
print('   -- original family      = (' .. family .. ')')
print("   dir = " .. S(result.dir) .. ",")
print('   zw = ' .. S(result.zw) .. ', zh = ' .. S(result.zh) .. ', ')
print('   kanjiskip = ' .. S(result.kanjiskip))
print('   xkanjiskip = ' .. S(result.xkanjiskip))
for i=0, ec do
   local t = result[i]
   print('   [' .. tostring(i) .. '] = {')
   if t.chars then
      print('      chars = {')
      local d = '         '
      for j=1,#(t.chars) do
	 d = d ..  mode(t.chars[j]) .. ', '
	 if j%8==0 and j<#(t.chars) then
	    d = d .. '\n         '
	 end
      end
      print(d)
      print('      },')
   end
   print('      align = ' .. S(t.align) .. ', left = ' .. S(0.0) 
	    .. ', down = ' .. S(0.0) .. ', ')
   print('      width = ' .. S(t.width) .. ', height = ' .. S(t.height) 
	    .. ', depth = ' .. S(t.depth) .. ', italic = ' .. S(t.italic) .. ',')
   if t.glue then
      print('      glue = {')
      local gi = {}
      for m,_ in pairs(t.glue) do gi[#gi+1]=m end
      table.sort(gi)
      for _,m in ipairs(gi) do
	 print('         [' .. tostring(m) .. '] = ' .. S(t.glue[m]))
      end
      print('      },')
   end
   if t.kern then
      print('      kern = {')
      local gi = {}
      for m,_ in pairs(t.kern) do gi[#gi+1]=m end
      table.sort(gi)
      for _,m in ipairs(gi) do
	 print('         [' .. tostring(m) .. '] = ' .. S(t.kern[m]) .. ',')
      end
      print('      },')
   end
   print('   },')
end
print('}')
