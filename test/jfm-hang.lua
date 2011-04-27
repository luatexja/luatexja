
jfm.dir = 'yoko'
-- 'yoko'

jfm.zw= 1.0; jfm.zh = 1.0
-- amount of ``1zw'' and ``1zh'' (these units are used in pTeX)


-- character type
-- jfm.define_char_type(<type>, <letters>)
jfm.define_char_type(1, {
  0x3042
}) 
jfm.define_char_type(2, {
  0x3044
}) 
jfm.define_char_type(3, {
  0x3048
}) 
jfm.define_char_type(4, {
  0x304A
}) 
jfm.define_char_type(8, {'lineend'})


jfm.define_type_dim(0, 0.0 , 0.0 , 1.0 , 0.88, 0.12, 0.0)
jfm.define_type_dim(1, 0.0 , 0.0 , 1.0 , 0.88, 0.12, 0.0)
jfm.define_type_dim(2, 0.0 , 0.0 , 1.0 , 0.88, 0.12, 0.0)
jfm.define_type_dim(3, 0.0 , 0.0 , 1.0 , 0.88, 0.12, 0.0)
jfm.define_type_dim(4, 0.0 , 0.0 , 1.0 , 0.88, 0.12, 0.50)

jfm.define_kern(1,8, -0.5)
jfm.define_glue(2,3,  0.25, 0.25, 0.25)
jfm.define_glue(1,3,  0.25, 0.0, 0.25)