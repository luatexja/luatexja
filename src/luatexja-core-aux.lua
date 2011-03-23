
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

function ltj.calc_between_two_jchar_aux(gb,ga)
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
      elseif k == 'kernkern' then
	 -- 両方とも kern．平均をとる
	 gb.kern = tex.round((gb.kern+ga.kern)/2)
      elseif k == 'kernglue' then 
	 -- gb: kern, ga: glue
	 return ga
      else
	 -- gb: glue, ga: kern
	 return gb
      end
   end
end
