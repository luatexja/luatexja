--
-- luatexja/ltj-rmlgbm.lua
--
luatexja.load_module('base');      local ltjb = luatexja.base

local cidfont_data = {}
local cache_chars = {}
local cache_ver = '2'

local cid_reg, cid_order, cid_supp, cid_name
local cid_replace = {
   ["Adobe-Japan1"] = {"UniJIS2004-UTF32", 23057, 6,
		       function (i)
			  if (231<=i and i<=632) or (8718<=i and i<=8719) 
		             or (12063<=i and i<=12087) then
			     return 327680 -- 655360/2
			  elseif 9758<=i and i<=9778 then
			     return 218453 -- 655360/3
			  elseif 9738<=i and i<=9757 then
			     return 163840 -- 655360/4
			  end
		       end},
                       -- 基本的には JIS X 0213:2004 に沿ったマッピング
   ["Adobe-Korea1"] = {"UniKS-UTF32",  18351, 2, 
		       function (i)
			  if 8094<=i and i<=8100 then 
			     return 327680 -- 655360/2
			  end
		       end},
   ["Adobe-GB1"]    = {"UniGB-UTF32",  30283, 5, 
		       function (i)
			  if (814<=i and i<=939) or (i==7716) 
		             or (22355<=i and i<=22357) then
			     return 327680 -- 655360/2
			  end
		       end},
   ["Adobe-CNS1"]   = {"UniCNS-UTF32", 19155, 6,
		       function (i)
			  if (13648<=i and i<=13742) or (i==17603) then
			     return 327680 -- 655360/2
			  end
		       end},
}

-- reading CID maps
local make_cid_font
do
   local line, fh -- line, file handler
   local tt,cidm -- characters, cid->(Unicode)

   local function load_cid_char(cid_dec, mke)
      local cid, ucs, ucsa
      line = fh:read("*l")
      while line do
         if string.find(line, "end...?char") then 
            line = fh:read("*l"); return
         else -- WMA l is in the form "<%x+>%s%d+"
            ucs, cid = string.match(line, "<(%x+)>%s+<?(%x+)>?")
            cid = cid_dec(cid); ucs = tonumber(ucs, 16); 
            if not tt[ucs]  then 
               tt[ucs] = mke(cid); cidm[cid]=ucs
            end
         end
         line = fh:read("*l")
      end
   end

   local function load_cid_range(inc, cid_dec, mke)
      local bucs, eucs, cid
      line = fh:read("*l")
      while line do
        if string.find(line, "end...?range") then 
            line = fh:read("*l"); return
         else -- WMA l is in the form "<%x+>%s+<%x+>"
            bucs, eucs, cid = string.match(line, "<(%x+)>%s+<(%x+)>%s+<?(%x+)>?")
            cid = cid_dec(cid); 
	    bucs = tonumber(bucs, 16); eucs = tonumber(eucs, 16)
            for ucs = bucs, eucs do
               if not tt[ucs]  then 
                  tt[ucs] = mke(cid); cidm[cid]=ucs
               end
               cid = inc(cid)
            end
         end
         line = fh:read("*l")
      end
   end

   local function open_cmap_file(name, inc, cid_dec, mke)
      fh = io.open(kpse.find_file(name, 'cmap files'), "r")
      line = fh:read("*l")
      while line do
         if string.find(line, "%x+%s+begin...?char") then
            load_cid_char(cid_dec, mke)
         elseif string.find(line, "%x+%s+begin...?range") then
            load_cid_range(inc, cid_dec, mke)
         else
            line = fh:read("*l")
         end
      end
      fh:close();  
   end
   
   local function increment(a) return a+1 end
   local function entry(a)     
      return {index = a} 
   end
   make_cid_font = function ()
      local kx = cid_replace[cid_name]
      if not kx then return end
      local k = {
         cidinfo = { ordering=cid_order, registry=cid_reg, supplement=kx[3] },
         encodingbytes = 2, extend=1000, format = 'opentype',
         direction = 0, characters = {}, parameters = {}, embedding = "no", cache = "yes", 
         ascender = 0, descender = 0, factor = 0, hfactor = 0, vfactor = 0,
	 tounicode = 1,
      }
      cidfont_data[cid_name] = k

      -- CID => Unicode 符号空間
      -- TODO: vertical fonts?
      tt, cidm = {}, {}
      for i = 0,kx[2] do cidm[i] = -1 end
      open_cmap_file(kx[1] .. "-H", increment, tonumber, entry)
      k.characters = tt

      -- Unicode にマップされなかった文字の処理
      -- これらは TrueType フォントを使って表示するときはおかしくなる
      local ttu, pricode = {}, 0xF0000
      for i,v in ipairs(cidm) do
         if v==-1 then 
            tt[pricode], cidm[i], pricode 
	       = { index = i }, pricode, pricode+1;
         end
         ttu[cid_order .. '.' .. i] = cidm[i]
      end
      -- shared
      k.shared = {
         otfdata = { 
            cidinfo= k.cidinfo, verbose = false, 
            shared = { featuredata = {}, }, 
            luatex = { features = {}, 
		       defaultwidth=1000, 
		       sequences = {  }, },
         },
         dynamics = {}, features = {}, processes = {}, 
      }
      k.resources = { unicodes = ttu, }
      k.descriptions = {}
      cache_chars[cid_name]  = { [655360] = k.characters }

      -- tounicode エントリ
      local cidp = {nil, nil}; local cidmo = cidm
      tt, ttu, cidm = {}, {}, {}
      open_cmap_file(cid_name .. "-UCS2",
		     function(a) 
			a[2] = a[2] +1 ; return a
		     end, 
		     function(a) 
			cidp[1] = string.upper(string.sub(a,1,string.len(a)-4))
			cidp[2] = tonumber(string.sub(a,-4),16)
			return cidp
		     end,
		     function(a) return a[1] ..string.format('%04X',a[2])  end)
      -- tt は cid -> tounicode になっているので cidm -> tounicode に変換
      local kxf = kx[4]
      for i,v in ipairs(cidmo) do
	 k.characters[v].width = kxf(i)
	 if v>=0xF0000 then
	    k.characters[v].tounicode = tt[i]
	 end
      end

      -- Save
      k.characters[46].width = math.floor(655360/14);
      ltjb.save_cache( "ltj-cid-auto-" .. string.lower(cid_name),
		       {
			  version = cache_ver,
			  k,
		       })
   end
end

-- 
local function cid_cache_outdated(t) return t.version~=cache_ver end
local function read_cid_font()
   local dat = ltjb.load_cache("ltj-cid-auto-" .. string.lower(cid_name),
			       cid_cache_outdated )
   if dat then 
      cidfont_data[cid_name] = dat[1]
      cache_chars[cid_name]  = { [655360] = cidfont_data[cid_name].characters }
   else
      -- Now we must create the virtual metrics from CMap.
      make_cid_font()
   end
   if cidfont_data[cid_name] then
      for i,v in pairs(cidfont_data[cid_name].characters) do
         if not v.width then v.width = 655360 end
         v.height, v.depth = 576716.8, 78643.2 -- optimized for jfm-ujis.lua
      end
   end
end

-- High-level

local definers = fonts.definers
local function mk_rml(name, size, id)
   local specification = definers.analyze(name,size)
   specification = definers.resolve(specification)
   specification.detail = specification.detail or ''

   local fontdata = {}
   local cachedata = {}
   local s = cidfont_data[cid_name]
   for k, v in pairs(s) do
      fontdata[k] = v
      cachedata[k] = v
   end
   fontdata.characters = nil
   cachedata.characters = nil
   fontdata.shared = nil
   cachedata.shared = nil
   if s.shared then
      cachedata.shared = {}
      local shared = cachedata.shared
      for k, v in pairs(s.shared) do
	 shared[k] = v
      end
   end

   -- characters & scaling
   if size < 0 then size = -size * 655.36 end
   local scale = size / 655360

   do
      local def_height =  0.88 * size 
      -- character's default height (optimized for jfm-ujis.lua)
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
   end

   -- other parameters
   do
      local parameters = {}
      for k, v in pairs(s.parameters) do
	 parameters[k] = v * scale
      end
      fontdata.parameters  = parameters
      fontdata.ascender    = fontdata.ascender * scale
      fontdata.descender   = fontdata.descender * scale
      fontdata.factor      = fontdata.factor * scale
      fontdata.hfactor     = fontdata.hfactor * scale
      fontdata.vfactor     = fontdata.vfactor * scale
      fontdata.size        = size
      fontdata.resources   = s.resources
      cachedata.parameters = parameters
      cachedata.ascender   = fontdata.ascender
      cachedata.descender  = fontdata.descender
      cachedata.factor     = fontdata.factor
      cachedata.hfactor    = fontdata.hfactor
      cachedata.vfactor    = fontdata.vfactor
      cachedata.size       = size
      cachedata.resources  = s.resources
   end

   -- no embedding
   local var = ''
   local s = string.match(specification.detail, 'slant=([+-]*%d*%.?%d)')
   if s and e~=0  then 
      s = s * 1000
      var, fontdata.slant  = var .. 's' .. tostring(s), s
   end
   local e = string.match(specification.detail, 'extend=([+-]*%d*%.?%d)')
   if e and e~=1  then 
      e = e * 1000
      var, fontdata.extend  = var .. 'x' .. tostring(e), e
   end
   fontdata.name = specification.name .. size .. var; cachedata.name = fontdata.name
   fontdata.fullname = specification.name .. var; cachedata.fullname = fontdata.fullname
   fontdata.psname = specification.name; cachedata.psname = fontdata.psname
   fonts.hashes.identifiers[id] = cachedata

   return fontdata
end

local function font_callback(name, size, id, fallback)
   local p = utf.find(name, ":") or utf.len(name)+1
   if utf.sub(name, 1, p-1) == 'psft' then
      local s = "Adobe-Japan1-6"
      local basename = utf.sub(name,p+1)
      local p = utf.find(basename, ":")
      local q = utf.find(basename, "/[BI][BI]?")
      if q and p and q<=p then
	 basename = utf.gsub(basename, '/[BI][BI]?', '', 1)
	 p = utf.find(basename, ":")
      end
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
      return fallback(name, size, id)
   end
end

cid_reg, cid_order, cid_name, cid_supp = 'Adobe', 'Japan1', 'Adobe-Japan1'
read_cid_font()


luatexja.rmlgbm = {
   cidfont_data = cidfont_data,
   font_callback = font_callback,
}
