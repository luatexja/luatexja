luatexja.jfont.define_jfm {
   dir = 'yoko',
   zw = 1.0, zh = 1.0,

   [0] = {
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
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
      width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
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
      width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
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
      width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
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
      width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
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
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
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
	 0xFF97, 0xFF98, 0xFF99, 0xFF9A, 0xFF9B, 0xFF9C, 0xFF9D, 0xFF9E, 0xFF9F,
	 "AJ1-516", "AJ1-517", "AJ1-518", "AJ1-519", "AJ1-520", "AJ1-521", "AJ1-522", 
	 "AJ1-523", "AJ1-524", "AJ1-525", "AJ1-526", "AJ1-527", "AJ1-528", "AJ1-529", 
	 "AJ1-530", "AJ1-531", "AJ1-532", "AJ1-533", "AJ1-534", "AJ1-535", "AJ1-536", 
	 "AJ1-537", "AJ1-538", "AJ1-539", "AJ1-540", "AJ1-541", "AJ1-542", "AJ1-543", 
	 "AJ1-544", "AJ1-545", "AJ1-546", "AJ1-547", "AJ1-548", "AJ1-549", "AJ1-550", 
	 "AJ1-551", "AJ1-552", "AJ1-553", "AJ1-554", "AJ1-555", "AJ1-556", "AJ1-557", 
	 "AJ1-558", "AJ1-559", "AJ1-560", "AJ1-561", "AJ1-562", "AJ1-563", "AJ1-564", 
	 "AJ1-565", "AJ1-566", "AJ1-567", "AJ1-568", "AJ1-569", "AJ1-570", "AJ1-571", 
	 "AJ1-572", "AJ1-573", "AJ1-574", "AJ1-575", "AJ1-576", "AJ1-577", "AJ1-578", 
	 "AJ1-579", "AJ1-580", "AJ1-581", "AJ1-582", "AJ1-583", "AJ1-584", "AJ1-585", 
	 "AJ1-586", "AJ1-587", "AJ1-588", "AJ1-589", "AJ1-590", "AJ1-591", "AJ1-592", 
	 "AJ1-593", "AJ1-594", "AJ1-595", "AJ1-596", "AJ1-597", "AJ1-598",
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 0.5, height = 0.88, depth = 0.12, italic=0.0,      
      glue = {
	 [1] = { 0.5 , 0.0, 0.5  },
	 [3] = { 0.25, 0.0, 0.25 }
      }
   },
}