--
-- src/ltj-direction.lua
--

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('stack');     local ltjs = luatexja.stack
luatexja.load_module('rmlgbm');    local ltjr = luatexja.rmlgbm
luatexja.direction = {}

local attr_dir = luatexbase.attributes['ltj@dir']
local attr_icflag = luatexbase.attributes['ltj@icflag']

local cat_lp = luatexbase.catcodetables['latex-package']
local Dnode = node.direct or node
local nullfunc = function (n) return n end
local to_node = (Dnode ~= node) and Dnode.tonode or nullfunc
local to_direct = (Dnode ~= node) and Dnode.todirect or nullfunc
local has_attr = Dnode.has_attribute
local set_attr = Dnode.set_attribute
local insert_before = Dnode.insert_before
local insert_after = Dnode.insert_after
local getid = (Dnode ~= node) and Dnode.getid or function(n) return n.id end
local getsubtype = (Dnode ~= node) and Dnode.getsubtype or function(n) return n.subtype end
local getlist = (Dnode ~= node) and Dnode.getlist or function(n) return n.head end
local setfield = (Dnode ~= node) and Dnode.setfield or function(n, i, c) n[i] = c end
local getfield = (Dnode ~= node) and Dnode.getfield or function(n, i) return n[i] end
local node_new = Dnode.new
local node_tail = Dnode.tail
local node_free = Dnode.free
local node_remove = Dnode.remove
local node_next = (Dnode ~= node) and Dnode.getnext or node.next
local traverse = Dnode.traverse
local traverse_id = Dnode.traverse_id
local start_time_measure, stop_time_measure 
   = ltjb.start_time_measure, ltjb.stop_time_measure
local abs = math.abs

local id_kern = node.id('kern')
local id_hlist = node.id('hlist')
local id_vlist = node.id('vlist')
local id_whatsit = node.id('whatsit')
local sid_save = node.subtype('pdf_save')
local sid_restore = node.subtype('pdf_restore')
local sid_matrix = node.subtype('pdf_setmatrix')
local sid_user = node.subtype('user_defined')

local tex_nest = tex.nest
local tex_getcount = tex.getcount
local tex_set_attr = tex.setattribute
local PROCESSED    = luatexja.icflag_table.PROCESSED
local PROCESSED_BEGIN_FLAG = luatexja.icflag_table.PROCESSED_BEGIN_FLAG
local PACKED       = luatexja.icflag_table.PACKED
local STCK = luatexja.userid_table.STCK
local DIR  = luatexja.userid_table.DIR
local dir_tate = luatexja.dir_table.dir_tate
local dir_yoko = luatexja.dir_table.dir_yoko
local dir_dtou = luatexja.dir_table.dir_dtou
local dir_utod = luatexja.dir_table.dir_utod
local dir_node_auto   = luatexja.dir_table.dir_node_auto
local dir_node_manual = luatexja.dir_table.dir_node_manual

local page_direction
--
local function adjust_badness(hd)
   if not node_next(hd) and getid(hd)==id_whatsit and getsubtype(hd)==sid_user
   and getfield(hd, 'user_id')==DIR then
      -- avoid double whatsit
      luatexja.global_temp=tex.globaldefs; tex.globaldefs=0
      luatexja.hbadness_temp=tex.hbadness; tex.hbadness=10000
      luatexja.vbadness_temp=tex.vbadness; tex.vbadness=10000
   else
      luatexja.global_temp = nil
      luatexja.hbadness_temp=nil
      luatexja.vbadness_temp=nil
   end
end

local get_dir_count, get_adjust_dir_count
do
   local function get_dir_count_inner(h)
      if h then
	 if h.id==id_whatsit and h.subtype==sid_user and h.user_id==DIR then
	       local ic = node.has_attribute(h, attr_icflag)
	       return (ic<PROCESSED_BEGIN_FLAG) 
		  and (node.has_attribute(h,attr_dir)%dir_node_auto) or 0
	 else
	    return 0
	 end
      else
	 return 0
      end
   end
   function get_dir_count()
      for i=tex_nest.ptr, 1, -1 do
	 local h = tex_nest[i].head.next
	 --luatexja.ext_show_node_list(h, 'GDR'..  i .. '> ', print)
	 if h then
	    local t = get_dir_count_inner(h)
	    if t~=0 then return t end
	 end
      end
      return page_direction
   end
   function get_adjust_dir_count()
      for i=tex_nest.ptr, 1, -1 do
         local v = tex_nest[i]
	 local h, m = v.head.next, v.mode
	 if abs(m)== ltjs.vmode and h then
	    local t = get_dir_count_inner(h)
	    if t~=0 then return t end
	 end
      end
      return page_direction
   end
   luatexja.direction.get_dir_count = get_dir_count
   luatexja.direction.get_adjust_dir_count = get_adjust_dir_count
end


-- \tate, \yoko
do
   local node_next = node.next
   local node_set_attr = node.set_attribute
   local function set_list_direction(v, name)
      local lv, w = tex_nest.ptr, tex.lists.page_head
      if not v then 
         v,name  = get_dir_count(), nil
      elseif v=='adj' then
         v,name = get_adjust_dir_count(), nil
      elseif v=='math' then
	 v,name  = get_dir_count(), nil
	 if abs(tex_nest[lv].mode) == ltjs.mmode and v == dir_tate then
	    v = dir_utod
	 end
      end
      if tex.currentgrouptype==6 then
	 ltjb.package_error(
                 'luatexja',
                 "You can't use `\\" .. name .. "' in an align",
		 "To change direction in an align, \n"
		    .. "you shold use \\hbox or \\vbox.")
      else
	 local w = (lv==0) and tex.lists.page_head or tex_nest[lv].head.next
	 if w then
	    if (not w.next) and 
	       w.id==id_whatsit and w.subtype==sid_user and w.user_id==DIR then
	       node_set_attr(w, attr_dir, v)
               if lv==0 then page_direction = v end
	    elseif lv==0 and not page_direction then
	       page_direction = v -- for first call of \yoko (in luatexja-core.sty)
	    else
              ltjb.package_error(
                 'luatexja',
                 "Use `\\" .. name .. "' at top of list",
                 'Direction change command by LuaTeX-ja is available\n'
		    .. 'only when the current list is null.')
	    end
	 else
	    local w = node_new(id_whatsit, sid_user)
	    setfield(w, 'next', nil)
	    setfield(w, 'user_id', DIR)
	    setfield(w, 'type', 110)
	    set_attr(w, attr_dir, v)
	    Dnode.write(w)
	    if lv==0 then page_direction = v end
	 end
         tex_set_attr('global', attr_icflag, 0)
      end
      tex_set_attr('global', attr_dir, 0)
   end
   luatexja.direction.set_list_direction = set_list_direction
end

-- ボックスに dir whatsit を追加
local function create_dir_whatsit(hd, gc, new_dir)
   if getid(hd)==id_whatsit and 
	    getsubtype(hd)==sid_user and getfield(hd, 'user_id')==DIR then
      set_attr(hd, attr_icflag, 
	       (has_attr(hd, attr_icflag) or 0)%PROCESSED_BEGIN_FLAG 
		  + PROCESSED_BEGIN_FLAG)
      tex_set_attr('global', attr_icflag, 0)
      return hd
   else
      local w = node_new(id_whatsit, sid_user)
      setfield(w, 'next', hd)
      setfield(w, 'user_id', DIR)
      setfield(w, 'type', 110)
      set_attr(w, attr_dir, new_dir)
      set_attr(w, attr_icflag, PROCESSED_BEGIN_FLAG)
      set_attr(hd, attr_icflag, 
	       (has_attr(hd, attr_icflag) or 0)%PROCESSED_BEGIN_FLAG 
		  + PROCESSED_BEGIN_FLAG)
      tex_set_attr('global', attr_dir, 0)
      tex_set_attr('global', attr_icflag, 0)
      return w
   end
end

-- hpack_filter, vpack_filter, post_line_break_filter
-- の結果を組方向を明示するため，先頭に dir_node を設置
do
   local function create_dir_whatsit_hpack(h, gc)
      local hd = to_direct(h)
      if gc=='fin_row' or gc == 'preamble'  then
	 if hd  then
	    set_attr(hd, attr_icflag, PROCESSED_BEGIN_FLAG)
	    tex_set_attr('global', attr_icflag, 0)
	 end
	 return h
      else
	 adjust_badness(hd)
	 return to_node(create_dir_whatsit(hd, gc, ltjs.list_dir))
      end
   end

   luatexbase.add_to_callback('hpack_filter', 
			      create_dir_whatsit_hpack, 'ltj.create_dir_whatsit', 10000)
end

do
   local function create_dir_whatsit_parbox(h, gc)
      stop_time_measure('tex_linebreak')
      -- start 側は ltj-debug.lua に
      local new_dir, hd = ltjs.list_dir, to_direct(h)
      for line in traverse_id(id_hlist, hd) do
         local nh = getlist(line)
	 setfield(line, 'head', create_dir_whatsit(nh, gc, new_dir) )
	 set_attr(line, attr_dir, new_dir)
      end
      tex_set_attr('global', attr_dir, 0)
      return h 
   end
   luatexbase.add_to_callback('post_linebreak_filter', 
			      create_dir_whatsit_parbox, 'ltj.create_dir_whatsit', 10000)
end

local create_dir_whatsit_vbox
do
   local wh = {}
   local id_glue, sid_parskip = node.id('glue'), 3
   create_dir_whatsit_vbox = function (hd, gc)
      ltjs.list_dir = get_dir_count()
      -- remove dir whatsit
      for x in traverse_id(id_whatsit, hd) do
     	 if getsubtype(x)==sid_user and getfield(x, 'user_id')==DIR then
     	    wh[#wh+1]=x
     	 end
      end
      if hd==wh[1] then
	 ltjs.list_dir =has_attr(hd,attr_dir)
	 local x = node_next(hd)
	 if getid(x)==id_glue and getsubtype(x)==sid_parskip then
	    node_remove(hd,x); node_free(x)
	 end
      end
      for i=1,#wh do  
	 hd = node_remove(hd, wh[i]); node_free(wh[i]); wh[i] = nil 
      end
      if gc=='fin_row' or gc == 'preamble'  then
	 if hd  then
	    set_attr(hd, attr_icflag, PROCESSED_BEGIN_FLAG)
	    tex_set_attr('global', attr_icflag, 0)
	 end
	 return hd
      else
	 local n =node_next(hd)
	 if gc=='vtop' then
	    local w = create_dir_whatsit(hd, gc, ltjs.list_dir)
	    -- move  dir whatsit after hd
	    setfield(hd, 'next', w); setfield(w, 'next', n)
	    return hd
	 else
	    hd = create_dir_whatsit(hd, gc, ltjs.list_dir)
	    return hd
	 end
      end
   end
end

-- dir_node に包む方法を書いたテーブル
local dir_node_aux
do
   local get_h =function (w,h,d) return h end
   local get_d =function (w,h,d) return d end
   local get_h_d =function (w,h,d) return h+d end
   local get_h_d_neg =function (w,h,d) return -h-d end
   local get_h_neg =function (w,h,d) return -h end
   local get_d_neg =function (w,h,d) return -d end
   local get_w_half =function (w,h,d) return 0.5*w end
   local get_w_neg_half =function (w,h,d) return -0.5*w end
   local get_w_neg =function (w,h,d) return -w end
   local get_w =function (w,h,d) return w end
   local zero = function() return 0 end
   dir_node_aux = {
      [dir_yoko] = { -- yoko を 
	 [dir_tate] = { -- tate 中で組む
	    width  = get_h_d,
	    height = get_w_half,
	    depth  = get_w_half,
	    [id_hlist] = {
	       { 'whatsit', sid_save },
	       { 'rotate', '0 1 -1 0' },
	       { 'kern', get_w_neg_half },
	       { 'box' , get_h },
	       { 'kern', get_w_neg_half },
	       { 'whatsit', sid_restore },
	    },
	    [id_vlist] = {
	       { 'whatsit', sid_save },
	       { 'rotate', '0 1 -1 0' },
	       { 'kern' , zero },
	       { 'box' , get_w_neg },
	       { 'kern', get_h_d_neg},
	       { 'whatsit', sid_restore },
	    },
	 },
	 [dir_dtou] = { -- dtou 中で組む
	    width  = get_h_d,
	    height = get_w,
	    depth  = zero,
	    [id_hlist] = {
	       { 'whatsit', sid_save },
	       { 'rotate', '0 -1 1 0' },
	       { 'kern', get_w_neg },
	       { 'box', get_d_neg },
	       { 'whatsit', sid_restore },
	    },
	    [id_vlist] = {
	       { 'whatsit', sid_save },
	       { 'rotate', '0 -1 1 0' },
	       { 'kern', get_h_d_neg },
	       { 'box', zero },
	       { 'whatsit', sid_restore },
	    },
	 },
      },
      [dir_tate] = { -- tate を
	 [dir_yoko] = { -- yoko 中で組む
	    width  = get_h_d,
	    height = get_w,
	    depth  = zero,
	    [id_hlist] = {
	       { 'whatsit', sid_save },
	       { 'rotate', '0 -1 1 0' },
	       { 'kern', get_w_neg },
	       { 'box' , get_d_neg },
	       { 'whatsit', sid_restore },
	    },
	    [id_vlist] = {
	       { 'whatsit', sid_save },
	       { 'rotate', '0 -1 1 0' },
	       { 'kern', get_h_d_neg },
	       { 'box', zero },
	       { 'whatsit', sid_restore },
	    },
	 },
	 [dir_dtou] = { -- dtou 中で組む
	    width  = get_w,
	    height = get_d,
	    depth  = get_h,
	    [id_hlist] = {
	       { 'whatsit', sid_save },
	       { 'rotate', '-1 0 0 -1' },
	       { 'kern', get_w_neg },
	       { 'box', zero },
	       { 'whatsit', sid_restore },
	    },
	    [id_vlist] = {
	       { 'whatsit', sid_save },
	       { 'rotate', '-1 0 0 -1' },
	       { 'kern', get_h_d_neg },
	       { 'box', get_w_neg },
	       { 'whatsit', sid_restore },
	    },
         },
	 [dir_utod] = { -- utod 中で組む
	    width  = get_w,
	    height = get_h,
	    depth  = get_d,
	    [id_hlist] = {
	       { 'nop' },
	       { 'nop' },
	       { 'nop' },
	       { 'box', zero },
	       { 'nop' },
	    },
	    [id_vlist] = {
	       { 'nop' },
	       { 'nop' },
	       { 'nop' },
	       { 'box', zero },
	       { 'nop' },
	    },
	 }
      },
      [dir_dtou] = { -- dtou を
	 [dir_yoko] = { -- yoko 中で組む
	    width  = get_h_d,
	    height = get_w, 
	    depth  = zero,
	    [id_hlist] = {
	       { 'whatsit', sid_save },
	       { 'rotate', '0 1 -1 0' },
	       { 'kern', zero },
	       { 'box', get_h },
	       { 'kern', get_w_neg },
	       { 'whatsit', sid_restore },
	    },
	    [id_vlist] = {
               { 'kern', zero },
	       { 'whatsit', sid_save },
	       { 'rotate', '0 1 -1 0' },
	       { 'box', get_w_neg },
	       { 'kern', get_h_d_neg },
	       { 'whatsit', sid_restore },
	    },
	 },
	 [dir_tate] = { -- tate 中で組む
	    width  = get_w,
	    height = get_d,
	    depth  = get_h,
	    [id_hlist] = {
	       { 'whatsit', sid_save },
	       { 'rotate', '-1 0 0 -1' },
	       { 'kern', get_w_neg },
	       { 'box', zero },
	       { 'whatsit', sid_restore },
	    },
	    [id_vlist] = {
	       { 'whatsit', sid_save },
	       { 'rotate', ' -1 0 0 -1' },
	       { 'kern', get_h_d_neg }, 
	       { 'box', get_w_neg },
	       { 'whatsit', sid_restore },
	    },
	 },
      },
   }
   dir_node_aux[dir_yoko][dir_utod] = dir_node_aux[dir_yoko][dir_tate]
   dir_node_aux[dir_dtou][dir_utod] = dir_node_aux[dir_dtou][dir_tate]
   dir_node_aux[dir_tate][dir_tate] = dir_node_aux[dir_tate][dir_utod]
   dir_node_aux[dir_utod] = dir_node_aux[dir_tate]
end

-- 1st ret val: b の組方向
-- 2nd ret val はその DIR whatsit
local function get_box_dir(b, default)
   start_time_measure('get_box_dir')
   local dir = has_attr(b, attr_dir) or 0
   local bh = getfield(b,'head') 
   -- b は insert node となりうるので getlist() は使えない
   local c
   for i=1,2 do
      if bh and getid(bh)==id_whatsit
      and getsubtype(bh)==sid_user and getfield(bh, 'user_id')==DIR then
	 c = bh
	 dir = (dir==0) and has_attr(bh, attr_dir) or dir
      end
      bh = node_next(bh)
   end
   stop_time_measure('get_box_dir')
   return (dir==0 and default or dir), c
end

do
   local getbox = tex.getbox
   local function check_dir(reg_num)
      start_time_measure('box_primitive_hook')
      local list_dir = get_dir_count()
      local b = getbox(tex_getcount('ltj@tempcnta'))
      if b then
	 local box_dir = get_box_dir(to_direct(b), dir_yoko)
	 if box_dir%dir_node_auto ~= list_dir then
	--    print('NEST', tex_nest.ptr, tex_getcount('ltj@tempcnta'))
	--    luatexja.ext_show_node_list(
        --       (tex_nest.ptr==0) and tex.lists.page_head or tex_nest[tex_nest.ptr].head,
        --       'LIST' .. tostring(list_dir) .. '> ', print)
	--   luatexja.ext_show_node_list(b, 'BOX' .. tostring(box_dir) .. '> ', print)
	    ltjb.package_error(
	       'luatexja',
	       "Incompatible direction list can't be unboxed",
	       'I refuse to unbox a box in differrent direction.')
	 end
      end
      if luatexja.global_temp and tex.globaldefs~=luatexja.global_temp then 
	 tex.globaldefs = luatexja.global_temp
      end
      stop_time_measure('box_primitive_hook')
   end
   luatexja.direction.check_dir = check_dir
end

-- dir_node に包まれている「本来の中身」を取り出し，
-- dir_node を全部消去
local function unwrap_dir_node(b, head, box_dir)
   -- b: dir_node, head: the head of list, box_dir: 
   -- return values are (new head), (next of b), (contents), (dir of contents)
   local bh = getlist(b)
   local bc = node_next(node_next(node_next(bh)))
   local nh, nb
   node_remove(bh, bc); 
   Dnode.flush_list(bh)
   if head then
      nh = insert_before(head, b, bc)
      nh, nb = node_remove(nh, b)
      setfield(b, 'next', nil)
      setfield(b, 'head', nil)
      node_free(b)
   end
   local shift_old, b_dir, wh = nil, get_box_dir(bc, 0)
   if wh then
      Dnode.flush_list(getfield(wh, 'value'))
      setfield(wh, 'value', nil)
   end
   -- recalc. info
   local info = dir_node_aux[b_dir][box_dir%dir_node_auto][getid(bc)]
   for _,v in ipairs(info) do 
      if v[1]=='box' then
	 shift_old = v[2](
	    getfield(bc,'width'), getfield(bc, 'height'), getfield(bc, 'depth'))
	 break
      end
   end
   setfield(bc, 'shift', getfield(bc, 'shift') - shift_old)
   return nh, nb, bc, b_dir
end

-- is_manual: 寸法変更に伴うものか？
local function create_dir_node(b, b_dir, new_dir, is_manual)
   --print('create new node', b_dir, new_dir)
   local info = dir_node_aux[b_dir][new_dir]
   local w = getfield(b, 'width')
   local h = getfield(b, 'height')
   local d = getfield(b, 'depth')
   local db = node_new(getid(b)) -- dir_node
   set_attr(db, attr_dir, 
	    new_dir + (is_manual and dir_node_manual or dir_node_auto))
   set_attr(db, attr_icflag, PROCESSED)
   set_attr(b, attr_icflag, PROCESSED)
   tex_set_attr('global', attr_dir, 0)
   tex_set_attr('global', attr_icflag, 0)
   setfield(db, 'dir', getfield(b, 'dir'))
   setfield(db, 'shift', 0)
   setfield(db, 'width',  info.width(w,h,d))
   setfield(db, 'height', info.height(w,h,d))
   setfield(db, 'depth',  info.depth(w,h,d))
   return db
end

-- 異方向のボックスの処理
local make_dir_whatsit, process_dir_node
do
   make_dir_whatsit = function (head, b, new_dir, origin)
      -- head: list head, b: box
      -- origin: コール元 (for debug)
      -- return value: (new head), (next of b), (new b), (is_b_dir_node)
      -- (new b): b か dir_node に被せられた b
      local bh = getlist(b)
      local box_dir, dn =  get_box_dir(b, ltjs.list_dir)
      -- 既に b の中身にあるwhatsit

      if box_dir==new_dir then
	 -- 組方向が一緒のボックスなので，何もしなくて良い
	 return head, node_next(b), b, false
      elseif  box_dir%dir_node_auto == new_dir  then
	 -- dir_node としてカプセル化されている
	 local bc = node_next(node_next(node_next(bh)))
	 local _, dnc = get_box_dir(b, 0)
	 if dnc then -- free all other dir_node
	    Dnode.flush_list(getfield(dnc, 'value'))
	    setfield(dnc, 'value', nil)
	 end
	 set_attr(b, attr_dir, box_dir%dir_node_auto + dir_node_auto)
	 return head, node_next(b), b, true
      else
	 --luatexja.ext_show_node_list(to_node(b), 'mkd> ', print)
	 -- 組方向を合わせる必要あり
         local nh, nb, ret, flag
	 if box_dir>= dir_node_auto then -- unwrap
	    local b_dir
            head, nb, b, b_dir = unwrap_dir_node(b, head, box_dir)
	    bh = getlist(b)
	    if b_dir==new_dir then
	       -- dir_node の中身が周囲の組方向とあっている
	       return head, nb, b, false 
	    else box_dir = b_dir end
	 end
            local db
            local dnh = getfield(dn, 'value')
            for x in traverse(dnh) do
               if has_attr(x, attr_dir)%dir_node_auto == new_dir then
                  setfield(dn, 'value', to_node(node_remove(dnh, x)))
                  db=x; break
               end
            end
	    Dnode.flush_list(dnh)
            db = db or create_dir_node(b, box_dir, new_dir, false)
            local w = getfield(b, 'width')
            local h = getfield(b, 'height')
            local d = getfield(b, 'depth')
            nh, nb =  insert_before(head, b, db), nil
            nh, nb = node_remove(nh, b)
            local db_head, db_tail  = nil
            for _,v in ipairs(dir_node_aux[box_dir][new_dir][getid(b)]) do
               local cmd, arg, nn = v[1], v[2]
               if cmd=='kern' then
                  nn = node_new(id_kern)
                  setfield(nn, 'kern', arg(w, h, d))
               elseif cmd=='whatsit' then
                  nn = node_new(id_whatsit, arg)
               elseif cmd=='rotate' then
                  nn = node_new(id_whatsit, sid_matrix)
                  setfield(nn, 'data', arg)
               elseif cmd=='box' then
                  nn = b; setfield(b, 'next', nil)
		  setfield(nn, 'shift', getfield(nn, 'shift') + arg(w,h,d))
	       elseif cmd=='nop' then
                  nn = node_new(id_kern)
                  setfield(nn, 'kern', 0)
               end
               if db_head then
                  insert_after(db_head, db_tail, nn)
                  db_tail = nn
	       else
		  db_head, db_tail = nn, nn
	       end
	       setfield(db, 'head', db_head)
	       ret, flag = db, true
	 end
	 return nh, nb, ret, flag
      end
   end
   process_dir_node = function (hd, gc)
      local x, new_dir = hd, ltjs.list_dir or dir_yoko
      while x do
	 local xid = getid(x)
	 if (xid==id_hlist and has_attr(x, attr_icflag)%PROCESSED_BEGIN_FLAG~=PACKED) 
	 or xid==id_vlist then
	    hd, x = make_dir_whatsit(hd, x, new_dir, 'process_dir_node:' .. gc)
	 else
	    x = node_next(x)
	 end
      end
      return hd
   end

   -- lastbox
   local node_prev = (Dnode~=node) and Dnode.getprev or node.prev
   local function lastbox_hook()
      start_time_measure('box_primitive_hook')
      local bn = tex_nest[tex_nest.ptr].tail
      if bn then
	 local b, head = to_direct(bn), to_direct(tex_nest[tex_nest.ptr].head)
	 local bid = getid(b)
	 if bid==id_hlist or bid==id_vlist then
	    local box_dir =  get_box_dir(b, 0)
	    if box_dir>= dir_node_auto then -- unwrap dir_node
	       local p = node_prev(b)
	       local dummy1, dummy2, nb = unwrap_dir_node(b, nil, box_dir)
	       setfield(p, 'next', nb);  tex_nest[tex_nest.ptr].tail = to_node(nb)
	       setfield(b, 'next', nil); setfield(b, 'head', nil)
	       node_free(b); b = nb
	    end
	    local _, wh =  get_box_dir(b, 0) -- clean dir_node attached to the box
	    if wh then
	       Dnode.flush_list(getfield('value', wh))
	       setfield(wh, 'value', nil)
	    end
	 end
      end
      stop_time_measure('box_primitive_hook')
   end

   luatexja.direction.make_dir_whatsit = make_dir_whatsit
   luatexja.direction.lastbox_hook = lastbox_hook
end

-- \wd, \ht, \dp の代わり
do
   local getbox, setdimen = tex.getbox, tex.setdimen
   local function get_box_dim_common(key, s, l_dir)
      local s_dir, wh = get_box_dir(s, dir_yoko)
      if s_dir ~= l_dir then
         local not_found = true
         for x in traverse(getfield(wh, 'value')) do
            if l_dir == has_attr(x, attr_dir)%dir_node_auto then
               setdimen('ltj@tempdima', getfield(x, key))
               not_found = false; break
            end
         end
         if not_found then
            local w = getfield(s, 'width')
            local h = getfield(s, 'height')
            local d = getfield(s, 'depth')
            setdimen('ltj@tempdima', 
                         dir_node_aux[s_dir][l_dir][key](w,h,d))
         end
      else
         setdimen('ltj@tempdima', getfield(s, key))
      end
   end
   local function get_box_dim(key, n)
      local gt = tex.globaldefs; tex.globaldefs = 0
      local s = getbox(n)
      if s then
         local l_dir = get_dir_count()
         s = to_direct(s)
         local b_dir = get_box_dir(s,dir_yoko)
         if b_dir<dir_node_auto then
            get_box_dim_common(key, s, l_dir)
         elseif b_dir%dir_node_auto==l_dir then
            setdimen('ltj@tempdima', getfield(s, key))
         else
            get_box_dim_common(key, 
			       node_next(node_next(node_next(getlist(s)))), l_dir)
         end
      else
         setdimen('ltj@tempdima', 0)
      end
      tex.globaldefs = gt
   end
   luatexja.direction.get_box_dim = get_box_dim

   -- return value: (changed dimen of box itself?)
   local function set_box_dim_common(key, s, l_dir)
      local s_dir, wh = get_box_dir(s, dir_yoko)
      if s_dir ~= l_dir then
         if not wh then
            wh = create_dir_whatsit(getlist(s), 'set_box_dim', s_dir)
            setfield(s, 'head', wh)
         end
         local db
         local dnh = getfield(wh, 'value')
         for x in traverse(dnh) do
            if has_attr(x, attr_dir)%dir_node_auto==l_dir then
               db = x; break
            end
         end
         if not db then
            db = create_dir_node(s, s_dir, l_dir, true)
            setfield(db, 'next', dnh)
            setfield(wh, 'value',to_node(db))
         end
         setfield(db, key, tex.getdimen('ltj@tempdima'))
	 return false
      else
         setfield(s, key, tex.getdimen('ltj@tempdima'))
	 if wh then
	    -- change dimension of dir_nodes which are created "automatically"
	       local bw, bh, bd 
		  = getfield(s,'width'), getfield(s, 'height'), getfield(s, 'depth')
	    for x in traverse(getfield(wh, 'value')) do
	       local x_dir = has_attr(x, attr_dir)
	       if x_dir<dir_node_manual then
		  local info = dir_node_aux[s_dir][x_dir%dir_node_auto]
		  setfield(x, 'width',  info.width(bw,bh,bd))
		  setfield(x, 'height', info.height(bw,bh,bd))
		  setfield(x, 'depth',  info.depth(bw,bh,bd))
	       end
	    end
	 end
	 return true
      end
   end
   local function set_box_dim(key)
      local n = tex_getcount('ltj@tempcnta')
      local s = getbox(n)
      if s then
	 local l_dir = get_dir_count()
	 s = to_direct(s)
         local b_dir = get_box_dir(s,dir_yoko)
         if b_dir<dir_node_auto then
            set_box_dim_common(key, s, l_dir)
	 elseif b_dir%dir_node_auto == l_dir then
	    -- s is dir_node
	    setfield(s, key, tex.getdimen('ltj@tempdima'))
	    if b_dir<dir_node_manual then
	       set_attr(s, attr_dir, b_dir%dir_node_auto + dir_node_manual)
	    end
         else
	    local sid, sl = getid(s), getlist(s)
	    local b = node_next(node_next(node_next(sl)))
	    local info = dir_node_aux[get_box_dir(b,dir_yoko)][b_dir%dir_node_auto]
	    local shift_old
	    for _,v in ipairs(info[sid]) do 
	       if v[1]=='box' then
		  shift_old = v[2](
		     getfield(b,'width'), getfield(b, 'height'), getfield(b, 'depth'))
		  break
	       end
	    end
           if set_box_dim_common(key, b, l_dir) then
	       local bw, bh, bd 
		  = getfield(b,'width'), getfield(b, 'height'), getfield(b, 'depth')
	       -- re-calculate shift
	       for i,v in ipairs(info[sid]) do 
		  if getid(sl)==id_kern then
		     setfield(sl, 'kern', v[2](bw,bh,bd) )
		  elseif getid(sl)==sid then
		     local d = getfield(sl, 'shift')
		     setfield(sl, 'shift', 
			      getfield(sl, 'shift') - shift_old + v[2](bw,bh,bd) )
		  end
		  sl = node_next(sl)
	       end
	       -- re-calculate dimension of s, if s is created "automatically"
	       if b_dir<dir_node_manual then
		  setfield(s, 'width',  info.width(bw,bh,bd))
		  setfield(s, 'height', info.height(bw,bh,bd))
		  setfield(s, 'depth',  info.depth(bw,bh,bd))
	       end
	    end
         end
      end
   end
   luatexja.direction.set_box_dim = set_box_dim
end

do
   local getbox = tex.getbox
   local function get_register_dir(n)
      local s = getbox(n)
      if s then
         s = to_direct(s)
         local b_dir = get_box_dir(s, dir_yoko)
         if b_dir<dir_node_auto then
	    return b_dir
         else
	    local b_dir = get_box_dir(
	       node_next(node_next(node_next(getlist(s)))), dir_yoko)
	    return b_dir
         end
      else
         return 0
      end
   end
   luatexja.direction.get_register_dir = get_register_dir
end

-- raise, lower
do
   local getbox, setbox, copy_list = tex.getbox, tex.setbox, Dnode.copy_list
   function luatexja.direction.raise_box()
      start_time_measure('box_primitive_hook')
      local list_dir = get_dir_count()
      local s = getbox('ltj@afbox')
      if s then
	 local sd = to_direct(s)
	 local box_dir = get_box_dir(sd, dir_yoko)
	 if box_dir%dir_node_auto ~= list_dir then
	    setbox(
	       'ltj@afbox', 
	       to_node(
		  copy_list(make_dir_whatsit(sd, sd, list_dir, 'box_move'))
		  -- without copy_list, we get a segfault
	       )
	    )
	 end
      end
      stop_time_measure('box_primitive_hook')
   end
end

-- 縦書き用字形への変換テーブル
local font_vert_table = {} -- key: fontnumber
do
   local font_vert_basename = {} -- key: basename
   local function add_feature_table(tname, src, dest)
      for i,v in pairs(src) do
	 if type(v.slookups)=='table' then
	    local s = v.slookups[tname]
	    if s and not dest[i] then
	       dest[i] = s
	    end
	 end
      end
   end

   local function prepare_vert_data(n, id)
      -- test if already loaded
      if type(id)=='number' then -- sometimes id is an integer
         font_vert_table[n] = font_vert_table[id]; return
      elseif (not id) or font_vert_table[n]  then return
      end
      local fname = id.filename
      local bname = file.basename(fname)
      if not fname then
         font_vert_table[n] = {}; return
      elseif font_vert_basename[bname] then
         font_vert_table[n] = font_vert_basename[bname]; return
      end
      local vtable = {}
      local a = id.resources.sequences
      if a then
	 local s = id.shared.rawdata.descriptions
	 for i,v in pairs(a) do
	    if v.features.vert or v.features.vrt2 then
	       add_feature_table(v.subtables[1], s, vtable)
	    end
	 end
      end
      font_vert_basename[bname] = vtable
      font_vert_table[n] = vtable
   end
   -- 縦書き用字形への変換
   function luatexja.direction.get_vert_glyph(n, chr)
      local fn = font_vert_table[n]
      return fn and fn[chr] or chr
   end
   luatexbase.add_to_callback('luatexja.define_font',
			      function (res, name, size, id)
				 prepare_vert_data(id, res)
			      end,
			      'prepare_vert_data', 1)

   local function a (n, dat) font_vert_table[n] = dat end
   luatexja.rmlgbm.vert_addfunc = a

end

-- PACKED の hbox から文字を取り出す
-- luatexja.jfmglue.check_box などで使用
do
   local function glyph_from_packed(h)
      local b = getlist(h)
      return (getid(b)==id_kern) 
	 and node_next(node_next(node_next(node_next(b)))) or b
   end
   luatexja.direction.glyph_from_packed = glyph_from_packed
end

-- adjust and insertion
local id_adjust = node.id('adjust')
function luatexja.direction.check_adjust_direction()
   start_time_measure('box_primitive_hook')
   local list_dir = get_adjust_dir_count()
   local a = tex_nest[tex_nest.ptr].tail
   local ad = to_direct(a)
   if a and getid(ad)==id_adjust then
      local adj_dir = get_box_dir(ad)
      if list_dir~=adj_dir then
         ltjb.package_error(
                 'luatexja',
                 'Direction Incompatible',
                 "\\vadjust's argument and outer vlist must have same direction.")
         Dnode.last_node()
      end
   end
   stop_time_measure('box_primitive_hook')
end

-- vsplit
do
   local split_dir_whatsit
   local function dir_adjust_vpack(h, gc)
      start_time_measure('direction_vpack')
      local hd = to_direct(h)
      if gc=='split_keep' then
	 -- supply dir_whatsit
	 hd = create_dir_whatsit_vbox(hd, gc)
	 split_dir_whatsit = hd
      elseif gc=='split_off'  then
	 local bh=hd
	 for i=1,2 do
	    if bh and getid(bh)==id_whatsit
	    and getsubtype(bh)==sid_user and getfield(bh, 'user_id')==DIR then
	       ltjs.list_dir  = has_attr(bh, attr_dir); break
	    end
	    bh = node_next(bh)
	 end
	 if split_dir_whatsit then
	    -- adjust direction of 'split_keep'
	    set_attr(split_dir_whatsit, attr_dir, ltjs.list_dir)
	 end
	 split_dir_whatsit=nil
      elseif gc=='preamble' then
	 split_dir_whatsit=nil
      else
	 adjust_badness(hd)
	 hd = process_dir_node(create_dir_whatsit_vbox(hd, gc), gc)
	 split_dir_whatsit=nil
      end
      stop_time_measure('direction_vpack')
      return to_node(hd)
   end
   luatexbase.add_to_callback('vpack_filter',
			      dir_adjust_vpack,
			      'ltj.direction', 10000)
end

do
   -- supply direction whatsit to the main vertical list "of the next page"
   local function dir_adjust_pre_output(h, gc)
      return to_node(create_dir_whatsit_vbox(to_direct(h), gc))
   end
   luatexbase.add_to_callback('pre_output_filter',
			      dir_adjust_pre_output,
			      'ltj.direction', 10000)

   function luatexja.direction.remove_end_whatsit()
      local h=tex.lists.page_head
      if (not h.next) and
	 h.id==id_whatsit and h.subtype==sid_user and
         h.user_id == DIR then
	    tex.lists.page_head = nil
	    node.free(h)
      end
   end
end

-- 
do
   local function dir_adjust_buildpage(info)
      if info=='box' then
	 local head = to_direct(tex.lists.contrib_head)
	 local nb
	 if head then
	    head, _, nb
	       = make_dir_whatsit(head, 
				  node_tail(head),
				  get_dir_count(), 
				  'buildpage')
	    tex.lists.contrib_head = to_node(head)
	 end
      end
   end
   luatexbase.add_to_callback('buildpage_filter',
			      dir_adjust_buildpage,
			      'ltj.direction', 10000)
end
