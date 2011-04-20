-- A sample of Japanese font metric for pluatex
-- The unit of <height>, <depth>: 
-- The unit of other dimension: the design size

jfm.dir = 'yoko'
-- 'yoko'

jfm.zw= 1.0; jfm.zh = 1.0
-- amount of ``1zw'' and ``1zh'' (these units are used in pTeX)


-- character type
-- jfm.define_char_type(<type>, <letters>)
jfm.define_char_type(1, {
  0x2018, 0x201C, 0x3008, 0x300A, 0x300C, 0x300E, 0x3010, 0x3014, 0x3016, 
  0x3018, 0x301D, 0xFF08, 0xFF3B, 0xFF5B, 0xFF5F
		     }) -- 開き括弧類
jfm.define_char_type(2, {
  0x2019, 0x201D, 0x3001, 0x3009, 0x300B, 0x300D, 0x300F, 0x3011, 0x3015, 
  0x3017, 0x3019, 0x301F, 0xFF09, 0xFF0C, 0xFF3D, 0xFF5D, 0xFF60
		     }) -- 閉じ括弧類
jfm.define_char_type(3, {0x30FB, 0xFF1A, 0xFF1B}) -- 中点類
jfm.define_char_type(4, {0x3002, 0xFF0E}) -- 句点類
jfm.define_char_type(5, {0x2015, 0x2025, 0x2026}) -- ダッシュ
jfm.define_char_type(6, {'boxbdd'})
jfm.define_char_type(7, {
  0xFF61, 0xFF62, 0xFF63, 0xFF64, 0xFF65, 0xFF66, 0xFF67, 0xFF68, 0xFF69, 
  0xFF6A, 0xFF6B, 0xFF6C, 0xFF6D, 0xFF6E, 0xFF6F, 0xFF70, 0xFF71, 0xFF72, 
  0xFF73, 0xFF74, 0xFF75, 0xFF76, 0xFF77, 0xFF78, 0xFF79, 0xFF7A, 0xFF7B, 
  0xFF7C, 0xFF7D, 0xFF7E, 0xFF7F, 0xFF80, 0xFF81, 0xFF82, 0xFF83, 0xFF84, 
  0xFF85, 0xFF86, 0xFF87, 0xFF88, 0xFF89, 0xFF8A, 0xFF8B, 0xFF8C, 0xFF8D, 
  0xFF8E, 0xFF8F, 0xFF90, 0xFF91, 0xFF92, 0xFF93, 0xFF94, 0xFF95, 0xFF96, 
  0xFF97, 0xFF98, 0xFF99, 0xFF9A, 0xFF9B, 0xFF9C, 0xFF9D, 0xFF9E, 0xFF9F
}) -- 半角カナ


-- 'boxbdd' matches 
--       o the beginning of paragraphs and hboxes,
--       o the ending of paragraphs and hboxes,
--       o just after the hbox created by \parindent.

-- 'jcharbdd' matches the boundary between two Japanese characters whose metrics (or sizes) 
--            are different.

-- 'diffmet' matches the boundary between a Japanese character 
--           and a material which is not a Japanese character.

-- 'lineend' matches the ending of a line.

-- dimension
-- jfm.define_type_dim(<type>, <left>, <down>, <width>, 
--                     <height>, <depth>, <italic correction>)
jfm.define_type_dim(0, 0.0 , 0.0 , 1.0 , 0.88, 0.12, 0.0)
jfm.define_type_dim(1, 0.5 , 0.0 , 0.5 , 0.88, 0.12, 0.0)
jfm.define_type_dim(2, 0.0 , 0.0 , 0.5 , 0.88, 0.12, 0.0)
jfm.define_type_dim(3, 0.25, 0.0 , 0.5 , 0.88, 0.12, 0.0)
jfm.define_type_dim(4, 0.0 , 0.0 , 0.5 , 0.88, 0.12, 0.0)
jfm.define_type_dim(5, 0.0 , 0.0 , 1.0 , 0.88, 0.12, 0.0)
-- jfm.define_type_dim(6, 0.0 , 0.0 , 1.0 , 0.88, 0.12, 0.0): does not needed
jfm.define_type_dim(7, 0.0 , 0.0 , 0.5 , 0.88, 0.12, 0.0)

-- glue/kern
-- jfm.define_glue(<btype>, <atype>, <width>, <stretch>, <shrink>)
-- jfm.define_kern(<btype>, <atype>, <width>)
jfm.define_glue(0,1, 0.5 , 0.0, 0.5 )
jfm.define_glue(7,1, 0.5 , 0.0, 0.5 )
jfm.define_glue(0,3, 0.25, 0.0, 0.25)
jfm.define_glue(7,3, 0.25, 0.0, 0.25)
jfm.define_glue(1,3, 0.25, 0.0, 0.25)
jfm.define_glue(2,0, 0.5 , 0.0, 0.5 )
jfm.define_glue(2,7, 0.5 , 0.0, 0.5 )
jfm.define_glue(2,1, 0.5 , 0.0, 0.5 )
jfm.define_glue(2,3, 0.25, 0.0, 0.25)
jfm.define_glue(2,5, 0.5 , 0.0, 0.5 )
jfm.define_glue(3,0, 0.25, 0.0, 0.25)
jfm.define_glue(3,7, 0.25, 0.0, 0.25)
jfm.define_glue(3,1, 0.25, 0.0, 0.25)
jfm.define_glue(3,2, 0.25, 0.0, 0.25)
jfm.define_glue(3,3, 0.5 , 0.0, 0.5 )
jfm.define_glue(3,4, 0.25, 0.0, 0.25)
jfm.define_glue(3,5, 0.25, 0.0, 0.25)
jfm.define_glue(4,0, 0.5 , 0.0, 0.0 )
jfm.define_glue(4,7, 0.5 , 0.0, 0.0 )
jfm.define_glue(4,1, 0.5 , 0.0, 0.0 )
jfm.define_glue(4,3, 0.75, 0.0, 0.25)
jfm.define_glue(4,5, 0.5 , 0.0, 0.0 )
jfm.define_glue(5,1, 0.5 , 0.0, 0.5 )
jfm.define_glue(5,3, 0.25, 0.0, 0.25)
jfm.define_kern(5,5, 0.0)