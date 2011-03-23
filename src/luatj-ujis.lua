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
		     })
jfm.define_char_type(2, {
  0x2019, 0x201D, 0x3001, 0x3009, 0x300B, 0x300D, 0x300F, 0x3011, 0x3015, 
  0x3017, 0x3019, 0x301F, 0xFF09, 0xFF0C, 0xFF3D, 0xFF5D, 0xFF60
		     })
jfm.define_char_type(3, {0x30FB, 0xFF1A, 0xFF1B})
jfm.define_char_type(4, {0x3002, 0xFF0E})
jfm.define_char_type(5, {0x2015, 0x2025, 0x2026})
jfm.define_char_type(6, {'boxbdd'})

-- 'boxbdd' matches 
--       o the beginning of paragraphs and hboxes
--       o the ending of paragraphs and hboxes
--       o just after the hbox created by \parindent

-- 'jcharbdd' matches the boundary between two Japanese characters whose metrics (or sizes) 
--            are different.

-- 'diffmet' matches the boundary between a Japanese character 
--           and a material which is not a Japanese character.

-- dimension
-- jfm.define_type_dim(<type>, <left>, <width>, <height>, <depth>, <italic correction>)
jfm.define_type_dim(0, 0.0 , 1.0 , 0.88, 0.12, 0.0)
jfm.define_type_dim(1, 0.5 , 0.5 , 0.88, 0.12, 0.0)
jfm.define_type_dim(2, 0.0 , 0.5 , 0.88, 0.12, 0.0)
jfm.define_type_dim(3, 0.25, 0.5 , 0.88, 0.12, 0.0)
jfm.define_type_dim(4, 0.0 , 0.5 , 0.88, 0.12, 0.0)
jfm.define_type_dim(5, 0.0 , 1.0 , 0.88, 0.12, 0.0)
-- jfm.define_type_dim(6, 0.0 , 1.0 , 0.88, 0.12, 0.0): does not needed

-- glue/kern
-- jfm.define_glue(<btype>, <atype>, <width>, <stretch>, <shrink>)
-- jfm.define_kern(<btype>, <atype>, <width>)
jfm.define_glue(0,1, 0.5 , 0.0, 0.5 )
jfm.define_glue(0,3, 0.25, 0.0, 0.25)
jfm.define_glue(1,3, 0.25, 0.0, 0.25)
jfm.define_glue(2,0, 0.5 , 0.0, 0.5 )
jfm.define_glue(2,1, 0.5 , 0.0, 0.5 )
jfm.define_glue(2,3, 0.25, 0.0, 0.25)
jfm.define_glue(2,5, 0.5 , 0.0, 0.5 )
jfm.define_glue(3,0, 0.25, 0.0, 0.25)
jfm.define_glue(3,1, 0.25, 0.0, 0.25)
jfm.define_glue(3,2, 0.25, 0.0, 0.25)
jfm.define_glue(3,3, 0.5 , 0.0, 0.5 )
jfm.define_glue(3,4, 0.25, 0.0, 0.25)
jfm.define_glue(3,5, 0.25, 0.0, 0.25)
jfm.define_glue(4,0, 0.5 , 0.0, 0.0 )
jfm.define_glue(4,1, 0.5 , 0.0, 0.0 )
jfm.define_glue(4,3, 0.75, 0.0, 0.25)
jfm.define_glue(4,5, 0.5 , 0.0, 0.0 )
jfm.define_glue(5,1, 0.5 , 0.0, 0.5 )
jfm.define_glue(5,3, 0.25, 0.0, 0.25)
jfm.define_kern(5,5, 0.0)