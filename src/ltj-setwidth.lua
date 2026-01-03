--
-- ltj-setwidth.lua
--

luatexja.load_module 'base';      local ltjb = luatexja.base
luatexja.load_module 'stack';     local ltjs = luatexja.stack
luatexja.load_module 'jfont';     local ltjf = luatexja.jfont
luatexja.load_module 'direction'; local ltjd = luatexja.direction
luatexja.load_module 'lotf_aux';  local ltju = luatexja.lotf_aux

local setfield = node.direct.setfield
local getfield = node.direct.getfield
local getid = node.direct.getid
local getfont = node.direct.getfont
local getlist = node.direct.getlist
local getchar = node.direct.getchar
local getsubtype = node.direct.getsubtype
local getwidth = node.direct.getwidth
local getshift = node.direct.getshift
local getoffsets = node.direct.getoffsets
local getheight = node.direct.getheight
local getdepth = node.direct.getdepth
local getwhd = node.direct.getwhd

local setwhd = node.direct.setwhd
local setchar = node.direct.setchar
local setnext = node.direct.setnext
local setdir = node.direct.setdir
local setkern = node.direct.setkern
local setshift = node.direct.setshift
local setoffsets = node.direct.setoffsets
local setheight = node.direct.setheight
local setdepth = node.direct.setdepth
local setlist = node.direct.setlist

local node_traverse = node.direct.traverse
local node_copy = node.direct.copy
local node_remove = node.direct.remove
local node_tail = node.direct.tail
local node_next = node.direct.getnext
local get_attr = node.direct.get_attribute
local set_attr = node.direct.set_attribute
local node_insert_before = node.direct.insert_before
local node_insert_after = node.direct.insert_after
local round = tex.round
local node_new = luatexja.dnode_new

local id_glyph  = node.id 'glyph'
local id_kern   = node.id 'kern'
local id_glue   = node.id 'glue'
local id_hlist  = node.id 'hlist'
local id_vlist  = node.id 'vlist'
local id_rule   = node.id 'rule'
local id_math   = node.id 'math'
local id_whatsit= node.id 'whatsit'
local sid_save   = node.subtype 'pdf_save'
local sid_restore = node.subtype 'pdf_restore'
local sid_matrix  = node.subtype 'pdf_setmatrix'
local dir_tate = luatexja.dir_table.dir_tate

local attr_yablshift = luatexbase.attributes['ltj@yablshift']
local attr_ykblshift = luatexbase.attributes['ltj@ykblshift']
local attr_tkblshift = luatexbase.attributes['ltj@tkblshift']
local attr_icflag = luatexbase.attributes['ltj@icflag']
local attr_vert_ori = luatexbase.attributes['ltj@vert@ori']

local ltjf_font_extra_info = ltjf.font_extra_info
local ltjs_orig_char_table = ltjs.orig_char_table

local PACKED       = luatexja.icflag_table.PACKED
local PROCESSED    = luatexja.icflag_table.PROCESSED

local get_pr_begin_flag
do
   local PROCESSED_BEGIN_FLAG = luatexja.icflag_table.PROCESSED_BEGIN_FLAG
   local floor = math.floor
   get_pr_begin_flag = function (p)
      local i = get_attr(p, attr_icflag) or 0
      return i - i%PROCESSED_BEGIN_FLAG
   end
end


local ltjw = {} --export
luatexja.setwidth = ltjw

luatexbase.create_callback("luatexja.set_width", "data",
                           function (fstable, fmtable, char_data)
                              return fstable
                           end)
local call_callback = luatexbase.call_callback

local fshift =  { down = 0, left = 0 }

local min, max, floor, abs = math.min, math.max, math.floor, math.abs

local rule_subtype = (status.luatex_version>=85) and 3 or 0

-- 和文文字の位置補正（横）
local function capsule_glyph_yoko(p, met, char_data, head, dir)
   if not char_data then return node_next(p), head, p end
   fshift.down = char_data.down; fshift.left = char_data.left
   fshift = call_callback("luatexja.set_width", fshift, met, char_data)
   local kbl = get_attr(p, attr_ykblshift) or 0
   --
   -- f*: whd specified in JFM
   local pwidth, pheight,pdepth = getwhd(p)
   local fwidth = char_data.width or pwidth
   local fheight= char_data.height or pheight
   local fdepth = char_data.depth or pdepth
   if pwidth==fwidth then
      -- 補正後glyph node は ht: p.height - kbl - down, dp: p.depth + min(0, kbl+down) を持つ
      -- 設定されるべき寸法: ht: fheight - kbl, dp: fdepth + kbl
      local ht_diff = fheight + fshift.down - pheight
      local dp_diff = fdepth  + kbl - pdepth - min(kbl + fshift.down, 0)
      if ht_diff == 0 and dp_diff ==0 then -- offset only
         set_attr(p, attr_icflag, PROCESSED)
         local xo, yo = getoffsets(p)
         setoffsets(p, xo - fshift.left, yo - kbl - fshift.down)
         return node_next(p), head, p
      elseif ht_diff >= 0 and dp_diff >=0 then -- rule
         local box = node_new(id_rule, rule_subtype, p)
         local xo, yo = getoffsets(p)
         setoffsets(p, xo, yo - kbl - fshift.down)
         setwhd(box, 0, fheight - kbl, fdepth + kbl)
         setdir(box, dir)
         set_attr(box, attr_icflag, PACKED)
         set_attr(p, attr_icflag, PROCESSED)
         head = p and node_insert_before(head, p, box)
            or node_insert_after(head, node_tail(head), box)
         return node_next(p), head, p, box
      end
   end

   local q; head, q = node_remove(head, p)
   if pwidth > fwidth then
      if char_data.round_threshold then
         local frac = pwidth / fwidth
         local quot = floor(frac+0.5)
         if abs(frac-quot) <char_data.round_threshold then fwidth = fwidth * quot end
      end
   end
   local xo, yo = getoffsets(p)
   setoffsets(p, xo + char_data.align*(fwidth-pwidth) - fshift.left,
              yo - fshift.down);
   setnext(p, nil)
   local box = node_new(id_hlist, nil, p)
   setwhd(box, fwidth, fheight, fdepth)
   setlist(box, p); setshift(box, kbl)
   setdir(box, dir)
   set_attr(box, attr_icflag, PACKED)
   head = q and node_insert_before(head, q, box)
      or node_insert_after(head, node_tail(head), box)
   return q, head, box
end

luatexja.setwidth.capsule_glyph_yoko = capsule_glyph_yoko

-- 和文文字の位置補正（縦）
-- UTR#50 で R もしくは Tr と指定されているが，縦組用グリフがないもの
local function capsule_glyph_tate_rot(p, met, char_data, head, dir, asc)
   fshift.down = char_data.down; fshift.left = char_data.left
   fshift = call_callback("luatexja.set_width", fshift, met, char_data)
   local kbl = get_attr(p, attr_tkblshift) or 0
   -- f*: whd specified in JFM
   local pwidth, pheight, pdepth = getwhd(p)
   local fwidth = char_data.width or pwidth
   local fheight= char_data.height or pheight
   local fdepth = char_data.depth or pdepth
   local q
   head, q = node_remove(head, p)
   local xo, yo = getoffsets(p)
   setoffsets(p, xo + char_data.align*(fwidth-pwidth) - fshift.left,
              yo - fshift.down - asc);
   setnext(p, nil)
   local box = node_new(id_hlist, nil, p)
   setwhd(box, fwidth, fheight, fdepth)
   setlist(box, p); setshift(box, kbl)
   setdir(box, dir)
   set_attr(box, attr_icflag, PACKED)
   head = q and node_insert_before(head, q, box)
      or node_insert_after(head, node_tail(head), box)
   return q, head, box
end

local font_getfont = font.getfont
local get_ascender, get_descender = ltju.get_ascender, ltju.get_descender
local loop_over_feat = ltju.loop_over_feat
local capsule_glyph_tate
do
local specified_feature = ltju.specified_feature
local function get_valt(pf, fn, pc)
   local k = 0
   if specified_feature(pf, fn) then
      loop_over_feat(pf, fn,
         function(i,t)
            if i==pc and type(t)=='table' then
               if #t==4 then k = k + t[4] end
            end
         end,
         false, 'gpos_single')
   end
   return k
end
local setwidth = node.direct.setwidth
local capsule_glyph_tate = function (p, met, char_data, head, dir)
   if not char_data then return node_next(p), head end
   local fwidth = char_data.width; local vadv, ascender, ascender_def
   local pwidth, pheight, pdepth = getwhd(p)
   local pf, pc = getfont(p), getchar(p)
   local embed
   do
      local f = font_getfont(pf)
      local feir = ltjf_font_extra_info[pf]
      if met.rotation and met.vert_activated then
          local pco = ltjs_orig_char_table[p] or pc
          local r = met.rotation[pco]
          local l = f.properties and f.properties.language
          r = (r==true) or (type(r)=="table" and not r[l])
          if r then
            r = met.rotation[pc]
            r = (r==true) or (type(r)=="table" and not r[l])
          end
          if r and (get_attr(p, attr_vert_ori) or 0)<=0 then
            return capsule_glyph_tate_rot(p, met, char_data, head, dir,
              0.5*(get_ascender(pf)-get_descender(pf)))
          end
      end
      embed = (f.filename~="")
      vadv, ascender = feir.vheight[pc]*met.size, feir.vorigin[pc]*met.size
      ascender_def = feir.vorigin[-1]*met.size
   end
   local xo, yo = getoffsets(p); local corr_adv = 0
   do -- special treatment for 'vpal'/'vhal/ feature
       local k = get_valt(pf, 'vpal', pc) + get_valt(pf, 'vhal', pc)
       if k~=0 then
           local pft = font_getfont(pf); corr_adv = k/pft.units*pft.size
           vadv = vadv + corr_adv
       end
   end
   fwidth = fwidth or vadv
   if vadv>fwidth and char_data.round_threshold then
      local frac = vadv / fwidth
      local quot = floor(frac+0.5)
      if abs(frac-quot) <char_data.round_threshold then fwidth = fwidth * quot end
   end
   fshift.down = char_data.down; fshift.left = char_data.left
   fshift = call_callback("luatexja.set_width", fshift, met, char_data)
   local y_shift = xo + (get_attr(p,attr_tkblshift) or 0)
   local q
   head, q = node_remove(head, p)

   local box = node_new(id_hlist, nil, p)
   setwhd(box, fwidth, char_data.height or 0, char_data.depth or 0); setshift(box, y_shift)
   setdir(box, dir)
   --print(string.format('"%s"(U+%04X) ', utf.char(pc),pc),
   --  luatexja.print_scaled(fwidth or 0), luatexja.print_scaled(pwidth or 0),
   --  luatexja.print_scaled(pheight or 0), luatexja.print_scaled(pdepth or 0))
   --print('',
   --  luatexja.print_scaled(vadv or -1), luatexja.print_scaled(ascender or -1),
   --  luatexja.print_scaled(ascender_def or -1)
--)

   ---- I don't know why these values work...
   local cwa, ad = char_data.align*(fwidth-vadv) - fshift.left, (ascender - ascender_def)
   setoffsets(p, 0, (embed and (.5*pwidth) or 0) - fshift.down)
   local k2 = node_new(id_kern, 1) 
   setkern(k2, -pheight + ((yo+corr_adv<0) and 0 or yo + 2*corr_adv) + cwa + ad - (0.88*met.size - ascender_def) )
   set_attr(k2, attr_icflag, round( -ascender + pheight + cwa - yo - corr_adv + 2*ad))
   local k3 = node_new(id_kern, 1); 
   setkern(k3, -met.size + fwidth - (embed and pwidth or 0) + ascender + pdepth - cwa + yo +corr_adv - 2*ad)
   setlist(box, k2); setnext(k2, p); setnext(p, k3); setnext(k3, nil)
   ----
   --print('', luatexja.print_scaled(cwa), luatexja.print_scaled(yo), luatexja.print_scaled(corr_adv))
   -- "PACKED" hbox のうち，リストが kern->glyph->kern のはこの種類だけ

   set_attr(box, attr_icflag, PACKED)
   head = q and node_insert_before(head, q, box)
      or node_insert_after(head, node_tail(head), box)
   return q, head, box
end
luatexja.setwidth.capsule_glyph_tate = capsule_glyph_tate
end

do
local font_getfont, famfont = font.getfont, node.family_font
local cap_math_aux = {
  [-1]=function() return 1 end, [0]=function() return 1 end,
  [1]=function()
     local sf, tf = famfont(2,1), famfont(2,0)
     return font_getfont(sf).size/font_getfont(tf).size
  end,
  [2]=function()
     local ssf, tf = famfont(2,2), famfont(2,0)
     return font_getfont(ssf).size/font_getfont(tf).size
  end
}
setmetatable(cap_math_aux, {__index=function(t,k) return t[2] end})
local function capsule_glyph_math(p, met, char_data, sty)
   if not char_data then return nil end
   local fwidth, pwidth = char_data.width, getwidth(p)
   fwidth = fwidth or pwidth
   fshift.down = char_data.down; fshift.left = char_data.left
   fshift = call_callback("luatexja.set_width", fshift, met, char_data)
   local fheight, fdepth = char_data.height, char_data.depth
   local y_shift = - getfield(p, 'yoffset') 
     + cap_math_aux[sty]()*
       ((get_attr(p,attr_ykblshift) or 0) - (get_attr(p,attr_yablshift) or 0))
   setfield(p, 'yoffset', -fshift.down)
   setfield(p, 'xoffset', getfield(p, 'xoffset') + char_data.align*(fwidth-pwidth) - fshift.left)
   local box = node_new(id_hlist, nil, p);
   setwhd(box, fwidth, fheight, fdepth)
   setlist(box, p); setshift(box, y_shift)
   setdir(box, tex.mathdir)
   set_attr(box, attr_icflag, PACKED)
   return box
end
luatexja.setwidth.capsule_glyph_math = capsule_glyph_math
end

-- 数式の位置補正
function luatexja.setwidth.apply_ashift_math(head, last, attr_ablshift)
   for p, pid in node_traverse(head) do
      if p==last then
         return
      elseif (get_attr(p, attr_icflag) or 0) ~= PROCESSED then
         if pid==id_hlist or pid==id_vlist then
            setshift(p, getshift(p) +  (get_attr(p,attr_ablshift) or 0))
         elseif pid==id_rule then
            local v = get_attr(p,attr_ablshift) or 0
            setheight(p, getheight(p)-v); setdepth(p, getdepth(p)+v)
            set_attr(p, attr_icflag, PROCESSED)
         elseif pid==id_glyph then
            -- 欧文文字; 和文文字は pid == id_hlist の場合で処理される
            -- (see conv_jchar_to_hbox_A in ltj-math.lua)
            setfield(p, 'yoffset',
                     getfield(p, 'yoffset') - (get_attr(p,attr_ablshift) or 0))
         end
         set_attr(p, attr_icflag, PROCESSED)
      end
   end
end

-- discretionary の位置補正
do
   local attr_yablshift = luatexbase.attributes['ltj@yablshift']
   local attr_tablshift = luatexbase.attributes['ltj@tablshift']
   local attr_ablshift
   local disc, tex_dir
   local traverse_glyph = node.direct.traverse_glyph
   local function ashift_disc_inner(field)
      local head = getfield(disc, field)
      if not head then return end
      local y_adjust, node_depth, adj_depth = 0, 0, 0
      for lp in traverse_glyph(head) do
         y_adjust = get_attr(lp,attr_ablshift) or 0
         local ld = getdepth(lp)
         node_depth = max(ld + min(y_adjust, 0), node_depth)
         adj_depth = (y_adjust>0) and max(ld + y_adjust, adj_depth) or adj_depth
         setfield(lp, 'yoffset', getfield(lp, 'yoffset') - y_adjust)
      end
      if adj_depth>node_depth then
         local r = node_new(id_rule,rule_subtype, head)
         setwhd(r, 0, 0, adj_depth); setdir(r, tex_dir)
         set_attr(r, attr_icflag, PROCESSED)
         if field=='post' then
            node_insert_after(head, head, r)
         else
            setfield(disc, field, (node_insert_before(head, head, r)))
         end
      end
   end
   function luatexja.setwidth.apply_ashift_disc(d, is_dir_tate, dir)
      attr_ablshift = is_dir_tate and attr_tablshift or attr_yablshift
      disc, tex_dir = d, dir
      ashift_disc_inner 'pre'
      ashift_disc_inner 'post'
      ashift_disc_inner 'replace'
   end
end
