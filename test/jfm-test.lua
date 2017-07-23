luatexja.jfont.define_jfm {
   version = 3,
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
      glue = { [3] = { 1.41, 0, 0}, [399] = {1.25, 0.43, 0.87} },
      kern = { [8] = -1.41 , [2] = 2.0, 
        [99] = 1.21, [599] = 1.22, [699] = 1.23, [799] = 1.24 }
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
      glue = { [3] = { 1.41, 0, 0}, 
        [99] ={ 1.73, 0, 0}, [599] ={ 1.74, 0, 0}, [699] ={ 1.75, 0, 0}, [799] ={ 1.77, 0, 0}  },
      kern = { [8] = -1.41 , [2] = 2.0, }
   },
   [31] = {
      chars = { 'え' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      glue = { [3] = { 1.41, 0, 0} },
      kern = { [2] = 2.0, [99] = 1.73, [599] = 1.74, [699] = 1.75, [799] = 1.76, }
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
   [4] = {
      chars = { 'エ' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      glue = { [199] = { 0.78, 0, 0} },
   },
   [99] = {
      chars = { 'jcharbdd' },
      glue = { [11] = { 1.41, 0, 0} },
      kern = { [21] = 2.0, }
   },
   [599] = {
      chars = { 'alchar' },
      glue = { [11] = { 1.42, 0, 0}, [1] = {0.51, 0, 0 } },
      kern = { [21] = 2.01, }
   },
   [699] = {
      chars = { 'nox_alchar' },
      glue = { [11] = { 1.43, 0, 0}, [1] = {0.52, 0, 0 } },
      kern = { [21] = 2.02, }
   },
   [799] = {
      chars = { 'glue' },
      glue = { [11] = { 1.44, 0, 0}, [1] = {0.53, 0, 0 } },
      kern = { [21] = 2.03, }
   },
   [199] = {
      chars = { 'boxbdd' },
      glue = { [51] = { 1.03, 0, 0} , [1] = { 0.94, 0.23, 0.45 }},
   },
   [299] = {
      chars = { 'parbdd' },
      glue = { [51] = { 0.68, 0.02, 0.04} },
   },
   [399] = {
      chars = { -1 }, -- math
      glue = { [0] = { 0.68, 0.02, 0.04} },
   },
   [8] = {
      chars = { 'lineend' },
   }
}
