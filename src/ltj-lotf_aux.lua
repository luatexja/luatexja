--
-- ltj-lotf_aux.lua
--

-- functions which access to fonts.* will be gathered in this file.
local aux = {}
luatexja.lotf_aux = aux

local getfont
do
  local font_getfont = font.getfont
  getfont = function (id) return (type(id)=="table") and id or font_getfont(id) end
end
  -- accept font number or table
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

local function loop_over_feat(id, feature_name, func)
-- feature_name: like { vert=true, vrt2 = true, ...}
-- func: return non-nil iff abort this fn
  local t = getfont(id)
  if t and t.resources and t.resources.sequences then
    for _,i in pairs(t.resources.sequences) do
      if i.order[1] and feature_name[i.order[1]] then
        local f = i.features and i.features[i.order[1]]
        if i.type == 'gsub_single' and i.steps 
          and f and f[t.properties.script] and f[t.properties.script][t.properties.language] then
          for _,j in pairs(i.steps) do
            if type(j)=='table' then 
              if type(j.coverage)=='table' then
                for i,k in pairs(j.coverage) do
                  local s = func(i,k); if s then return s end
                end
              end
            end
          end
        end
      end
    end
  end
end
aux.loop_over_feat = loop_over_feat

local vert_vrt2 = { vert=true, vrt2=true }
function aux.replace_vert_variant(id, c)
  return loop_over_feat(id, vert_vrt2, 
           function (i,k) if i==c then return k end end)
	 or c
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
