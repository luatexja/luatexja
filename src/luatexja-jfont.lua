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

function ltj.search_metric(key)
   for i,v in ipairs(ltj.metrics) do 
      if v.name==key then return i end
   end
   return nil
end

function ltj.load_jfont_metric()
  if ltj.jfmfname=='' then 
     ltj.error('no JFM specified', 
	       {[1]='To load and define a Japanese font, the name of JFM must be specified.',
		[2]="The JFM 'ujis' will be  used for now."})
     ltj.jfmfname='ujis'
  end
  jfm.name=ltj.jfmfname .. ':' .. ltj.jfmvar;
  local i = ltj.search_metric(jfm.name)
  local t = {}
  if i then  return i end
  jfm.char_type={}; jfm.glue={}; jfm.kern={}
  ltj.loadlua('jfm-' .. ltj.jfmfname .. '.lua');
  if jfm.dir~='yoko' then
     ltj.error("jfm.dir must be 'yoko'", {}); return nil
   end
   t.name=jfm.name
   t.dir=jfm.dir; t.zw=jfm.zw; t.zh=jfm.zh
   t.char_type=jfm.char_type
   t.glue=jfm.glue; t.kern=jfm.kern
   table.insert(ltj.metrics,t)
   return #ltj.metrics
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

-- extract ltj.jfmfname and ltj.jfmvar
function ltj.extract_metric(name)
   local basename=name
   local tmp = utf.sub(basename, 1, 5)
   ltj.jfmfname = ''
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
	 ltj.jfmfname = utf.sub(basename,p+4,q-1)
      elseif utf.sub(basename,p,p+6)=='jfmvar=' and q>p+6 then
	 ltj.jfmvar = utf.sub(basename,p+7,q-1)
      end
      if utf.len(basename)+1==q then p=nil else p=q+1 end
   end
   return
end
