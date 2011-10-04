luatexja.jfont.define_jfm {
   dir = 'yoko',
   zw = 1.0, zh = 1.0,
   kanjiskip = { 0.1, 0.04, 0.05 },
   xkanjiskip = { 0.31, 0.045, 0.057 },

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
   [51] = {
      chars = { 'か' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      kern = { [199] = 0.85 },
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
      glue = { [11] = { 1.41, 0, 0} },
      kern = { [21] = 2.0, }
   },
   [199] = {
      chars = { 'boxbdd' },
      glue = { [51] = { 1.03, 0, 0} , [1] = { 0.94, 0.23, 0.45 }},
   },
   [8] = {
      chars = { 'lineend' },
   }
}
