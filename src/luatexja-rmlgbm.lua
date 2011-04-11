function ltj.mk_rml(name, size, id)
   ltj.rmlgbm_data = ltj.rmlgbm_data or require('luatexja-rmlgbm-data')

   local specification = fonts.define.analyze(name,size)
   local method = specification.method
   specification = fonts.define.specify[method](specification)
   local features = specification.features.normal

   -- below are taken from otfl-font-otf.lua (luaotfload v1.24)

   -- from fonts.otf.otf_to_tfm()
   local tfmdata
   ltj.rmlgbm_data.shared = ltj.rmlgbm_data.shared or {
      featuredata = { },
      anchorhash  = { },
      initialized = false,
   }
   tfmdata = fonts.otf.copy_to_tfm(ltj.rmlgbm_data)
   tfmdata.unique = tfmdata.unique or { }
   tfmdata.shared = tfmdata.shared or { } -- combine
   local shared = tfmdata.shared
   shared.otfdata = ltj.rmlgbm_data
   shared.features = features -- default
   shared.dynamics = { }
   shared.processes = { }
   shared.set_dynamics = fonts.otf.set_dynamics -- fast access and makes other modules independent
   -- this will be done later anyway, but it's convenient to have
   -- them already for fast access
   tfmdata.luatex = ltj.rmlgbm_data.luatex
   tfmdata.indices = ltj.rmlgbm_data.luatex.indices
   tfmdata.unicodes = ltj.rmlgbm_data.luatex.unicodes
   tfmdata.marks = ltj.rmlgbm_data.luatex.marks
   tfmdata.originals = ltj.rmlgbm_data.luatex.originals
   tfmdata.changed = { }
   tfmdata.has_italic = ltj.rmlgbm_data.metadata.has_italic
   if not tfmdata.language then tfmdata.language = 'dflt' end
   if not tfmdata.script   then tfmdata.script   = 'dflt' end
   shared.processes, shared.features = fonts.otf.set_features(tfmdata,fonts.define.check(features,fonts.otf.features.default))
   
   -- from fonts.otf.read_from_open_type()
   tfmdata = fonts.tfm.scale(tfmdata, size)

   -- no embedding
   tfmdata.name = specification.name .. size
   tfmdata.fullname = specification.name
   tfmdata.psname = specification.name
   tfmdata.embedding='no'; 
   tfmdata.cache='no'

   fonts.ids[id] = tfmdata

   return tfmdata
end

local dr_orig = fonts.define.read
function fonts.define.read(name, size, id)
   local p = utf.find(name, ":") or utf.len(name)+1
   local tmp = utf.sub(name, 1, p-1)
   if tmp == 'psft' then
      return ltj.mk_rml(utf.sub(name,p+1), size, id)
   else 
      return dr_orig(name, size, id)
   end
end
