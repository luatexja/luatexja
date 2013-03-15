--
-- luatexja/rmlgbm.lua
--
luatexbase.provides_module({
  name = 'luatexja.rmlgbm',
  date = '2012/04/21',
  version = '0.3',
  description = 'Definitions of non-embedded Japanese (or other CJK) fonts',
})
module('luatexja.rmlgbm', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

luatexja.load_module('base');      local ltjb = luatexja.base

local cidfont_data = {}
local cache_chars = {}
local path           = {
    localdir  = file.join(kpse.expand_var("$TEXMFVAR"), aux_dir),
    systemdir = file.join(kpse.expand_var("$TEXMFSYSVAR"), aux_dir),
}

local cid_reg, cid_order, cid_supp, cid_name
local taux_dir = 'luatex-cache/luatexja'
local cid_replace = {
   ["Adobe-Japan1"] = "UniJIS2004-UTF32", -- JIS X 0213:2004
   ["Adobe-Korea1"] = "UniKS-UTF32",
   ["Adobe-GB1"]    = "UniGB-UTF32",
   ["Adobe-CNS1"]   = "UniCNS-UTF32",
}

-- reading CID maps
local line, fh, tt

local function load_bf_char()
   local cid, ucs, ucsa
   line = fh:read("*l")
   while line do
      if line == "endcidchar" then 
	 line = fh:read("*l"); return
      else -- WMA l is in the form "<%x+>%s%d+"
	 ucs, cid = string.match(line, "<(%x+)>%s+(%d+)")
	 cid = tonumber(cid, 10); ucs = tonumber(ucs, 16); 
	 if not tt[ucs]  then 
	    tt[ucs] = { index = cid } 
	 end
      end
      line = fh:read("*l")
   end
end

local function load_bf_range()
   local bucs, eucs, cid
   line = fh:read("*l")
   while line do
      if line == "endcidrange" then 
	 line = fh:read("*l"); return
      else -- WMA l is in the form "<%x+>%s+<%x+>"
	 bucs, eucs, cid = string.match(line, "<(%x+)>%s+<(%x+)>%s+(%d+)")
	 cid = tonumber(cid, 10); bucs = tonumber(bucs, 16); eucs = tonumber(eucs, 16);
	 for ucs = bucs, eucs do
	    if not tt[ucs]  then 
	       tt[ucs] = { index = cid }
	    end
	    cid = cid+1
	 end
      end
      line = fh:read("*l")
   end
end

local function make_cid_font()
   cidfont_data[cid_name] = {
      cidinfo = { ordering=cid_order, registry=cid_reg, supplement=cid_supp },
      encodingbytes = 2, extend=1000, format = 'opentype',
      direction = 0, characters = {}, parameters = {}, embedding = "no", cache = "yes", 
      ascender = 0, descender = 0, factor = 0, hfactor = 0, vfactor = 0, 
   }
   tt = {}

   -- Open
   -- TODO: vertical fonts?
   fh = io.open(kpse.find_file(cid_replace[cid_name] .. "-H", 'cmap files'), "r")
   line = fh:read("*l")
   while line do
      if string.find(line, "%x+%s+begincidchar") then
	 load_bf_char()
      elseif string.find(line, "%x+%s+begincidrange") then
	 load_bf_range()
      else
	 line = fh:read("*l")
      end
   end
   fh:close();  cidfont_data[cid_name].characters = tt
   cache_chars[cid_name]  = { [655360] = cidfont_data[cid_name].characters }

   -- Save
   local savepath  = path.localdir .. '/luatexja/'
   if not lfs.isdir(savepath) then
      dir.mkdirs(savepath)
   end
   savepath = file.join(savepath, "ltj-cid-auto-" 
			.. string.lower(cid_name)  .. ".lua")
   if file.iswritable(savepath) then
      table.tofile(savepath, cidfont_data[cid_name],'return', false, true, false )
   else 
      ltjb.package_warning('luatexja', 
			   'failed to save informations of non-embedded 2-byte fonts', '')
   end
end

-- 
local function read_cid_font()
   -- local v = "ltj-cid-" .. string.lower(cid_name) .. ".lua"
   local v = "ltj-cid-auto-" .. string.lower(cid_name) .. ".lua"
   local localpath  = file.join(path.localdir, v)
   local systempath = file.join(path.systemdir, v)
   local kpsefound  = kpse.find_file(v)
   if kpsefound and file.isreadable(kpsefound) then
      cidfont_data[cid_name] = require(kpsefound)
      cache_chars[cid_name]  = { [655360] = cidfont_data[cid_name].characters }
   elseif file.isreadable(localpath)  then
      cidfont_data[cid_name] = require(localpath)
      cache_chars[cid_name]  = { [655360] = cidfont_data[cid_name].characters }
   elseif file.isreadable(systempath) then
      cidfont_data[cid_name] = require(systempath)
      cache_chars[cid_name]  = { [655360] = cidfont_data[cid_name].characters }
   end
   -- Now we must create the virtual metrics from CMap.
   ltjb.package_info('luatexja', 
			'I try to generate informations of non-embedded 2-byte fonts...', '')
   make_cid_font()

   if cidfont_data[cid_name] then
      for i,v in pairs(cidfont_data[cid_name].characters) do
         if not v.width then v.width = 655360 end
         v.height, v.depth = 576716.8, 78643.2 -- optimized for jfm-ujis.lua
      end
   end
end

-- High-level
local function mk_rml(name, size, id)
   local specification = fonts.define.analyze(name,size)
   specification = fonts.define.specify[':'](specification)
   local features = specification.features.normal

   local fontdata = {}
   local cachedata = {}
   local s = cidfont_data[cid_name]
   for k, v in pairs(s) do
      fontdata[k] = v
      cachedata[k] = v
   end
   fontdata.characters = nil
   cachedata.characters = nil
   fontdata.unicodes = nil
   fontdata.shared = nil
   cachedata.shared = nil
   if s.shared then
      cachedata.shared = {}
      local shared = cachedata.shared
      for k, v in pairs(s.shared) do
	 shared[k] = v
      end
      
      shared.set_dynamics = fonts.otf.set_dynamics 
      shared.processes, shared.features = fonts.otf.set_features(cachedata,fonts.define.check(features,fonts.otf.features.default))
   end

   -- characters & scaling
   if size < 0 then size = -size * 655.36 end
   local scale = size / 655360
   local def_height =  0.88 * size -- character's default height (optimized for jfm-ujis.lua)
   local def_depth =  0.12 * size  -- and depth.
   if not cache_chars[cid_name][size] then
      cache_chars[cid_name][size]  = {}
      for k, v in pairs(cache_chars[cid_name][655360]) do
         cache_chars[cid_name][size][k] = { 
	    index = v.index, width = v.width * scale, 
	    height = def_height, depth = def_depth, tounicode = v.tounicode,
	 }
      end
   end
   fontdata.characters = cache_chars[cid_name][size]
   cachedata.characters = cache_chars[cid_name][size]

   local parameters = {}
   for k, v in pairs(s.parameters) do
      parameters[k] = v * scale
   end
   fontdata.parameters = parameters;                cachedata.parameters = parameters
   fontdata.ascender = fontdata.ascender * scale;   cachedata.ascender = fontdata.ascender
   fontdata.descender = fontdata.descender * scale; cachedata.descender = fontdata.descender
   fontdata.factor = fontdata.factor * scale;       cachedata.factor = fontdata.factor
   fontdata.hfactor = fontdata.hfactor * scale;     cachedata.hfactor = fontdata.hfactor
   fontdata.vfactor = fontdata.vfactor * scale;     cachedata.vfactor = fontdata.vfactor
   fontdata.size = size;                            cachedata.size = size

   -- no embedding
   local var = ''
   if features.slant then 
      fontdata.slant = features.slant*1000;         cachedata.slant = fontdata.slant
      var = var .. 's' .. tostring(features.slant)
   end
   if features.extend then 
      fontdata.extend = features.extend*1000;       cachedata.extend = fontdata.extend
       var = var .. 'x' .. tostring(features.extend)
  end
   fontdata.name = specification.name .. size .. var; cachedata.name = fontdata.name
   fontdata.fullname = specification.name .. var; cachedata.fullname = fontdata.fullname
   fontdata.psname = specification.name; cachedata.psname = fontdata.psname
   fonts.ids[id] = cachedata

   return fontdata
end

local dr_orig = fonts.define.read
function fonts.define.read(name, size, id)
   local p = utf.find(name, ":") or utf.len(name)+1
   if utf.sub(name, 1, p-1) == 'psft' then
      local s = "Adobe-Japan1-6"
      local basename = utf.sub(name,p+1)
      local p = utf.find(basename, ":")
      if p then 
	 local xname = utf.sub(basename, p+1)
	 p = 1
	 while p do
	    local q = utf.find(xname, ";", p+1) or utf.len(xname)+1
	    if utf.sub(xname, p, p+3)=='cid=' and q>p+4 then
	       s = utf.sub(xname, p+4, q-1)
	    end
	    if utf.len(xname)+1==q then p = nil else p = q + 1 end
	 end
      end
      cid_reg, cid_order = string.match(s, "^(.-)%-(.-)%-(%d-)$")
      if not cid_reg then 
         cid_reg, cid_order = string.match(s, "^(.-)%-(.-)$")
      end
      cid_name = cid_reg .. '-' .. cid_order
      if not cidfont_data[cid_name] then 
         read_cid_font()
         if not cidfont_data[cid_name] then 
            ltjb.package_error('luatexja',
                               "bad cid key `" .. s .. "'",
                               "I couldn't find any non-embedded font information for the CID\n" ..
                                  '`' .. s .. "'. For now, I'll use `Adobe-Japan1-6'.\n"..
                                  'Please contact the LuaTeX-ja project team.')
            cid_name = "Adobe-Japan1"
         end
      end
      return mk_rml(basename, size, id)
   else 
      return dr_orig(name, size, id)
   end
end

cid_reg, cid_order, cid_name = 'Adobe', 'Japan1', 'Adobe-Japan1'
read_cid_font()