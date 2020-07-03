--
-- ltj-lotf_aux.lua
--

-- functions which access to caches by luaotfload gathered in this file.
-- lines with marked by "-- HARFLOAD" are codes for harfload
local aux = {}
luatexja.lotf_aux = aux

local font_metric_table = {}
aux.font_metric_table = font_metric_table

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
  elseif t and t.hb then -- HARF
    local hb, tf = luaotfload.harfbuzz, t.hb.spec.hb_features
    tf[#tf+1] = hb.Feature.new(name)
  end
end
function aux.specified_feature(id, name)
  local t = getfont(id)
  return t and (t.shared and t.shared.features and t.shared.features[name])
         or (t.hb and t.hb.spec and t.hb.spec.features.raw and t.hb.spec.features.raw[name]) -- HARF
end


do
local nulltable = {}
local function get_cidinfo(id) -- table
  local t = getfont(id)
  return (t and (t.resources and t.resources.cidinfo or t.cidinfo)) or nulltable
end
aux.get_cidinfo = get_cidinfo
end

local function get_asc_des(id)
  local t, v = getfont(id), font_metric_table[id]
  local a, d
  if t and t.shared and t.shared.rawdata then
    local u = t.units
    local t2 = t.shared.rawdata.metadata
    if t2 then
      a, d = t2.ascender and t2.ascender/u, t2.descender and -t2.descender/u
    end
  elseif t.hb then -- HARF
    local hbfont, u = t.hb.shared.font, t.hb.shared.upem
    local h = hbfont:get_h_extents()
    if h and u then 
       a, d = h.ascender and h.ascender/u, h.descender and -h.descender/u
    end
  end
  v.ascender, v.descender =  (a or 0.88)*t.size, (d or 0.12)*t.size
end
local function get_ascender(id) -- scaled points
  if not font_metric_table[id].ascender then get_asc_des(id) end
  return font_metric_table[id].ascender
end

local function get_descender(id) -- scaled points
  if not font_metric_table[id].descender then get_asc_des(id) end
  return font_metric_table[id].descender
end
aux.get_ascender, aux.get_descender = get_ascender, get_descender

do
local dummy_vht, dummy_vorg = {}, {}
setmetatable(dummy_vht, {__index = function () return 1 end } )
setmetatable(dummy_vorg, {__index = function () return 0.88 end } )
local function get_vmet_table(tfmdata, dest)
   if (not tfmdata) or (not tfmdata.shared) or (not tfmdata.shared.rawdata) then
     dest = dest or {}
     dest.vorigin, dest.vheight = dummy_vorg, dummy_vht
     dest.ind_to_uni = {}
     return dest
   end
   local rawdata = tfmdata.shared.rawdata
   local ascender = rawdata.metadata.ascender or 0
   local default_vheight 
     = rawdata.metadata.defaultvheight
       or (rawdata.metadata.descender and (ascender+rawdata.metadata.descender) or units)
   local units = tfmdata.units
   local t_vorigin, t_vheight, t_ind_to_uni = {}, {}, {}
   for i,v in pairs(rawdata.descriptions) do
     t_ind_to_uni[v.index] = i
     if v.tsb then
       local j = v.boundingbox[4] + v.tsb
       if j~=ascender then t_vorigin[i]= j / units end
     end
     if v.vheight then
       if v.vheight~=default_vheight then t_vheight[i] = v.vheight / units end
     end
   end
   local vhd, vod = default_vheight / units, ascender/units
   t_vheight.default = vhd
   t_vorigin.default = vod
   setmetatable(t_vheight, {__index = function () return vhd end } )
   setmetatable(t_vorigin, {__index = function () return vod end } )
   dest = dest or {}
   dest.ind_to_uni = t_ind_to_uni
   dest.vorigin = t_vorigin -- designed size = 1.0
   dest.vheight = t_vheight -- designed size = 1.0
   return dest
end
aux.get_vmet_table = get_vmet_table
end
local function loop_over_duplicates(id, func)
-- func: return non-nil iff abort this fn
  local t = (type(id)=="table") and id or getfont(id)
  if t and t.resources and t.resources.duplicates then -- HARF: not executed
    for i,v in pairs(t.resources.duplicates) do
      func(i,v)
    end
  end
end
aux.loop_over_duplicates = loop_over_duplicates

local function loop_over_feat(id, feature_name, func, universal)
-- feature_name: like { vert=true, vrt2 = true, ...}
-- func: return non-nil iff abort this fn
-- universal: true iff look up all (script, lang) pair
  local t = (type(id)=="table") and id or getfont(id)
  if t and t.resources and t.resources.sequences then -- HARF: not executed
    for _,i in pairs(t.resources.sequences) do
      if i.order[1] and feature_name[i.order[1]] then
        local f = i.features and i.features[i.order[1]]
        if i.type == 'gsub_single' and i.steps 
          and f and (universal or (f[t.properties.script] and f[t.properties.script][t.properties.language])) then
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


--for name, func in pairs(aux) do
--  if type(func)=="function" then 
--    aux[name] = function(...)
--      print('LOTF_AUX', name, ...);
--      local a = func(...); print('RESULT', a); return a
--    end
--  end
--end

local search
search = function (t, key, prefix)
  if type(t)=="table" then
    prefix = prefix or ''
    for i,v in pairs(t) do 
      if i==key then print(prefix..'.'..i, v) 
      else  search(v,key,prefix..'.'..tostring(i)) end
    end
  end
end
aux.t_search = search



-- EOF
