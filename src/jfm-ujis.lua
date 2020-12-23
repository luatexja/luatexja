-- -*- coding: utf-8 -*-
-- jfm-ujis.lua: LuaTeX-ja 標準 JFM
-- based on upnmlminr-h.tfm (a metric in UTF/OTF package used by upTeX).

-- JIS X 4051:2004 では，行末の句読点や中点はベタなのでそれに従う
-- kanjiskip:    0pt plus .25zw minus 0pt
-- xkanjiskip: .25zw plus .25zw (or .0833zw) minus .125zw

local t = {
   version = 3,
   dir = 'yoko',
   zw = 1.0, zh = 1.0,
   kanjiskip =  { 0.0, 0.25, 0 },
   xkanjiskip = { 0.25, 0.25, .125 },
   [0] = {
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [2] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [3] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [4] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [6] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [007] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [107] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [207] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [8] = { 0, 0, 0, kanjiskip_shrink=1 },
      },
      kern = { [307] = 0 },	 
      round_threshold = 0.01,
   },

   [1] = { -- 開き括弧類
      chars = {
	 '‘', '“', '〈', '《', '「', '『', '【', '〔', '〖',
	 '〘', '〝', '（', '［', '｛', '｟'
      },
      align = 'right', left = 0.0, down = 0.0,
      width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
-- 3 のみ四分，あとは0
         [0] = { 0, 0, 0, kanjiskip_shrink=1 },
         [1] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [2] = { 0, 0, 0, kanjiskip_shrink=1, kanjiskip_stretch=1 },
	 [3] = { 0.25, 0.0, 0.25, priority=1 },
	 [4] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [5] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [105] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [205] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [305] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [405] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [6] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [007] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [107] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [207] = { 0, 0, 0, kanjiskip_shrink=1 },
         [8] = { 0, 0, 0, kanjiskip_shrink=1 },
      }
   },

   [2] = { -- 閉じ括弧類
      chars = {
	 '’', '”', '〉', '》', '」', '』', '】', '〕',
	 '〗', '〙', '〟', '）', '］', '｝', '｠', '、', '，*'
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
-- 3 は四分, 2, 4, 9 は0, あとは0.5
	 [0] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [1] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
         [2] = { 0, 0, 0, kanjiskip_shrink=1},
	 [3] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
         [4] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [5] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [105] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [205] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [305] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [405] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [6] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [007] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [107] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [207] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [8] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
      }
   },

   [3] = { -- 中点類
      chars = {'・', '：', '；', '·'},
      align = 'middle', left = 0.0, down = 0.0,
      width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
      --end_stretch = 0.25,
      glue = {
-- 3 のみ 0.5，あとは0.25
	 [0] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [1] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [2] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [3] = { 0.5 , 0.0, 0.5 , priority=1 },
	 [4] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [5] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [105] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [205] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [305] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [405] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [6] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [007] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [107] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [207] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [8] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
      }
   },

   [4] = { -- 句点類
      chars = {'。', '．'},
      align = 'left', left = 0.0, down = 0.0,
      width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
         -- 3 は.75, 2, 4 は0, あとは0.5
	 [0] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [1] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [3] = { 0.75, 0.0, 0.25, priority=1, ratio=1./3, kanjiskip_stretch=1 },
	 [5] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [105] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [205] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [305] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [405] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [6] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [007] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [107] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [207] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
	 [8] = { 0.5 , 0.0, 0.5, ratio=0, kanjiskip_stretch=1 },
      }
   },

   [5] = { -- 分離禁止文字
      chars = { '―', '‥', '…', '〳', '〴', '〵', },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [2] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [3] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [4] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [6] = { 0, 0, 0, kanjiskip_shrink=1 },
      },
      kern = {
	 [5] = 0.0, [105] = 0.0, [205] = 0.0, [305] = 0.0, [405] = 0.0,
      }
   },

   [105] = { -- 二分（二重）ダッシュ
      chars = { '゠', '–' },
      align = 'middle', left = 0.0, down = 0.0,
      width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [2] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [3] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [4] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [6] = { 0, 0, 0, kanjiskip_shrink=1 },
      },
      kern = {
	 [5] = 0.0, [105] = 0.0, [205] = 0.0, [305] = 0.0, [405] = 0.0,
      }
   },

   [205] = { -- em-dash
      chars = { 0x2014 },
      align = 'middle', left = 0.0, down = 0.0,
      width = 1, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [2] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [3] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [4] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [6] = { 0, 0, 0, kanjiskip_shrink=1 },
      },
      kern = {
	 [5] = 0.0, [105] = 0.0, [205] = 0.0, [305] = 0.0, [405] = 0.0,
      }
   },
   [305] = { -- two-em dash
      chars = { 0x2E3A },
      align = 'middle', left = 0.0, down = 0.0,
      width = 2, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [2] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [3] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [4] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [6] = { 0, 0, 0, kanjiskip_shrink=1 },
      },
      kern = {
	 [5] = 0.0, [105] = 0.0, [205] = 0.0, [305] = 0.0, [405] = 0.0,
      }
   },
   [405] = { -- three-em dash
      chars = { 0x2E3B },
      align = 'middle', left = 0.0, down = 0.0,
      width = 3, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [2] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [3] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [4] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [6] = { 0, 0, 0, kanjiskip_shrink=1 },
      },
      kern = {
	 [5] = 0.0, [105] = 0.0, [205] = 0.0, [305] = 0.0, [405] = 0.0,
      }
   },

   [6] = { -- 感嘆符・疑問符
      chars = { '？', '！', '‼', '⁇', '⁈', '⁉', },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
         [0] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [1] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [2] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [3] = { 0.75, 0.0, 0.25, priority=1, ratio=1 },
	 [4] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [6] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [007] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [107] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [207] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [8] = { 0, 0, 0, kanjiskip_shrink=1 },
      },
      kern = {
	 [5] = 0.0, [105] = 0.0, [205] = 0.0, [305] = 0.0, [405] = 0.0,
      }
   },

   [007] = { -- 半角カナ，その他半角CID
      chars = {
	 '｡', '｢', '｣', '､', '･', 'ｦ', 'ｧ', 'ｨ', 'ｩ',
	 'ｪ', 'ｫ', 'ｬ', 'ｭ', 'ｮ', 'ｯ', 'ｰ', 'ｱ', 'ｲ',
	 'ｳ', 'ｴ', 'ｵ', 'ｶ', 'ｷ', 'ｸ', 'ｹ', 'ｺ', 'ｻ',
	 'ｼ', 'ｽ', 'ｾ', 'ｿ', 'ﾀ', 'ﾁ', 'ﾂ', 'ﾃ', 'ﾄ',
	 'ﾅ', 'ﾆ', 'ﾇ', 'ﾈ', 'ﾉ', 'ﾊ', 'ﾋ', 'ﾌ', 'ﾍ',
	 'ﾎ', 'ﾏ', 'ﾐ', 'ﾑ', 'ﾒ', 'ﾓ', 'ﾔ', 'ﾕ', 'ﾖ',
	 'ﾗ', 'ﾘ', 'ﾙ', 'ﾚ', 'ﾛ', 'ﾜ', 'ﾝ', 'ﾞ', 'ﾟ',
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 0.5, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [2] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [3] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [4] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [6] = { 0, 0, 0, kanjiskip_shrink=1 },
         [8] = { 0, 0, 0, kanjiskip_shrink=1 },
      },
      kern = { [307] = 0 },	 
   },

   [107] = { -- 1/3 角
      chars = {},
      align = 'left', left = 0.0, down = 0.0,
      width = 1/3, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [2] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [3] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [4] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [6] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [107] = { 0, 0, 0, kanjiskip_shrink=1 },
         [8] = { 0, 0, 0, kanjiskip_shrink=1 },
      }
   },

   [207] = { -- 1/4 角
      chars = {},
      align = 'left', left = 0.0, down = 0.0,
      width = 0.25, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [2] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [3] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [4] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [6] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [207] = { 0, 0, 0, kanjiskip_shrink=1 },
         [8] = { 0, 0, 0, kanjiskip_shrink=1 },
      }
   },

   [307] = { -- 合成用（半）濁点
      chars = { 0x3099, 0x309A },
      align = 'right', left = 0.0, down = 0.0,
      width = 0, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [2] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [3] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [4] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [6] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [207] = { 0, 0, 0, kanjiskip_shrink=1 },
         [8] = { 0, 0, 0, kanjiskip_shrink=1 },
      }
   },

   [8] = { -- 罫線類．
      chars = {
	 '─', '━', '│', '┃', '┄', '┅', '┆', '┇',
	 '┈', '┉', '┊', '┋', '┌', '┍', '┎', '┏',
	 '┐', '┑', '┒', '┓', '└', '┕', '┖', '┗',
	 '┘', '┙', '┚', '┛', '├', '┝', '┞', '┟',
	 '┠', '┡', '┢', '┣', '┤', '┥', '┦', '┧',
	 '┨', '┩', '┪', '┫', '┬', '┭', '┮', '┯',
	 '┰', '┱', '┲', '┳', '┴', '┵', '┶', '┷',
	 '┸', '┹', '┺', '┻', '┼', '┽', '┾', '┿',
	 '╀', '╁', '╂', '╃', '╄', '╅', '╆', '╇',
	 '╈', '╉', '╊', '╋', '╌', '╍', '╎', '╏',
	 '═', '║', '╒', '╓', '╔', '╕', '╖', '╗',
	 '╘', '╙', '╚', '╛', '╜', '╝', '╞', '╟',
	 '╠', '╡', '╢', '╣', '╤', '╥', '╦', '╧',
	 '╨', '╩', '╪', '╫', '╬', '╭', '╮', '╯',
	 '╰', '╱', '╲', '╳', '╴', '╵', '╶', '╷',
	 '╸', '╹', '╺', '╻', '╼', '╽', '╾', '╿',
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = 0.88, depth = 0.12, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5, ratio=1, kanjiskip_stretch=1 },
	 [2] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [3] = { 0.25, 0.0, 0.25, priority=1, ratio=1 },
	 [4] = { 0, 0, 0, kanjiskip_shrink=1 },
	 [6] = { 0, 0, 0, kanjiskip_shrink=1 },
      },
      kern = {
	 [8] = 0.0
      }
   },

   [99] = { -- box末尾
      chars = {'boxbdd', 'glue'},
   },
   [199] = { -- box末尾
      chars = {'parbdd'},
   },
}

local ht = t[007].chars
for i=231,632 do ht[#ht+1] = 'AJ1-' .. tostring(i) end
for i=8718,8719 do ht[#ht+1] = 'AJ1-' .. tostring(i) end
for i=12063,12087 do ht[#ht+1] = 'AJ1-' .. tostring(i) end
local ht = t[107].chars
for i=9758,9778 do ht[#ht+1] = 'AJ1-' .. tostring(i) end
local ht = t[207].chars
for i=9738,9757 do ht[#ht+1] = 'AJ1-' .. tostring(i) end

t[100]=table.fastcopy(t[0])
t[100].chars={'nox_alchar'}
for i,v in pairs(t) do
  if i~=6 and type(i)=='number' and type(v)=='table' then -- 感嘆符以外
    if v.glue and v.glue[0] then v.glue[100] = v.glue[0] end
    if v.kern and v.kern[0] then v.kern[100] = v.kern[0] end
  end
end
t[200]=table.fastcopy(t[0])
t[200].chars={ 0x3031,0x3032 }
t[200].height=1.38; t[200].depth=0.62
for i,v in pairs(t) do
  if type(i)=='number' and type(v)=='table' then
    if v.glue and v.glue[0] then v.glue[200] = v.glue[0] end
    if v.kern and v.kern[0] then v.kern[200] = v.kern[0] end
  end
end

local jf = luatexja.jfont.jfm_feature
if jf and jf.beginpar_middledot_zw==true then
    t[199].kern = { [3] = 0.25 }
end

luatexja.jfont.define_jfm(t)
