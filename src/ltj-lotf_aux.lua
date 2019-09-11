--
-- ltj-lotf_aux.lua
--

-- functions which access to fonts.* will be gathered in this file.
local aux = {}
luatexja.lotf_aux = aux

local getfont = font.getfont
local provides_feature = luaotfload.aux.provides_feature
function aux.exist_feature(id, name)
  local t = getfont(id)
  if t and t.properties then
    return provides_feature(id, t.properties.script, t.properties.language, name)
  else return false
  end
end 

function aux.enable_feature(id, name)
  local t = getfont(id)
  if t and t.shared and t.shared.features then
    t.shared.features[name] = true
  end
end
function aux.specified_feature(id, name)
  local t = getfont(id)
  return (t and t.shared and t.shared.features and t.shared.features[name])
end

local function get_ascender(id) -- scaled points
  local t = getfont(id)
  return (t and t.parameters and t.parameters.ascender) or 0
end
local function get_descender(id) -- scaled points
  local t = getfont(id)
  return (t and t.parameters and t.parameters.descender) or 0
end
aux.get_ascender, aux.get_descender = get_ascender, get_descender

function aux.get_vheight(id, c) -- scaled points
    local t = getfont(id)
  if t and t.descriptions and t.descriptions[c] and t.descriptions[c].vheight then
    return t.descriptions[c].vheight / t.units * t.size
  elseif t and t.shared and t.shared.rawdata and t.shared.rawdata.metadata then
    return t.shared.rawdata.metadata.defaultvheight / t.units * t.size
  else
    return get_ascender(id) + get_descender(id)
  end
end

local search
search = function (t, key, prefix)
  if type(t)=="table" then
    for i,v in pairs(t) do 
      if i==key then print(prefix..'.'..i, v) 
      else  search(v,key,prefix..'.'..tostring(i)) end
    end
  end
end
aux.t_search = search

-- EOF
