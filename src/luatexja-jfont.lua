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
local threshold = 0x100 -- must be >=0x100
-- below threshold: kcat_table_main[chr_code] = index
-- above threshold: kcat_table_range = 
--   { [1] = {b_1, b_2, ...},
--     [2] = {i_1, i_2, ...} }
-- ( Characters b_i<=chr_code <b_{i+1} have the index i_i )
-- kcat_table_index = index1, index2, ...

-- init
local ucs_out = 0x110000
local kcat_table_main = {}
kcat_table_range = { [1] = {threshold,ucs_out}, [2] = {0,-1} }
kcat_table_index = { [0] = 'other' ,
			   [1] = 'iso8859-1'}

local kc_kanji = 0
local kc_kana = 1
local kc_letter = 2
local kc_punct = 3
local kc_noncjk = 4

for i=0x80,0xFF do
   kcat_table_main[i]=1
end
for i=0x100,threshold-1 do
   kcat_table_main[i]=0
end

local function add_jchar_range(b,e,ind)
   -- We assume that e>=b
   if b<threshold then
      for i=math.max(0x80,b),math.min(threshold-1,e) do
	 kcat_table_main[i]=ind
      end
      if e<threshold then return true else b=threshold end
   end
   local insp
   for i,v in ipairs(kcat_table_range[1]) do
      if v>e then 
	 insp = i-1; break
      end
   end
   if kcat_table_range[1][insp]>b or kcat_table_range[2][insp]>1 then
      ltj.error("Bad character range",{}); return nil -- error
   end
   if kcat_table_range[1][insp]<b  then 
   -- now [insp]¢« <b .. b .. [insp+1]¢« >e
      table.insert(kcat_table_range[1],insp+1,b)
      table.insert(kcat_table_range[2], insp+1, kcat_table_range[2][insp])
      insp=insp+1
   end
   -- [insp]¢« =b .. e .. [insp+1]¢« >e
   table.insert(kcat_table_range[1], insp+1,e+1)
   table.insert(kcat_table_range[2], insp+1, kcat_table_range[2][insp])
   kcat_table_range[2][insp]=ind
end

function ltj.def_jchar_range(b,e,name) 
   local ind = #kcat_table_index+1
   for i,v in pairs(kcat_table_index) do
      if v==name then ind=i; break  end
   end
   if ind>=50 then 
      ltj.error("No room for new character range",{}); return -- error
   end
   if ind == #kcat_table_index+1 then
      table.insert(kcat_table_index, name)
      print('New char range: ' .. name, ind) 
   end
   add_jchar_range(b,e,ind)
end

local function get_char_kcatcode(p)
   local i
   local c = p.char
   if c<0x80 then return kc_noncjk
   elseif c<threshold then i=kcat_table_main[c] 
   else
      for j,v in ipairs(kcat_table_range[1]) do
	 if v>c then 
	    i = kcat_table_range[2][j-1]; break
	 end
      end
   end
   return math.floor(has_attr(p,
         luatexbase.attributes['luatexja@kcat'..math.floor(i/10)])
         /math.pow(8, i%10))%8
end

--  ÏÂÊ¸Ê¸»ú¤ÈÇ§¼±¤¹¤ë unicode ¤ÎÈÏ°Ï
function ltj.is_ucs_in_japanese_char(p)
   return (get_char_kcatcode(p)~=kc_noncjk) 
end

function ltj.set_jchar_range(g, name,kc)
   local ind = 0
   for i,v in pairs(kcat_table_index) do
      if v==name then ind=i; break  end
   end
   local attr = luatexbase.attributes['luatexja@kcat'..math.floor(ind/10)]
   local a = tex.getattribute(attr)
   local k = math.pow(8, ind%10)
   tex.setattribute(g,attr,(math.floor(a/k/8)*8+kc)*k+a%k)
end