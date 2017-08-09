local utr_revision = 17
print('  local function rotate_in_utr50(i)')
print('  -- UTR#50 revision ' ..  utr_revision)
local fh = io.open('VerticalOrientation-' .. utr_revision .. '.txt')
local t = {}

for c in fh:lines() do
    if c:match('(%x+)%.%.(%x+)%s+;%sT-[rR]') then
	local b, e = c:match('(%x+)%.%.(%x+)%s+;')
	b, e = tonumber(b,16), tonumber(e,16)
	for i=b,e do t[i]=true end
    elseif c:match('(%x+)%s+;%sT-[rR]') then
	local b = c:match('(%x+)%s+;')
	t[tonumber(b,16)]=true
    end
end

fh:close()
local b, v
for i=0,0x10ffff do
    if t[i] then
	if not v then 
	    b, v = i, true
	else
	    e=i
	end
    else
	if v then print(string.format('    if (0x%04X<=i)and(i<0x%04X) then return true end', b,i)); v = false; end
    end
end
print('  end')

