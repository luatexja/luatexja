kpse.set_program_name('luatex')
dofile(kpse.find_file('lualibs.lua'))

local function toX(a) return string.format('0x%X',a) end

local uax_revision = '14.0.0'
print('  -- UAX#50 for Unicode  ' ..  uax_revision)
local fh = io.open('VerticalOrientation-' .. uax_revision .. '.txt')
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
local t2={}
local b, v = 0, t[0]
for i=0,0x10ffff do
    if t[i]~=v then
	table.insert(t2,b); b, v=i, t[i]
    end
end
table.insert(t2,b)

print('  -- t[0] = ' .. tostring(t[0]))
print(table.serialize(t2,'  local t'))

--[[
for i,v in ipairs(t2) do
    print(i, toX(v[1]) .. ' ≦x< ' .. toX(v[2]),  v[3])
end
]]

print([[  local function rotate_in_uax50(i)
    local lo, hi = 1, #t
    while lo < hi do
      local mi = math.ceil((lo+hi)/2)
      if t[mi]<=i then lo=mi else hi=mi-1 end 
    end
    return lo%2==1
  end
]])

