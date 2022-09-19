-- -*- coding: utf-8 -*-
-- jfm-jis.lua: JISフォントメトリック互換
-- Besed on ujis.tfm (a counterpart of jis.tfm for upTeX).
-- * Do not confuse with jfm-ujis.lua.

local vscale = 0.916443 / 0.962216
local vht = 0.777588 / 0.962216
local vdp = 0.138855 / 0.962216
luatexja.jfont.define_jfm {
   dir = 'yoko',
   zw = 1.0, zh = vscale,

   [0] = {
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5  },
	 [3] = { 0.25, 0.0, 0.25 }
      }
   },

   [1] = { -- 開き括弧類
      chars = {
	 '‘', '“', '〈', '《', '「', '『', '【', '〔', '〖',
	 '〘', '〝', '（', '［', '｛', '｟'
      },
      align = 'right', left = 0.0, down = 0.0,
      width = 0.5, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [3] = { 0.25, 0.0, 0.25 }
      }
   },

   [2] = { -- 閉じ括弧類
      chars = {
	 '’', '”', '、', '〉', '》', '」', '』', '】', '〕',
	 '〗', '〙', '〟', '）', '，', '］', '｝', '｠'
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 0.5, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [0] = { 0.5 , 0.0, 0.5  },
	 [1] = { 0.5 , 0.0, 0.5  },
	 [3] = { 0.25, 0.0, 0.25 },
	 [5] = { 0.5 , 0.0, 0.5  },
      }
   },

   [3] = { -- 中点類
      chars = {'・', '：', '；'},
      align = 'middle', left = 0.0, down = 0.0,
      width = 0.5, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [0] = { 0.25, 0.0, 0.25 },
	 [1] = { 0.25, 0.0, 0.25 },
	 [2] = { 0.25, 0.0, 0.25 },
	 [3] = { 0.5 , 0.0, 0.5  },
	 [4] = { 0.25, 0.0, 0.25 },
	 [5] = { 0.25, 0.0, 0.25 },
      }
   },

   [4] = { -- 句点類
      chars = {'。', '．'},
      align = 'left', left = 0.0, down = 0.0,
      width = 0.5, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [0] = { 0.5 , 0.0, 0.0  },
	 [1] = { 0.5 , 0.0, 0.0  },
	 [3] = { 0.75, 0.0, 0.25 },
	 [5] = { 0.5 , 0.0, 0.0  },
      }
   },

   [5] = { -- ダッシュ
      chars = { '―', '‥', '…' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5  },
	 [3] = { 0.25, 0.0, 0.25 }
      },
      kern = {
	 [5] = 0.0
      }
   },

   [99] = { -- box末尾
      chars = {'boxbdd', 'parbdd'},
   },

}