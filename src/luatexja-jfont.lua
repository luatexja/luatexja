local has_attr = node.has_attribute
local jfmfname

--====== METRIC
jfm={}; jfm.char_type={}; jfm.glue={}; jfm.kern={}

function jfm.define_char_type(t,lt) 
   if not jfm.char_type[t] then jfm.char_type[t]={} end
   jfm.char_type[t].chars=lt 
end
function jfm.define_type_dim(t,l,x,w,h,d,i)
   if not jfm.char_type[t] then jfm.char_type[t]={} end
   jfm.char_type[t].width=w; jfm.char_type[t].height=h;
   jfm.char_type[t].depth=d; jfm.char_type[t].italic=i; 
   jfm.char_type[t].left=l; jfm.char_type[t].down=x
end
function jfm.define_glue(b,a,w,st,sh)
   local j=b*0x800+a
   if not jfm.glue[j] then jfm.glue[j]={} end
   jfm.glue[j].width=w; jfm.glue[j].stretch=st; 
   jfm.glue[j].shrink=sh
end
function jfm.define_kern(b,a,w)
   local j=b*0x800+a
   if not jfm.kern[j] then jfm.kern[j]=w end
end

-- procedures for \loadjfontmetric
ltj.metrics={} -- this table stores all metric informations
ltj.font_metric_table={}

local function search_metric(key)
   for i,v in ipairs(ltj.metrics) do 
      if v.name==key then return i end
   end
   return nil
end

-- return nil iff ltj.metrics[ind] is a bad metric
local function consistency_check(ind)
   local t = ltj.metrics[ind]
   local r = ind
   if t.dir~='yoko' then -- TODO: tate?
      r=nil
   elseif type(t.zw)~='number' or type(t.zh)~='number' then 
      r=nil -- .zw, .zh must be present
   else
      local lbt = ltj.find_char_type('lindend',ind)
      if lbt~=0 and t.char_type[lbt].chars~={'linebdd'} then
	 r=nil -- 'linebdd' must be isolated char_type
      end
   end
   if not r then ltj.metrics[ind] = nil end
   return r
end

function ltj.load_jfont_metric()
   if jfmfname=='' then 
      ltj.error('no JFM specified', 
		{[1]='To load and define a Japanese font, the name of JFM must be specified.',
		 [2]="The JFM 'ujis' will be  used for now."})
      jfmfname='ujis'
   end
   jfm.name=jfmfname .. ':' .. ltj.jfmvar
   local i = search_metric(jfm.name)
   local t = {}
   if i then  return i end
   jfm.char_type={}; jfm.glue={}; jfm.kern={}
   ltj.loadlua('jfm-' .. jfmfname .. '.lua')
   t.name=jfm.name
   t.dir=jfm.dir; t.zw=jfm.zw; t.zh=jfm.zh
   t.char_type=jfm.char_type
   t.glue=jfm.glue; t.kern=jfm.kern
   table.insert(ltj.metrics,t)
   return consistency_check(#ltj.metrics)
end

function ltj.find_char_type(c,m)
-- c: character code, m
   if not ltj.metrics[m] then return 0 end
   for i, v in pairs(ltj.metrics[m].char_type) do
      if i~=0 then
        for j,w in pairs(v.chars) do
           if w==c then return i end
        end
      end
   end
   return 0
end


--====== \setjfont\CS={...:...;jfm=metric;...}

function ltj.jfontdefX(g)
  local t = token.get_next()
  ltj.cstemp=token.csname_name(t)
  if g then ltj.is_global = '\\global' else ltj.is_global = '' end
  tex.sprint('\\expandafter\\font\\csname ' .. ltj.cstemp .. '\\endcsname')
end

function ltj.jfontdefY() -- for horizontal font
   local j=ltj.load_jfont_metric()
   local fn=font.id(ltj.cstemp)
   local f = font.fonts[fn]
   if not j then 
     ltj.error("bad JFM '" .. jfmfname .. "'",
               {[1]='The JFM file you specified is not valid JFM file.',
                [2]='Defining Japanese font is cancelled.'})
     tex.sprint(ltj.is_global .. '\\expandafter\\let\\csname '
		.. ltj.cstemp .. '\\endcsname=\\relax')
     return 
   end
   ltj.font_metric_table[fn]={}
   ltj.font_metric_table[fn].jfm=j; ltj.font_metric_table[fn].size=f.size
   tex.sprint(ltj.is_global .. '\\protected\\expandafter\\def\\csname '
              .. ltj.cstemp .. '\\endcsname'
              .. '{\\csname luatexja@curjfnt\\endcsname=' .. fn
              .. ' \\zw=' .. tex.round(f.size*ltj.metrics[j].zw) .. 'sp'
              .. '\\zh=' .. tex.round(f.size*ltj.metrics[j].zh) .. 'sp\\relax}')
end

local dr_orig = fonts.define.read
function fonts.define.read(name, size, id)
   ltj.extract_metric(name)
   -- In the present imple., we don't remove "jfm=..." from name.
   local fontdata = dr_orig(name, size, id)
   return fontdata
end

-- extract jfmfname and ltj.jfmvar
function ltj.extract_metric(name)
   local basename=name
   local tmp = utf.sub(basename, 1, 5)
   jfmfname = ''
   ltj.jfmvar = ''
   if tmp == 'file:' or tmp == 'name:' or tmp == 'psft:' then
      basename = utf.sub(basename, 6)
   end

   local p = utf.find(basename, ":")
   if p then 
      basename = utf.sub(basename, p+1)
   else return 
   end

   p=1
   while p do
      local q= utf.find(basename, ";",p+1) or utf.len(basename)+1
      if utf.sub(basename,p,p+3)=='jfm=' and q>p+4 then
	 jfmfname = utf.sub(basename,p+4,q-1)
      elseif utf.sub(basename,p,p+6)=='jfmvar=' and q>p+6 then
	 ltj.jfmvar = utf.sub(basename,p+7,q-1)
      end
      if utf.len(basename)+1==q then p=nil else p=q+1 end
   end
   return
end


--====== Range of Japanese characters.
-- jcr_table_main[chr_code] = index
-- index : internal 0, 1, 2, ..., 216               0: 'other'
--         external    1  2       216, (out of range): 'other'

-- init: 
local ucs_out = 0x110000
local jcr_table_main = {}
local jcr_cjk = 0
local jcr_noncjk = 1

for i=0x80,0xFF do
   jcr_table_main[i]=1
end
for i=0x100,ucs_out-1 do
   jcr_table_main[i]=0
end

function ltj.def_char_range(b,e,ind) -- ind: external range number
   if ind<0 or ind>216 then 
      ltj.error('Invalid range number (' .. ind .. '), should be in the range 1..216.',
		{}); return
   end
   for i=math.max(0x80,b),math.min(ucs_out-1,e) do
      jcr_table_main[i]=ind
   end
end

local function get_char_jcrcode(p) -- for internal use
   local i
   local c = p.char
   if c<0x80 then return jcr_noncjk else i=jcr_table_main[c] end
   return math.floor(has_attr(p,
         luatexbase.attributes['luatexja@kcat'..math.floor(i/31)])
         /math.pow(2, i%31))%2
end

function ltj.get_char_jcrnumber(c) -- return the (external) range number
   if c<0x80 or c>=ucs_out then return -1
   else 
      local i = jcr_table_main[c] or 0
      if i==0 then return 217 else return i end
   end
end

function ltj.get_jcr_setting(i) -- i: internal range number
   return math.floor(tex.getattribute(luatexbase.attributes['luatexja@kcat'..math.floor(i/31)])
         /math.pow(2, i%31))%2
end

--  和文文字と認識する unicode の範囲
function ltj.is_ucs_in_japanese_char(p)
   return (get_char_jcrcode(p)~=jcr_noncjk) 
end

function ltj.set_jchar_range(g, i) -- i: external range number
   if i==0 then return 
   else
      local kc
      if i>0 then kc=0 else kc=1; i=-i end
      if i>216 then i=0 end
      local attr = luatexbase.attributes['luatexja@kcat'..math.floor(i/31)]
      local a = tex.getattribute(attr)
      local k = math.pow(2, i%31)
      tex.setattribute(g,attr,(math.floor(a/k/2)*2+kc)*k+a%k)
   end
end