--
-- luatexja/rmlgbm.lua
--
luatexbase.provides_module({
  name = 'luatexja.rmlgbm',
  date = '2011/06/27',
  version = '0.1',
  description = 'Definitions of non-embedded Japanese fonts',
})
module('luatexja.rmlgbm', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

local rmlgbm_data = require('luatexja-rmlgbm-data')
local cache_chars = { [655360] = rmlgbm_data.characters }

local function mk_rml(name, size, id)
   local specification = fonts.define.analyze(name,size)
   specification = fonts.define.specify[':'](specification)
   local features = specification.features.normal

   local fontdata = {}
   local cachedata = {}
   for k, v in pairs(rmlgbm_data) do
      fontdata[k] = v
      cachedata[k] = v
   end
   fontdata.characters = nil
   cachedata.characters = nil
   fontdata.unicodes = nil
   fontdata.shared = nil
   cachedata.shared = {}
   local shared = cachedata.shared
   for k, v in pairs(rmlgbm_data.shared) do
      shared[k] = v
   end

   shared.set_dynamics = fonts.otf.set_dynamics 
   shared.processes, shared.features = fonts.otf.set_features(cachedata,fonts.define.check(features,fonts.otf.features.default))
   
   -- characters & scaling
   if size < 0 then size = -size * 655.36 end
   local scale = size / 655360
   if not cache_chars[size] then
      cache_chars[size]  = {}
      for k, v in pairs(cache_chars[655360]) do
         cache_chars[size][k] = {}
         cache_chars[size][k].index = v.index
         cache_chars[size][k].width = v.width * scale
         cache_chars[size][k].tounicode = v.tounicode
      end
   end
   fontdata.characters = cache_chars[size]
   cachedata.characters = cache_chars[size]

   local parameters = {}
   for k, v in pairs(rmlgbm_data.parameters) do
      parameters[k] = v * scale
   end
   fontdata.parameters = parameters
   cachedata.parameters = parameters

   fontdata.ascender = fontdata.ascender * scale
   cachedata.ascender = fontdata.ascender
   fontdata.descender = fontdata.descender * scale
   cachedata.descender = fontdata.descender
   fontdata.factor = fontdata.factor * scale
   cachedata.factor = fontdata.factor
   fontdata.hfactor = fontdata.hfactor * scale
   cachedata.hfactor = fontdata.hfactor
   fontdata.vfactor = fontdata.vfactor * scale   
   cachedata.vfactor = fontdata.vfactor
   fontdata.size = size
   cachedata.size = size

   -- no embedding
   local var = ''
   if features.slant then 
      fontdata.slant = features.slant*1000
      cachedata.slant = fontdata.slant
      var = var .. 's' .. tostring(features.slant)
   end
   if features.extend then 
      fontdata.extend = features.extend*1000
      cachedata.extend = fontdata.extend
       var = var .. 'x' .. tostring(features.extend)
  end
   fontdata.name = specification.name .. size .. var
   cachedata.name = fontdata.name
   fontdata.fullname = specification.name .. var
   cachedata.fullname = fontdata.fullname

   fontdata.psname = specification.name
   cachedata.psname = fontdata.psname

   fonts.ids[id] = cachedata

   return fontdata
end

local dr_orig = fonts.define.read
function fonts.define.read(name, size, id)
   local p = utf.find(name, ":") or utf.len(name)+1
   if utf.sub(name, 1, p-1) == 'psft' then
      return mk_rml(utf.sub(name,p+1), size, id)
   else 
      return dr_orig(name, size, id)
   end
end
