luatexja.jfont.define_jfm {
   dir = 'yoko',
   zw = 1.0, zh = 1.0,

   [0] = {
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.88*0.16,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5  },
	 [3] = { 0.25, 0.0, 0.25 }
      }
   },

   [1] = { -- 開き括弧類
      chars = {
	 0x2018, 0x201C, 0x3008, 0x300A, 0x300C, 0x300E, 0x3010, 0x3014, 0x3016, 
	 0x3018, 0x301D, 0xFF08, 0xFF3B, 0xFF5B, 0xFF5F
      },
      align = 'right', left = 0.0, down = 0.0,
      width = 0.5, height = 0.88, depth = 0.12, italic=0.88*0.16,
      glue = {
	 [3] = { 0.25, 0.0, 0.25 }
      }
   },

   [2] = { -- 閉じ括弧類
      chars = {
	 0x2019, 0x201D, 0x3001, 0x3009, 0x300B, 0x300D, 0x300F, 0x3011, 0x3015, 
	 0x3017, 0x3019, 0x301F, 0xFF09, 0xFF0C, 0xFF3D, 0xFF5D, 0xFF60
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 0.5, height = 0.88, depth = 0.12, italic=0.88*0.16,
      glue = {
	 [0] = { 0.5 , 0.0, 0.5  },
	 [1] = { 0.5 , 0.0, 0.5  },
	 [3] = { 0.25, 0.0, 0.25 },
	 [5] = { 0.5 , 0.0, 0.5  },
	 [7] = { 0.5 , 0.0, 0.5  }
      }
   },

   [3] = { -- 中点類
      chars = {0x30FB, 0xFF1A, 0xFF1B},
      align = 'middle', left = 0.0, down = 0.0,
      width = 0.5, height = 0.88, depth = 0.12, italic=0.88*0.16,
      glue = {
	 [0] = { 0.25, 0.0, 0.25 },
	 [1] = { 0.25, 0.0, 0.25 },
	 [2] = { 0.25, 0.0, 0.25 },
	 [3] = { 0.5 , 0.0, 0.5  },
	 [4] = { 0.25, 0.0, 0.25 },
	 [5] = { 0.25, 0.0, 0.25 },
	 [7] = { 0.25, 0.0, 0.25 }
      }
   },

   [4] = { -- 句点類
      chars = {0x3002, 0xFF0E},
      align = 'left', left = 0.0, down = 0.0,
      width = 0.5, height = 0.88, depth = 0.12, italic=0.88*0.16,
      glue = {
	 [0] = { 0.5 , 0.0, 0.0  },
	 [1] = { 0.5 , 0.0, 0.0  },
	 [3] = { 0.75, 0.0, 0.25 },
	 [5] = { 0.5 , 0.0, 0.0  },
	 [7] = { 0.5 , 0.0, 0.0  }
      }
   },

   [5] = { -- ダッシュ
      chars = { 0x2015, 0x2025, 0x2026 },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.88*0.16,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5  },
	 [3] = { 0.25, 0.0, 0.25 }
      },
      kern = {
	 [5] = 0.0
      }
   },

   [6] = { -- box末尾
      chars = {'boxbdd'},
   },

   [7] = { -- 半角カナ
      chars = {
	 0xFF61, 0xFF62, 0xFF63, 0xFF64, 0xFF65, 0xFF66, 0xFF67, 0xFF68, 0xFF69, 
	 0xFF6A, 0xFF6B, 0xFF6C, 0xFF6D, 0xFF6E, 0xFF6F, 0xFF70, 0xFF71, 0xFF72, 
	 0xFF73, 0xFF74, 0xFF75, 0xFF76, 0xFF77, 0xFF78, 0xFF79, 0xFF7A, 0xFF7B, 
	 0xFF7C, 0xFF7D, 0xFF7E, 0xFF7F, 0xFF80, 0xFF81, 0xFF82, 0xFF83, 0xFF84, 
	 0xFF85, 0xFF86, 0xFF87, 0xFF88, 0xFF89, 0xFF8A, 0xFF8B, 0xFF8C, 0xFF8D, 
	 0xFF8E, 0xFF8F, 0xFF90, 0xFF91, 0xFF92, 0xFF93, 0xFF94, 0xFF95, 0xFF96, 
	 0xFF97, 0xFF98, 0xFF99, 0xFF9A, 0xFF9B, 0xFF9C, 0xFF9D, 0xFF9E, 0xFF9F
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 0.5, height = 0.88, depth = 0.12, italic=0.88*0.16,      
      glue = {
	 [1] = { 0.5 , 0.0, 0.5  },
	 [3] = { 0.25, 0.0, 0.25 }
      }
   },
}