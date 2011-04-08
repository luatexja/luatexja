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

function ltj.loadjfontmetric()
   if string.len(jfm.name)==0 then
      ltj.error("the key of font metric is null"); return nil
   elseif ltj.search_metric(jfm.name) then
      ltj.error("the metric '" .. jfm.name .. "' is already loaded"); return nil
   end
   if jfm.dir~='yoko' then
      ltj.error("jfm.dir must be 'yoko'"); return nil
   end
   local t={}
   t.name=jfm.name
   t.dir=jfm.dir
   t.zw=jfm.zw
   t.zh=jfm.zh
   t.char_type=jfm.char_type
   t.glue=jfm.glue
   t.kern=jfm.kern
   table.insert(ltj.metrics,t)
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

function ltj.jfontdefX(b)
  local t = token.get_next()
  ltj.cstemp=token.csname_name(t)
  ltj.mettemp=''
  tex.sprint('\\expandafter\\font\\csname ' .. ltj.cstemp .. '\\endcsname')
end
function ltj.jfontdefY() -- for horizontal font
   local j=ltj.search_metric(ltj.mettemp)
   if not j then
      ltj.error("metric named '" .. ltj.mettemp .. "' didn't loaded")
      return
   end
   local fn=font.id(ltj.cstemp)
   local f = font.fonts[fn]
   ltj.font_metric_table[fn]={}
   ltj.font_metric_table[fn].jfm=j; ltj.font_metric_table[fn].size=f.size
   tex.sprint('\\protected\\expandafter\\def\\csname ' .. ltj.cstemp .. '\\endcsname' 
	      .. '{\\csname luatexja@curjfnt\\endcsname=' .. fn
	      .. ' \\zw=' .. tex.round(f.size*ltj.metrics[j].zw) .. 'sp' 
	      .. '\\zh=' .. tex.round(f.size*ltj.metrics[j].zh) .. 'sp\\relax}')
end


local dr_orig = fonts.define.read
function fonts.define.read(name, size, id)
   ltj.mettemp = ltj.determine_metric(name)
   -- In hthe present imple., we don't remove "jfm=..." from name.
   local fontdata = dr_orig(name, size, id)
   return fontdata
end

function ltj.determine_metric(name)
   local basename=name
   local tmp = utf.sub(basename, 1, 5)
   if tmp == 'file:' or tmp == 'name:' or tmp == 'psft:' then
      basename = utf.sub(basename, 6)
   end

   local p = utf.find(basename, ":")
   if p then 
      basename = utf.sub(basename, p+1)
   else return ''
   end

   p=1
   while p do
      local q= utf.find(basename, ";",p+1) or utf.len(basename)+1
      if utf.sub(basename,p,p+3)=='jfm=' and q>p+4 then
	 return utf.sub(basename,p+4,q-1)
      end
      if utf.len(basename)+1==q then p=nil else p=q+1 end
   end
   return ''
end
