print([[
local f = false
return {
version = 3,
table_ivd_aj1 = {]])

local f = io.open('IVD_Sequences.txt')
local t, maxcid = {}, 0
local s = f:read()
while s do
    if s:match('#') then
	print('-- ' .. s)
    elseif s:match('Adobe.Japan.') then
	local c1,c2,c3 = s:match('(%x+)%s+(%x+);%s+Adobe.Japan.;%s+CID%+(%d+)')
	c1, c2, c3 = tonumber(c1, 16), tonumber(c2, 16), tonumber(c3)
	if c2 and c2>=0xE0100 then
	    c2 = c2 - 0xE00FF
	    if maxcid<c3 then maxcid = c3 end
	    t[c3] = c2*0x200000+c1
	end
    end
    s = f:read()
end
f:close()

local s={}
for i=1,maxcid do
    s[#s+1] = t[i] and string.format('0x%x', t[i]) or 'f'
    if #s==10 then print(" " .. table.concat(s, ",") .. ','); s={} end
end
print(" " .. table.concat(s, ","))

-- ( echo 'luatexja.otf.ivd_aj1 = {' ; grep 'Adobe-Japan1' IVD_Sequences.txt|sed 's/\([0-9A-F][0-9A-F]*\) \([0-9A-F][0-9A-F]*\)\;.*CID.\([0-9][0-9]*\)$/[\3]=\{0x\1,0x\2\},/' ; echo '}' )
print([[}}]])

