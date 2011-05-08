ltj.define_jfm {
   dir = 'yoko',
   zw = 1.0, zh = 1.0,
   kanjiskip = { 0.0, 0.04, 0.05 },
   xkanjiskip = { 0.25, 0.083, 0.083 },

   [0] = {
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
   },
   [1] = {
      chars = { 'あ' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      glue = { [3] = { 1.41, 0, 0} },
      kern = { [8] = -1.41 , [2] = 2.0, [99] = 1.21 }
   },
   [11] = {
      chars = { 'い' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      glue = { [3] = { 1.41, 0, 0} },
      kern = { [2] = 2.0, }
   },
   [21] = {
      chars = { 'う' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      glue = { [3] = { 1.41, 0, 0}, [99] ={ 1.73, 0, 0}  },
      kern = { [8] = -1.41 , [2] = 2.0, }
   },
   [31] = {
      chars = { 'え' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      glue = { [3] = { 1.41, 0, 0} },
      kern = { [2] = 2.0, [99] = 1.73}
   },
   [41] = {
      chars = { 'お' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      kern = { [8] = -1.41 , [2] = 2.0}
   },

   [2] = {
      chars = { 'ア' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0
   },
   [3] = {
      chars = { 'ウ' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0
   },
   [99] = {
      chars = { 'jcharbdd' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      glue = { [11] = { 1.41, 0, 0} },
      kern = { [21] = 2.0, }
   },
   [8] = {
      chars = { 'lineend' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
   }
}
