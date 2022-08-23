--
-- ltj-rmlgbm.lua
--
luatexja.load_module 'base';      local ltjb = luatexja.base

local cidfont_data = {}
local cache_chars = {}
local cache_ver = 11
local identifiers = fonts.hashes.identifiers

local cid_reg, cid_order, cid_supp, cid_name
local cid_replace = {
   ["Adobe-Japan1"] = {"UniJIS2004-UTF32", 23059, 7,
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
   ["Adobe-CNS1"]   = {"UniCNS-UTF32", 19178, 7,
                       function (i)
                          if (13648<=i and i<=13742) or (i==17603) then
                             return 327680 -- 655360/2
                          end
                       end},
   ["Adobe-KR"] = {"UniAKR-UTF32", 22896, 9,
                       function (i)
                          if i==3057 then
                             return 655360*2
                          elseif i==3058 then
                             return 655360*3
                          elseif i==12235 or i==12236 then
                             return 163840 -- 655360/4
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
      local fn = kpse.find_file(name, 'cmap files')
      if fn then
         fh = io.open(fn, "r")
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
   end

   local function increment(a) return a+1 end
   local function entry(a)
      return {index = a}
   end
   local feat_dummy_vert = { gsub={vert={dflt={dflt=true}}} }
   local seq_dummy_vert={{
     features={vert={dflt={dflt=true}}},
     --flags={false,false,false,false},
     --index=1, name="s_s_0", skiphash=false, steps={coverage={},index=1},
     ["type"]="gsub_single", order='vert',
   }}
   make_cid_font = function ()
      local kx = cid_replace[cid_name]
      if not kx then return end
      local k = {
         cidinfo = { ordering=cid_order, registry=cid_reg, supplement=kx[3] },
         encodingbytes = 2, extend=1000, format = 'opentype',
         direction = 0, characters = {}, parameters = {
            ascender = 655360*0.88,
            descender = 655360*0.12,
         },
         embedding = "no", cache = "yes", factor = 0, hfactor = 0, vfactor = 0,
         tounicode = 1,
         properties = { language = "dflt", script = "dflt" },
      }
      cidfont_data[cid_name] = k

      -- CID => Unicode 符号空間
      local tth, cidmo = {}, {}
      tt, cidm = tth, cidmo
      for i = 0,kx[2] do cidm[i] = -1 end
      open_cmap_file(kx[1] .. "-H", increment, tonumber, entry)
      k.characters = tth

      -- Unicode にマップされなかった文字の処理
      -- これらは TrueType フォントを使って表示するときはおかしくなる
      local ttu, pricode = {}, 0xF0000
      for i,v in ipairs(cidmo) do
         if v==-1 then
            tth[pricode], cidmo[i], pricode
               = { index = i }, pricode, pricode+1;
         end
         ttu[i] = cidmo[i]
         ttu[cid_order .. '.' .. i] = cidmo[i]
      end

      -- shared
      k.shared = {
         otfdata = {
            cidinfo= k.cidinfo, verbose = false,
            shared = { featuredata = {}, },
         },
         dynamics = {}, processes = {},
         rawdata = {}, features={},
      }
      k.resources = {
         unicodes = ttu,
         features = feat_dummy_vert,
         sequences = seq_dummy_vert,
      }
      k.descriptions = {}
      cache_chars[cid_name]  = { [655360] = k.characters }

      -- 縦書用字形
      tt, cidm = {}, {}
      local ttv = {}; k.ltj_vert_table = ttv
      for i = 0,kx[2] do cidm[i] = -1 end
      open_cmap_file(kx[1] .. "-V", increment, tonumber, entry)
      for i,v in pairs(tt) do
         ttv[i] =  cidmo[v.index] -- "unicode" of vertical variant
      end

      -- tounicode エントリ
      local cidp = {nil, nil}; tt, ttu, cidm = {}, {}, {}
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
      if k and k.characters and k.characters[46] then
        k.characters[46].width = math.floor(655360/14);
      end
      ltjb.save_cache("ltj-cid-auto-" .. string.lower(cid_name),
                      {version = cache_ver, k})
      k.shared.rawdata.resources=k.resources
      k.shared.rawdata.descriptions=k.descriptions
   end
end

--
local cidf_vert_processor
do
   local traverse_id, is_node = node.direct.traverse_id, node.is_node
   local to_direct = node.direct.todirect
   local id_glyph = node.id 'glyph'
   local getfont = node.direct.getfont
   local getchar = node.direct.getchar
   local setchar = node.direct.setchar
   local font_getfont = font.getfont
   cidf_vert_processor = {
      function (head, fnum)
         local fontdata = font_getfont(fnum)
         if head and luatexja.jfont.font_metric_table[fnum] and luatexja.jfont.font_metric_table[fnum].vert_activated then
            local vt = fontdata.ltj_vert_table
            local nh = is_node(head) and to_direct(head) or head
            for n in traverse_id(id_glyph, head) do
               if getfont(n)==fnum then
                 local c = getchar(n); setchar(n, vt[c] or c)
               end
            end
            return head, false
         end
      end
   }
end

local dummy_vht, dummy_vorg = {}, {}
setmetatable(dummy_vht, {__index = function () return 1 end } )
setmetatable(dummy_vorg, {__index = function () return 0.88 end } )
local function cid_cache_outdated(t) return t.version~=cache_ver end
local function read_cid_font()
   local dat = ltjb.load_cache("ltj-cid-auto-" .. string.lower(cid_name),
                               cid_cache_outdated)
   if dat then
      dat[1].shared.rawdata.resources=dat[1].resources
      dat[1].shared.rawdata.descriptions=dat[1].descriptions
      cidfont_data[cid_name] = dat[1]
      cache_chars[cid_name]  = { [655360] = cidfont_data[cid_name].characters }
   else
      -- Now we must create the virtual metrics from CMap.
      make_cid_font()
   end
   if cidfont_data[cid_name] then
      cidfont_data[cid_name].shared.processes = cidf_vert_processor
      cidfont_data[cid_name].resources.ltj_extra
        = { ind_to_uni = cidfont_data[cid_name].resources.unicodes,
            vheight = dummy_vht, vorigin = dummy_vorg }
      for i,v in pairs(cidfont_data[cid_name].characters) do
         if not v.width then v.width = 655360 end
         v.height, v.depth = 576716.8, 78643.2 -- optimized for jfm-ujis.lua
      end
      return cidfont_data[cid_name]
   else
      return nil
   end
end

-- High-level
local function prepare_cid_font(reg, ord)
   cid_reg, cid_order, cid_name, cid_supp = reg, ord, reg .. '-' .. ord
   return cidfont_data[cid_name] or read_cid_font()
end


local definers = fonts.definers
local function mk_rml(name, size, id)
   local specification = definers.analyze(name,size)
   --specification = definers.resolve(specification) (not needed)
   specification.detail = specification.detail or ''
   do
      local n = specification.name
      if n:sub(1,1)=="{" then n=n:sub(2) end
      if n:sub(-1)=="}" then  n=n:sub(1,-2) end
      specification.name=n
   end
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
   luatexja.rmlgbm.vert_addfunc(id, fontdata)

   -- other parameters
   do
      local parameters = {}
      for k, v in pairs(s.parameters) do  parameters[k] = v * scale end
      fontdata.parameters  = parameters; fontdata.size  = size; fontdata.resources  = s.resources
      cachedata.parameters = parameters; cachedata.size = size; cachedata.resources = s.resources
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
   identifiers[id] = cachedata

   return fontdata
end

local function font_callback(name, size, id, fallback)
   if name:sub(1,1)=="{" and name:sub(-1)=="}" then name = name:sub(2,-2) end
   local p = name:find(":") or 0
   if name:sub(1, p-1) == 'psft' then
      local s = "Adobe-Japan1-7"
      local basename = name:sub(p+1)
      local p = basename:find(":")
      local q = basename:find("/[BI][BI]?")
      if q and p and q<=p then
         basename = basename:gsub('/[BI][BI]?', '', 1)
         p = basename:find(":")
      end
      if p then
         local xname = basename:sub(p+1)
         p = 1
         while p do
            local q = xname:find(";", p+1) or xname:len()+1
            if xname:sub(p, p+3)=='cid=' and q>p+4 then
               s = xname:sub(p+4, q-1)
            end
            if xname:len()+1==q then p = nil else p = q + 1 end
         end
      end
      cid_reg, cid_order = string.match(s, "^(.-)%-(.-)%-(%d-)$")
      if not cid_reg then
         cid_reg, cid_order = string.match(s, "^(.-)%-(.-)$")
      end
      if not prepare_cid_font(cid_reg, cid_order) then
         ltjb.package_error('luatexja',
                            "bad cid key `" .. s .. "'",
                            "I couldn't find any non-embedded font information for the CID\n" ..
                            '`' .. s .. "'. For now, I'll use `Adobe-Japan1-6'.\n"..
                            'Please contact the LuaTeX-ja project team.')
         cid_name = "Adobe-Japan1"
      end
      return mk_rml(basename, size, id)
   else
      local fontdata=fallback(name, size, id)
      if type (fontdata) == "table" and fontdata.encodingbytes == 2 then
        luatexbase.call_callback ("luaotfload.patch_font", fontdata, name, id)
      else
        luatexbase.call_callback ("luaotfload.patch_font_unsafe", fontdata, name, id)
      end
      return fontdata
   end
end

luatexja.rmlgbm = {
   prepare_cid_font = prepare_cid_font,
   cidfont_data = cidfont_data,
   font_callback = font_callback,
   vert_addfunc = function () end, -- dummy, set in ltj-direction.lua
}

prepare_cid_font('Adobe', 'Japan1')
