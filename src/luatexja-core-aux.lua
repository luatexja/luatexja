
--  和文文字と満たす unicode の範囲（適当）
function ltj.is_ucs_in_japanese_char(c)
   if (c>=0x2000)and(c<=0x27FF) then return true
   elseif (c>=0x2900)and(c<=0x29FF) then return true
   elseif (c>=0x3000)and(c<=0x30FF) then return true
   elseif (c>=0x31F0)and(c<=0x4DBF) then return true
   elseif (c>=0x4E00)and(c<=0x9FFF) then return true
   elseif (c>=0xF900)and(c<=0xFAFF) then return true
   elseif (c>=0xFF00)and(c<=0xFFEF) then return true
   elseif (c>=0x20000)and(c<=0xDFFFF) then return true
   else return false
   end
end


-- gb: 前側の和文文字 b 由来の glue/kern (maybe nil)
-- ga: 後側の和文文字 a 由来の glue/kern (maybe nil)
-- 両者から，b と a の間に入る glue/kern を計算する

function ltj.calc_between_two_jchar_aux_large(gb,ga)
   if not gb then 
      return ga
   else
      if not ga then return gb end
      local k = node.type(gb.id) .. node.type(ga.id)
      if k == 'glueglue' then 
	 -- 両方とも glue．大きい方をとる
	 gb.spec.width   = math.max(gb.spec.width,ga.spec.width)
	 gb.spec.stretch = math.max(gb.spec.stretch,ga.spec.shrink)
	 gb.spec.shrink  = math.min(gb.spec.shrink,ga.spec.shrink)
	 return gb
      elseif k == 'kernkern' then
	 -- 両方とも kern．
	 gb.kern = math.max(gb.kern,ga.kern)
	 return gb
      elseif k == 'kernglue' then 
	 -- gb: kern, ga: glue
	 ga.spec.width   = math.max(gb.kern,ga.spec.width)
	 ga.spec.stretch = math.max(ga.spec.stretch,0)
	 ga.spec.shrink  = math.min(ga.spec.shrink,0)
	 return ga
      else
	 -- gb: glue, ga: kern
	 gb.spec.width   = math.max(ga.kern,gb.spec.width)
	 gb.spec.stretch = math.max(gb.spec.stretch,0)
	 gb.spec.shrink  = math.min(gb.spec.shrink,0)
	 return gb
      end
   end
end
function ltj.calc_between_two_jchar_aux_small(gb,ga)
   if not gb then 
      return ga
   else
      if not ga then return gb end
      local k = node.type(gb.id) .. node.type(ga.id)
      if k == 'glueglue' then 
	 -- 両方とも glue．大きい方をとる
	 gb.spec.width   = math.min(gb.spec.width,ga.spec.width)
	 gb.spec.stretch = math.min(gb.spec.stretch,ga.spec.shrink)
	 gb.spec.shrink  = math.max(gb.spec.shrink,ga.spec.shrink)
	 return gb
      elseif k == 'kernkern' then
	 -- 両方とも kern．
	 gb.kern = math.min(gb.kern,ga.kern)
	 return gb
      elseif k == 'kernglue' then 
	 -- gb: kern, ga: glue
	 ga.spec.width   = math.min(gb.kern,ga.spec.width)
	 ga.spec.stretch = math.min(ga.spec.stretch,0)
	 ga.spec.shrink  = math.max(ga.spec.shrink,0)
	 return ga
      else
	 -- gb: glue, ga: kern
	 gb.spec.width   = math.min(ga.kern,gb.spec.width)
	 gb.spec.stretch = math.min(gb.spec.stretch,0)
	 gb.spec.shrink  = math.max(gb.spec.shrink,0)
	 return gb
      end
   end
end
function ltj.calc_between_two_jchar_aux_average(gb,ga)
   if not gb then 
      return ga
   else
      if not ga then return gb end
      local k = node.type(gb.id) .. node.type(ga.id)
      if k == 'glueglue' then 
	 -- 両方とも glue．平均をとる
	 gb.spec.width   = tex.round((gb.spec.width+ga.spec.width)/2)
	 gb.spec.stretch = tex.round((gb.spec.stretch+ga.spec.shrink)/2)
	 gb.spec.shrink  = tex.round((gb.spec.shrink+ga.spec.shrink)/2)
	 return gb
      elseif k == 'kernkern' then
	 -- 両方とも kern．平均をとる
	 gb.kern = tex.round((gb.kern+ga.kern)/2)
	 return gb
      elseif k == 'kernglue' then 
	 -- gb: kern, ga: glue
	 ga.spec.width   = tex.round((gb.kern+ga.spec.width)/2)
	 ga.spec.stretch = tex.round(ga.spec.stretch/2)
	 ga.spec.shrink  = tex.round(ga.spec.shrink/2)
	 return ga
      else
	 -- gb: glue, ga: kern
	 gb.spec.width   = tex.round((ga.kern+gb.spec.width)/2)
	 gb.spec.stretch = tex.round(gb.spec.stretch/2)
	 gb.spec.shrink  = tex.round(gb.spec.shrink/2)
	 return gb
      end
   end
end
function ltj.calc_between_two_jchar_aux_both(gb,ga)
   if not gb then 
      return ga
   else
      if not ga then return gb end
      local k = node.type(gb.id) .. node.type(ga.id)
      if k == 'glueglue' then 
	 gb.spec.width   = tex.round((gb.spec.width+ga.spec.width))
	 gb.spec.stretch = tex.round((gb.spec.stretch+ga.spec.shrink))
	 gb.spec.shrink  = tex.round((gb.spec.shrink+ga.spec.shrink))
	 return gb
      elseif k == 'kernkern' then
	 gb.kern = tex.round((gb.kern+ga.kern))
	 return gb
      elseif k == 'kernglue' then 
	 -- gb: kern, ga: glue
	 ga.spec.width   = tex.round((gb.kern+ga.spec.width))
	 return ga
      else
	 -- gb: glue, ga: kern
	 gb.spec.width   = tex.round((ga.kern+gb.spec.width))
	 return gb
      end
   end
end

ltj.calc_between_two_jchar_aux=ltj.calc_between_two_jchar_aux_average
