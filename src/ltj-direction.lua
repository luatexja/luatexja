--
-- src/ltj-direction.lua
--

luatexja.load_module 'base';      local ltjb = luatexja.base
luatexja.load_module 'stack';     local ltjs = luatexja.stack
luatexja.direction = {}

local attr_dir = luatexbase.attributes['ltj@dir']
local attr_icflag = luatexbase.attributes['ltj@icflag']

local dnode = node.direct
local cat_lp = luatexbase.catcodetables['latex-package']
local to_node = dnode.tonode
local to_direct = dnode.todirect
local get_attr = dnode.get_attribute
local set_attr = dnode.set_attribute
local insert_before = dnode.insert_before
local insert_after = dnode.insert_after
local getid = dnode.getid
local getsubtype = dnode.getsubtype
local getlist = dnode.getlist
local getfield = dnode.getfield
local getwhd = dnode.getwhd
local getvalue = node.direct.getdata
local setfield = dnode.setfield
local setwhd = dnode.setwhd
local setnext = dnode.setnext
local setlist = dnode.setlist
local setvalue = node.direct.setdata

local node_new = dnode.new
local node_free = dnode.flush_node or dnode.free
local node_remove = dnode.remove
local node_next = dnode.getnext
local traverse = dnode.traverse
local traverse_id = dnode.traverse_id
local start_time_measure, stop_time_measure
    = ltjb.start_time_measure, ltjb.stop_time_measure
local abs = math.abs

local id_kern    = node.id 'kern'
local id_hlist   = node.id 'hlist'
local id_vlist   = node.id 'vlist'
local id_whatsit = node.id 'whatsit'
local sid_save   = node.subtype 'pdf_save'
local sid_user   = node.subtype 'user_defined'

local getnest = tex.getnest
local tex_nest = tex.nest
local getcount = tex.getcount
local ensure_tex_attr = ltjb.ensure_tex_attr
local PROCESSED    = luatexja.icflag_table.PROCESSED
local PROCESSED_BEGIN_FLAG = luatexja.icflag_table.PROCESSED_BEGIN_FLAG
local PACKED       = luatexja.icflag_table.PACKED
local DIR  = luatexja.userid_table.DIR
local dir_tate = luatexja.dir_table.dir_tate
local dir_yoko = luatexja.dir_table.dir_yoko
local dir_dtou = luatexja.dir_table.dir_dtou
local dir_utod = luatexja.dir_table.dir_utod
local dir_math_mod    = luatexja.dir_table.dir_math_mod
local dir_node_auto   = luatexja.dir_table.dir_node_auto
local dir_node_manual = luatexja.dir_table.dir_node_manual
local function get_attr_icflag(p)
   return (get_attr(p, attr_icflag) or 0) % PROCESSED_BEGIN_FLAG
end

local page_direction
--
local dir_pool
do
   local node_copy = dnode.copy
   dir_pool = {}
   for _,i in pairs({dir_tate, dir_yoko, dir_dtou, dir_utod}) do
      local w = node_new(id_whatsit, sid_user)
      dnode.setattributelist(w, nil)
      set_attr(w, attr_dir, i); set_attr(w, attr_icflag, 0)
      setfield(w, 'user_id', DIR)
      setfield(w, 'type', 110); setnext(w, nil)
      dir_pool[i] = function () return node_copy(w) end
   end
end

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
   local node_attr = node.get_attribute
   local function get_dir_count_inner(h)
      if h then
         if h.id==id_whatsit and h.subtype==sid_user and h.user_id==DIR then
            return ((node_attr(h, attr_icflag) or 0)<PROCESSED_BEGIN_FLAG)
               and (node_attr(h,attr_dir)%dir_node_auto) or 0
         else
            return 0
         end
      else
         return 0
      end
   end
   function get_dir_count()
       for i=tex_nest.ptr, 1, -1 do
           local h = getnest(i).head.next
           if h then
               local t = get_dir_count_inner(h)
               if t~=0 then return t end
           end
       end
       return page_direction
   end
   function get_adjust_dir_count()
      for i=tex_nest.ptr, 1, -1 do
         local v = getnest(i)
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


-- \tate, \yoko，\dtou, \utod
do
   local node_next = node.next
   local node_set_attr = node.set_attribute
   local node_traverse = node.traverse
   local STCK = luatexja.userid_table.STCK
   local IHB = luatexja.userid_table.IHB
   local id_local = node.id 'local_par'
   local id_dir   = node.id 'dir'

   local function test_list(h, lv)
      if not h then
         return 2 -- need to create dir_whatsit
      else
         local flag = 2 -- need to create dir_whatsit
         local w
         for p in node_traverse(h) do
            if p.id==id_whatsit then
               if p.subtype==sid_user then
                  local uid= p.user_id
                  if uid==DIR then
                     flag = 1; w = w or p -- found
                  elseif not(uid==IHB or uid==STCK) then
                     return 0 -- error
                  end
               end
            elseif p.id~=id_local and p.id~=id_dir then
               return 0 -- error
            end
         end
         if flag==1 then -- dir_whatsit already exists
            return 1, w
         else
            return flag
         end
      end
   end
   local node_next_node, node_tail_node = node.next, node.tail
   local insert_after_node = node.insert_after
   function luatexja.direction.set_list_direction_hook(v)
      if not v then
         v = get_dir_count()
         if abs(getnest(tex_nest.ptr-1).mode) == ltjs.mmode and v == dir_tate then
            v = dir_utod
         end
      elseif v=='adj' then
         v = get_adjust_dir_count()
      end
      local h = getnest().head
      local hn = node.next(h)
      hn = (hn and hn.id==id_local) and hn or h
      local w = to_node(dir_pool[v]())
      insert_after_node(h, hn, w)
      getnest().tail = node_tail_node(w)
      ensure_tex_attr(attr_icflag, 0)
      ensure_tex_attr(attr_dir, 0)
   end

   local function set_list_direction(v, name)
      local lv = tex_nest.ptr
      if not v then
         v,name  = get_dir_count(), nil
         if lv>=1 and abs(getnest(lv-1).mode) == ltjs.mmode and v == dir_tate then
            v = dir_utod
         end
      elseif v=='adj' then
         v,name = get_adjust_dir_count(), nil
      end
      local current_nest = getnest()
      if tex.currentgrouptype==6 then
         ltjb.package_error(
                 'luatexja',
                 "You can't use `\\" .. name .. "' in an align",
                 "To change the direction in an align, \n"
                 .. "you shold use \\hbox or \\vbox.")
      elseif current_nest.mode == ltjs.hmode or abs(current_nest.mode) == ltjs.mmode then
         ltjb.package_error(
                 'luatexja',
                 "Improper `\\" .. name .. "'",
                 'You cannot change the direction in unrestricted horizontal mode \n'
                 .. 'nor math modes.')
      else
         local h = (lv==0) and tex.lists.page_head or current_nest.head.next
         local flag,w = test_list(h,lv)
         if flag==0 then
            if lv==0 and not page_direction then
               page_direction = v -- for first call of \yoko (in luatexja-core.sty)
            else
              if luatexja.debug then
                luatexja.ext_show_node_list(dnode.tonode(h),'>> ', texio.write_nl)
              end
              ltjb.package_error(
                 'luatexja',
                 "Use `\\" .. tostring(name) .. "' at top of list",
                 'Direction change command by LuaTeX-ja is available\n'
                    .. 'only when the current list is null.')
            end
         elseif flag==1 then
            node_set_attr(w, attr_dir, v)
            if lv==0 then page_direction = v end
         elseif lv==0 then
            page_direction = v
         else -- flag == 2: need to create dir whatsit.
            local h = current_nest.head
            local hn = node.next(h)
            hn = (hn and hn.id==id_local) and hn or h
            local w = to_node(dir_pool[v]())
            insert_after_node(h,hn,w)
            current_nest.tail = node_tail_node(w)
         end
         ensure_tex_attr(attr_icflag, 0)
      end
      ensure_tex_attr(attr_dir, 0)
   end
   luatexja.direction.set_list_direction = set_list_direction
end

-- ボックスに dir whatsit を追加
local function create_dir_whatsit(hd, gc, new_dir)
   if getid(hd)==id_whatsit and
            getsubtype(hd)==sid_user and getfield(hd, 'user_id')==DIR then
      set_attr(hd, attr_icflag,
               get_attr_icflag(hd) + PROCESSED_BEGIN_FLAG)
      local n =node_next(hd)
      if n then
         set_attr(n, attr_icflag,
                  get_attr_icflag(n) + PROCESSED_BEGIN_FLAG)
      end
      ensure_tex_attr(attr_icflag, 0)
      return hd
   else
      local w = dir_pool[new_dir]()
      set_attr(w, attr_icflag, PROCESSED_BEGIN_FLAG)
      set_attr(hd, attr_icflag,
               get_attr_icflag(hd) + PROCESSED_BEGIN_FLAG)
      ensure_tex_attr(attr_icflag, 0)
      ensure_tex_attr(attr_dir, 0)
      return insert_before(hd, hd, w)
   end
end

-- hpack_filter, vpack_filter, post_line_break_filter
-- の結果を組方向を明示するため，先頭に dir_node を設置
local get_box_dir
do
   local function create_dir_whatsit_hpack(h, gc)
      local hd = to_direct(h)
      if gc=='fin_row' then
         if hd  then
            for p in traverse_id(15, hd) do -- unset
               if get_box_dir(p, 0)==0 then
                  setfield(p, 'head', create_dir_whatsit(getfield(p, 'head'), 'fin_row', ltjs.list_dir))
                  -- We cannot use setlist and getlist, since they don't support unset_node
               end
            end
            set_attr(hd, attr_icflag, PROCESSED_BEGIN_FLAG)
            ensure_tex_attr(attr_icflag, 0)
         end
         return h
      elseif gc == 'preamble'  then
      else
         adjust_badness(hd)
         return to_node(create_dir_whatsit(hd, gc, ltjs.list_dir))
      end
   end

   ltjb.add_to_callback('hpack_filter',
                              create_dir_whatsit_hpack, 'ltj.create_dir_whatsit', 10000)
end

do
   local function create_dir_whatsit_parbox(h, gc)
      stop_time_measure 'tex_linebreak';
      -- start 側は ltj-debug.lua に
      local new_dir = ltjs.list_dir
      for line in traverse_id(id_hlist, to_direct(h)) do
         setlist(line, create_dir_whatsit(getlist(line), gc, new_dir) )
      end
      ensure_tex_attr(attr_dir, 0)
      return h
   end
   ltjb.add_to_callback('post_linebreak_filter',
                              create_dir_whatsit_parbox, 'ltj.create_dir_whatsit', 10000)
end

local create_dir_whatsit_vbox
do
   local wh = {}
   local id_glue = node.id 'glue'
   create_dir_whatsit_vbox = function (hd, gc)
      ltjs.list_dir = get_dir_count()
      -- remove dir whatsit
      for x in traverse_id(id_whatsit, hd) do
         if getsubtype(x)==sid_user and getfield(x, 'user_id')==DIR then
            wh[#wh+1]=x
         end
      end
      if hd==wh[1] then
         ltjs.list_dir = get_attr(hd, attr_dir)
         local x = node_next(hd)
         while x and getid(x)==id_glue and getsubtype(x)==3 do
            node_remove(hd,x); node_free(x); x = node_next(hd)
         end
         --if gc~='vtop' then
         --    if #wh==1 then wh[1]=nil else wh[#wh], wh[1]=nil, wh[#wh] end
         --end
      end
      for i=1,#wh do
         hd = node_remove(hd, wh[i]); node_free(wh[i]); wh[i] = nil
      end
      if gc=='fin_row' then -- gc == 'preamble' case is treated in dir_adjust_vpack
         if hd then
            set_attr(hd, attr_icflag, PROCESSED_BEGIN_FLAG)
            ensure_tex_attr(attr_icflag, 0)
         end
         return hd
      elseif gc=='vtop' then
         local n = node_next(hd)
         local w = create_dir_whatsit(hd, gc, ltjs.list_dir)
         -- move dir whatsit after hd
         setnext(hd, w); setnext(w, n)
         return hd
      else return create_dir_whatsit(hd, gc, ltjs.list_dir)
      end
   end
end

-- dir_node に包む方法を書いたテーブル
local dir_node_aux
do
   local setkern = dnode.setkern
   local setshift = dnode.setshift
   local sid_restore= node.subtype 'pdf_restore'
   local sid_matrix = node.subtype 'pdf_setmatrix'
   local floor = math.floor
   local get_h =function (w,h,d) return h end
   local get_d =function (w,h,d) return d end
   local get_h_d =function (w,h,d) return h+d end
   local get_h_d_neg =function (w,h,d) return -h-d end
   local get_d_neg =function (w,h,d) return -d end
   local get_w_half =function (w,h,d) return floor(0.5*w) end
   local get_w_half_rem =function (w,h,d) return w-floor(0.5*w) end
   local get_w_neg =function (w,h,d) return -w end
   local get_w =function (w,h,d) return w end
   local zero = function() return 0 end
   local function gen_kern(arg, b, w,h,d,dw,dh,dd)
      local nn = node_new(id_kern)
      setkern(nn, arg(w, h, d, dw, dh, dd)); return nn
   end
   local function gen_whatsit(arg)
      return node_new(id_whatsit, arg)
   end
   local function gen_rotate(arg)
      local nn = node_new(id_whatsit, sid_matrix)
      setfield(nn, 'data', arg); return nn
   end
   local function gen_box(arg, b, w,h,d,dw,dh,dd)
      local nn = b; setnext(b, nil)
      setshift(nn, arg(w, h, d, dw, dh, dd)); return nn
   end
   dir_node_aux = {
      [dir_yoko] = { -- yoko を
         [dir_tate] = { -- tate 中で組む
            width  = get_h_d,
            height = get_w_half,
            depth  = get_w_half_rem,
            [id_hlist] = {
               { gen_whatsit, sid_save },
               { gen_rotate, '0 1 -1 0' },
               { gen_kern, function(w,h,d,nw,nh,nd) return -nd end },
               { gen_box , get_h},
               { gen_kern, function(w,h,d,nw,nh,nd) return nd-w end },
               { gen_whatsit, sid_restore },
            },
            [id_vlist] = {
               { gen_whatsit, sid_save },
               { gen_rotate, '0 1 -1 0' },
               { gen_kern , zero },
               { gen_box , function(w,h,d,nw,nh,nd) return -nh-nd end },
               { gen_kern, get_h_d_neg},
               { gen_whatsit, sid_restore },
            },
         },
         [dir_dtou] = { -- dtou 中で組む
            width  = get_h_d,
            height = get_w,
            depth  = zero,
            [id_hlist] = {
               { gen_whatsit, sid_save },
               { gen_rotate, '0 -1 1 0' },
               { gen_kern, function(w,h,d,nw,nh,nd) return -nh end },
               { gen_box, get_d_neg },
               { gen_kern, function(w,h,d,nw,nh,nd) return nh-w end },
               { gen_whatsit, sid_restore },
            },
            [id_vlist] = {
               { gen_whatsit, sid_save },
               { gen_rotate, '0 -1 1 0' },
               { gen_kern, get_h_d_neg },
               { gen_box, zero },
               { gen_whatsit, sid_restore },
            },
         },
      },
      [dir_tate] = { -- tate を
         [dir_yoko] = { -- yoko 中で組む
            width  = get_h_d,
            height = get_w,
            depth  = zero,
            [id_hlist] = {
               { gen_whatsit, sid_save },
               { gen_rotate, '0 -1 1 0' },
               { gen_kern, function (w,h,d,nw,nh,nd) return -nh end },
               { gen_box , get_d_neg },
               { gen_kern, function (w,h,d,nw,nh,nd) return nh-w end },
               { gen_whatsit, sid_restore },
            },
            [id_vlist] = {
               { gen_whatsit, sid_save },
               { gen_rotate, '0 -1 1 0' },
               { gen_kern, get_h_d_neg },
               { gen_box, zero },
               { gen_whatsit, sid_restore },
            },
         },
         [dir_dtou] = { -- dtou 中で組む
            width  = get_w,
            height = get_d,
            depth  = get_h,
            [id_hlist] = {
               { gen_whatsit, sid_save },
               { gen_rotate, '-1 0 0 -1' },
               { gen_kern, get_w_neg },
               { gen_box,  function (w,h,d,nw,nh,nd) return h-nd end },
               { gen_whatsit, sid_restore },
            },
            [id_vlist] = {
               { gen_whatsit, sid_save },
               { gen_rotate, '-1 0 0 -1' },
               { gen_kern, get_h_d_neg },
               { gen_box, get_w_neg },
               { gen_whatsit, sid_restore },
            },
         },
      },
      [dir_dtou] = { -- dtou を
         [dir_yoko] = { -- yoko 中で組む
            width  = get_h_d,
            height = get_w,
            depth  = zero,
            [id_hlist] = {
               { gen_whatsit, sid_save },
               { gen_rotate, '0 1 -1 0' },
               { gen_kern, function (w,h,d,nw,nh,nd) return -nd end },
               { gen_box, get_h },
               { gen_kern, function (w,h,d,nw,nh,nd) return nd-w end },
               { gen_whatsit, sid_restore },
            },
            [id_vlist] = {
               { gen_kern, zero },
               { gen_whatsit, sid_save },
               { gen_rotate, '0 1 -1 0' },
               { gen_box, function (w,h,d,nw,nh,nd) return -nd-nh end },
               { gen_kern, get_h_d_neg },
               { gen_whatsit, sid_restore },
            },
         },
         [dir_tate] = { -- tate 中で組む
            width  = get_w,
            height = get_d,
            depth  = get_h,
            [id_hlist] = {
               { gen_whatsit, sid_save },
               { gen_rotate, '-1 0 0 -1' },
               { gen_kern, get_w_neg },
               { gen_box, function (w,h,d,nw,nh,nd) return h-nd end },
               { gen_whatsit, sid_restore },
            },
            [id_vlist] = {
               { gen_whatsit, sid_save },
               { gen_rotate, ' -1 0 0 -1' },
               { gen_kern, function (w,h,d,nw,nh,nd) return -nh-nd end },
               { gen_box, get_w_neg },
               { gen_kern, function (w,h,d,nw,nh,nd) return nh+nd-h-d end },
               { gen_whatsit, sid_restore },
            },
         },
      },
   }
end

-- 1st ret val: b の組方向
-- 2nd ret val はその DIR whatsit
function get_box_dir(b, default)
   start_time_measure 'get_box_dir'
   local dir = get_attr(b, attr_dir) or 0
   local bh = getfield(b, 'head') -- We cannot use getlist since b may be an unset_node.
   local c
   if bh~=0 then -- bh != nil
      for bh in traverse_id(id_whatsit, bh) do
         if getsubtype(bh)==sid_user and getfield(bh, 'user_id')==DIR then
            c = bh; dir = (dir==0) and get_attr(bh, attr_dir) or dir
         end
      end
   end
   stop_time_measure 'get_box_dir'
   return (dir==0 and default or dir), c
end

do
   local ltj_tempcnta = luatexbase.registernumber 'ltj@tempcnta'
   local getbox = tex.getbox
   local dir_backup
   function luatexja.direction.unbox_check_dir()
      start_time_measure 'box_primitive_hook'
      local list_dir = get_dir_count()%dir_math_mod
      local b = getbox(getcount(ltj_tempcnta))
      if b and getlist(to_direct(b)) then
         local box_dir = get_box_dir(to_direct(b), dir_yoko)
         if box_dir%dir_math_mod ~= list_dir then
            ltjb.package_error(
               'luatexja',
               "Incompatible direction list can't be unboxed",
               'I refuse to unbox a box in differrent direction.')
            tex.sprint(cat_lp, '\\@gobbletwo')
         else
            dir_backup = nil
            local bd = to_direct(b)
            local hd = getlist(bd)
            local nh = hd
            while hd do
               if getid(hd)==id_whatsit and getsubtype(hd)==sid_user
                  and getfield(hd, 'user_id')==DIR then
                     local d = hd
                     nh, hd = node_remove(nh, hd); node_free(d)
               else
                  hd = node_next(hd)
               end
            end
            setlist(bd, nh)
         end
      end
      if luatexja.global_temp and tex.globaldefs~=luatexja.global_temp then
         tex.globaldefs = luatexja.global_temp
      end
      stop_time_measure 'box_primitive_hook'
   end
   function luatexja.direction.uncopy_check_dir()
      start_time_measure 'box_primitive_hook'
      local list_dir = get_dir_count()%dir_math_mod
      local b = getbox(getcount(ltj_tempcnta))
      if b and getlist(to_direct(b)) then
         local box_dir = get_box_dir(to_direct(b), dir_yoko)
         if box_dir%dir_math_mod ~= list_dir then
            ltjb.package_error(
               'luatexja',
               "Incompatible direction list can't be unboxed",
               'I refuse to unbox a box in differrent direction.')
            tex.sprint(cat_lp, '\\@gobbletwo')
         else
            dir_backup = nil
            local bd = to_direct(b)
            local hd = getlist(bd)
            local nh = hd
            while hd do
               if getid(hd)==id_whatsit and getsubtype(hd)==sid_user
                  and getfield(hd, 'user_id')==DIR then
                     local d = hd
                     nh, hd = node_remove(nh, hd)
                     if not dir_backup then
                        dir_backup = d; setnext(dir_backup, nil)
                     else
                        node_free(d)
                     end
               else
                  hd = node_next(hd)
               end
            end
            setlist(bd, nh)
         end
      end
      if luatexja.global_temp and tex.globaldefs~=luatexja.global_temp then
         tex.globaldefs = luatexja.global_temp
      end
      stop_time_measure 'box_primitive_hook'
   end
   function luatexja.direction.uncopy_restore_whatsit()
      local b = getbox(getcount(ltj_tempcnta))
      if b then
         local bd = to_direct(b)
         if dir_backup then
            setnext(dir_backup, getlist(bd))
            setlist(bd, dir_backup)
            dir_backup = nil
         end
      end
   end
end

-- dir_node に包まれている「本来の中身」を取り出し，
-- dir_node を全部消去
local function unwrap_dir_node(b, head, box_dir)
   -- b: dir_node, head: the head of list, box_dir:
   -- return values are (new head), (next of b), (contents), (dir of contents)
   local bh = getlist(b)
   local nh, nb
   if head then
      nh = insert_before(head, b, bh)
      nh, nb = node_remove(nh, b)
      setnext(b, nil); node_free(b)
   end
   local shift_old, b_dir, wh = nil, get_box_dir(bh, 0)
   if wh then
      dnode.flush_list(getvalue(wh)); setvalue(wh, nil)
   end
   return nh, nb, bh, b_dir
end

-- is_manual: 寸法変更に伴うものか？
local create_dir_node
do
    local getdir = dnode.getdir
    local setdir = dnode.setdir
    local setshift = dnode.setshift

create_dir_node = function(b, b_dir, new_dir, is_manual)
   local info = dir_node_aux[b_dir%dir_math_mod][new_dir%dir_math_mod]
   local w, h, d = getwhd(b)
   local db = node_new(getid(b)) -- dir_node
   set_attr(db, attr_dir,
            new_dir + (is_manual and dir_node_manual or dir_node_auto))
   set_attr(db, attr_icflag, PROCESSED)
   set_attr(b, attr_icflag, PROCESSED)
   ensure_tex_attr(attr_dir, 0)
   ensure_tex_attr(attr_icflag, 0)
   setdir(db, getdir(b)); setshift(db, 0)
   setwhd(db, info.width(w,h,d), info.height(w,h,d), info.depth(w,h,d))
   return db
end
end

-- 異方向のボックスの処理
local make_dir_whatsit, process_dir_node
do
   make_dir_whatsit = function (head, b, new_dir, origin)
      new_dir = new_dir%dir_math_mod
      -- head: list head, b: box
      -- origin: コール元 (for debug)
      -- return value: (new head), (next of b), (new b), (is_b_dir_node)
      -- (new b): b か dir_node に被せられた b
      local bh = getlist(b)
      local box_dir, dn =  get_box_dir(b, ltjs.list_dir)
      -- 既に b の中身にあるwhatsit
      if (box_dir<dir_node_auto) and (not dn) then
        bh = create_dir_whatsit(bh, 'make_dir_whatsit', dir_yoko)
        dn = bh; setlist(b, bh)
      end
      if box_dir%dir_math_mod==new_dir then
         if box_dir>=dir_node_auto then
            -- dir_node としてカプセル化されている
            local _, dnc = get_box_dir(b, 0)
            if dnc then -- free all other dir_node
               dnode.flush_list(getvalue(dnc)); setvalue(dnc, nil)
            end
            set_attr(b, attr_dir, box_dir%dir_math_mod + dir_node_auto)
            return head, node_next(b), b, true
         else
            -- 組方向が一緒 (up to math dir) のボックスなので，何もしなくて良い
            return head, node_next(b), b, false
         end
      else
         -- 組方向を合わせる必要あり
         local nh, nb, ret, flag
         if box_dir>= dir_node_auto then -- unwrap
            local b_dir
            head, nb, b, b_dir = unwrap_dir_node(b, head, box_dir)
            bh = getlist(b)
            if b_dir%dir_math_mod==new_dir then
               -- dir_node の中身が周囲の組方向とあっている
               return head, nb, b, false
            else box_dir = b_dir end
         end
         box_dir = box_dir%dir_math_mod
         local db
         local dnh = getvalue(dn)
         for x in traverse(dnh) do
            if get_attr(x, attr_dir)%dir_math_mod == new_dir then
               setvalue(dn, to_node(node_remove(dnh, x)))
               db=x; break
            end
         end
         dnode.flush_list(getvalue(dn)); setvalue(dn, nil)
         db = db or create_dir_node(b, box_dir, new_dir, false)
         local w, h, d = getwhd(b)
         nh, nb =  insert_before(head, b, db), nil
         nh, nb = node_remove(nh, b)
         setnext(b, nil); setlist(db, b)
         ret, flag = db, true
         return nh, nb, ret, flag
      end
   end
   process_dir_node = function (hd, gc)
      local x, new_dir = hd, ltjs.list_dir or dir_yoko
      while x do
         local xid = getid(x)
         if (xid==id_hlist and get_attr_icflag(x)~=PACKED)
         or xid==id_vlist then
            hd, x = make_dir_whatsit(hd, x, new_dir, 'process_dir_node:' .. gc)
         else
            x = node_next(x)
         end
      end
      return hd
   end

   -- lastbox
   local node_prev = dnode.getprev
   local id_glue = node.id 'glue'
   local function lastbox_hook()
      start_time_measure 'box_primitive_hook'
      local bn = getnest().tail
      if bn then
         local b, head = to_direct(bn), to_direct(getnest().head)
         local bid = getid(b)
         if bid==id_hlist or bid==id_vlist then
            local p = getlist(b)
            -- alignment の各行の中身が入ったボックス
            if p and getid(p)==id_glue and getsubtype(p)==12 then -- tabskip
               local np = node_next(p); local npid = getid(np)
               if npid==id_hlist or npid==id_vlist then
                  setlist(b, create_dir_whatsit(p, 'align', get_box_dir(np, 0)))
               end
            end
            local box_dir =  get_box_dir(b, 0)
            if box_dir>= dir_node_auto then -- unwrap dir_node
               local p = node_prev(b)
               local dummy1, dummy2, nb = unwrap_dir_node(b, nil, box_dir)
               setnext(p, nb);  getnest().tail = to_node(nb)
               setnext(b, nil); setlist(b, nil)
               node_free(b); b = nb
            end
            local _, wh =  get_box_dir(b, 0) -- clean dir_node attached to the box
            if wh then
               dnode.flush_list(getvalue(wh)); setvalue(wh, nil)
            end
         end
      end
      stop_time_measure 'box_primitive_hook'
   end

   luatexja.direction.make_dir_whatsit = make_dir_whatsit
   luatexja.direction.lastbox_hook = lastbox_hook
end

-- \wd, \ht, \dp の代わり
do
   local getbox, setdimen = tex.getbox, tex.setdimen
   local ltj_tempdima = luatexbase.registernumber 'ltj@tempdima'
   local function get_box_dim_common(key, s, l_dir)
      -- s: not dir_node.
      local s_dir, wh = get_box_dir(s, dir_yoko)
      s_dir = s_dir%dir_math_mod
      if s_dir ~= l_dir then
         local not_found = true
         for x in traverse(getvalue(wh)) do
            if l_dir == get_attr(x, attr_dir)%dir_node_auto then
               setdimen(ltj_tempdima, getfield(x, key))
               not_found = false; break
            end
         end
         if not_found then
            local w, h, d = getwhd(s)
            setdimen(ltj_tempdima, dir_node_aux[s_dir][l_dir][key](w,h,d))
         end
      else
         setdimen(ltj_tempdima, getfield(s, key))
      end
   end
   local function get_box_dim(key, n)
      local gt = tex.globaldefs; tex.globaldefs = 0
      local s = getbox(n)
      if s then
         local l_dir = (get_dir_count())%dir_math_mod
         s = to_direct(s)
         local b_dir = get_box_dir(s,dir_yoko)
         if b_dir<dir_node_auto then
            get_box_dim_common(key, s, l_dir)
         elseif b_dir%dir_math_mod==l_dir then
            setdimen(ltj_tempdima, getfield(s, key))
         else
            get_box_dim_common(key, getlist(s), l_dir)
         end
      else
         setdimen(ltj_tempdima, 0)
      end
      tex.sprint(cat_lp, '\\ltj@tempdima')
      tex.globaldefs = gt
   end
   luatexja.direction.get_box_dim = get_box_dim

   -- return value: (changed dimen of box itself?)
   local scan_dimen, scan_int = token.scan_dimen, token.scan_int
   local scan_keyword = token.scan_keyword
   local function set_box_dim_common(key, s, l_dir)
      local s_dir, wh = get_box_dir(s, dir_yoko)
      s_dir = s_dir%dir_math_mod
      if s_dir ~= l_dir then
         if not wh then
            wh = create_dir_whatsit(getlist(s), 'set_box_dim', s_dir)
            setlist(s, wh)
         end
         local db
         local dnh = getvalue(wh)
         for x in traverse(dnh) do
            if get_attr(x, attr_dir)%dir_node_auto==l_dir then
               db = x; break
            end
         end
         if not db then
            db = create_dir_node(s, s_dir, l_dir, true)
            setnext(db, dnh); setvalue(wh, to_node(db))
         end
         setfield(db, key, scan_dimen())
         return false
      else
         setfield(s, key, scan_dimen())
         if wh then
            -- change dimension of dir_nodes which are created "automatically"
               local bw, bh, bd = getwhd(s)
            for x in traverse(getvalue(wh)) do
               local x_dir = get_attr(x, attr_dir)
               if x_dir<dir_node_manual then
                  local info = dir_node_aux[s_dir][x_dir%dir_node_auto]
                  setwhd(x, info.width(bw,bh,bd), info.height(bw,bh,bd), info.depth(bw,bh,bd))
               end
            end
         end
         return true
      end
   end
   local function set_box_dim(key)
      local s = getbox(scan_int()); scan_keyword('=')
      if s then
         local l_dir = (get_dir_count())%dir_math_mod
         s = to_direct(s)
         local b_dir = get_box_dir(s,dir_yoko)
         if b_dir<dir_node_auto then
            set_box_dim_common(key, s, l_dir)
         elseif b_dir%dir_math_mod == l_dir then
            -- s is dir_node
            setfield(s, key, scan_dimen())
            if b_dir<dir_node_manual then
               set_attr(s, attr_dir, b_dir%dir_node_auto + dir_node_manual)
            end
         else
            local sid, b = getid(s), getlist(s)
            local info = dir_node_aux[get_box_dir(b,dir_yoko)%dir_math_mod][b_dir%dir_node_auto]
            local bw, bh, bd = getwhd(b)
            local sw, sh, sd = getwhd(s)
            if set_box_dim_common(key, b, l_dir) and b_dir<dir_node_manual then
               -- re-calculate dimension of s, if s is created "automatically"
               if b_dir<dir_node_manual then
                  setwhd(s, info.width(bw,bh,bd), info.height(bw,bh,bd), info.depth(bw,bh,bd))
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

do
   local getbox, setbox, copy_list = tex.getbox, tex.setbox, dnode.copy_list
   -- raise, lower
   function luatexja.direction.raise_box()
      start_time_measure 'box_primitive_hook'
      local list_dir = get_dir_count()
      local s = getbox 'ltj@afbox'
      if s then
         local sd = to_direct(s)
         local box_dir = get_box_dir(sd, dir_yoko)
         if box_dir%dir_math_mod ~= list_dir then
            setbox('ltj@afbox',
               to_node(copy_list(make_dir_whatsit(sd, sd, list_dir, 'box_move')))
               -- copy_list しないとリストの整合性が崩れる……？
            )
         end
      end
      stop_time_measure 'box_primitive_hook'
   end
end

-- PACKED の hbox から文字を取り出す
-- luatexja.jfmglue.check_box などで使用
do
   local function glyph_from_packed(h)
      local b = getlist(h)
      return (getid(b)==id_kern or (getid(b)==id_whatsit and getsubtype(b)==sid_save) )
         and node_next(node_next(node_next(b))) or b
   end
   luatexja.direction.glyph_from_packed = glyph_from_packed
end

-- adjust
do
   local id_adjust = node.id 'adjust'
   local last_node = dnode.last_node
   local scan_keyword = token.scan_keyword
   function luatexja.direction.adjust_begin()
      if scan_keyword 'pre' then tex.sprint(cat_lp, '\\ltj@@vadjust@pre')
      else tex.sprint(cat_lp, '\\ltj@@vadjust@post') end
   end
   function luatexja.direction.check_adjust_direction()
      start_time_measure 'box_primitive_hook'
      local list_dir = get_adjust_dir_count()
      local a = getnest().tail
      local ad = to_direct(a)
      if a and getid(ad)==id_adjust then
         local adj_dir = get_box_dir(ad)
         if list_dir~=adj_dir then
            ltjb.package_error(
               'luatexja',
               'Direction Incompatible',
               "\\vadjust's argument and outer vlist must have same direction.")
            node_free(last_node())
         end
      end
      stop_time_measure 'box_primitive_hook'
   end
end

-- insert
do
   local id_ins  = node.id 'ins'
   local id_rule = node.id 'rule'
   function luatexja.direction.populate_insertion_dir_whatsit()
      start_time_measure 'box_primitive_hook'
      local list_dir = get_dir_count()
      local a = getnest().tail
      local ad = to_direct(a)
      if (not a) or getid(ad)~=id_ins then
          a = node.tail(tex.lists.page_head); ad = to_direct(a)
      end
      if a and getid(ad)==id_ins then
         local h = getlist(ad)
         if getid(h)==id_whatsit and
            getsubtype(h)==sid_user and getfield(h, 'user_id')==DIR then
               local n = h; h = node_remove(h,h)
               node_free(n)
         end
         for box_rule, bi in traverse(h) do
            if bi<id_rule then
               h = insert_before(h, box_rule, dir_pool[list_dir]())
            end
         end
         ensure_tex_attr(attr_dir, 0)
         setlist(ad, h)
      end
      stop_time_measure 'box_primitive_hook'
   end
end

-- vsplit
do
   local split_dir_whatsit, split_dir_head, split_dir_at_2nd
   local cat_lp = luatexbase.catcodetables['latex-package']
   local sprint, scan_int, tex_getbox = tex.sprint, token.scan_int, tex.getbox
   function luatexja.direction.vsplit()
      local n = scan_int();
      local p = to_direct(tex_getbox(n))
      if split_dir_head then node_free(split_dir_head); split_dir_head = nil end
      if split_dir_whatsit then split_dir_watsit = nil end
      if p then
         local bh = getlist(p)
         if getid(bh)==id_whatsit and getsubtype(bh)==sid_user and getfield(bh, 'user_id')==DIR
            and node_next(bh) then
            ltjs.list_dir = get_attr(bh, attr_dir)
            setlist(p, (node_remove(bh,bh)))
            split_dir_head, split_dir_2nd = bh, false
         else
            local w = node_next(bh)
            if getid(w)==id_whatsit and getsubtype(w)==sid_user and getfield(w, 'user_id')==DIR then
               ltjs.list_dir = get_attr(w, attr_dir)
               setlist(p, (node_remove(bh,w)))
               split_dir_head, split_dir_2nd = w, true
            end
         end
      end
      sprint(cat_lp, '\\ltj@@orig@vsplit' .. tostring(n))
   end
   local function dir_adjust_vpack(h, gc)
      start_time_measure 'direction_vpack'
      local hd = to_direct(h)
      if gc=='split_keep' then
         -- supply dir_whatsit
         hd = create_dir_whatsit_vbox(hd, gc)
         split_dir_whatsit = hd
      elseif gc=='split_off'  then
         if split_dir_head then
            ltjs.list_dir = get_attr(split_dir_head, attr_dir)
            if split_dir_2nd then hd = insert_after(hd, hd, split_dir_head)
            else hd = insert_before(hd, hd, split_dir_head)
            end
            split_dir_head=nil
         end
         if split_dir_whatsit then
            -- adjust direction of 'split_keep'
            set_attr(split_dir_whatsit, attr_dir, ltjs.list_dir)
            split_dir_whatsit=nil
         end
      elseif gc=='preamble' then
         split_dir_whatsit=nil
      else
         adjust_badness(hd)
         -- hd = process_dir_node(create_dir_whatsit_vbox(hd, gc), gc)
         -- done in append_to_vpack callback
         hd = create_dir_whatsit_vbox(hd, gc)
         split_dir_whatsit=nil
      end
      stop_time_measure 'direction_vpack'
      return to_node(hd)
   end
   ltjb.add_to_callback('vpack_filter',
                        dir_adjust_vpack,
                        'ltj.direction', 10000)
end

do
   local function dir_adjust_pre_output(h, gc)
      return to_node(create_dir_whatsit_vbox(to_direct(h), gc))
   end
   ltjb.add_to_callback('pre_output_filter', dir_adjust_pre_output,
                        'ltj.direction', 10000)
end

-- append_to_vlist filter: done in ltj-lineskip.lua

-- finalize (executed just before \shipout)
-- we supply correct pdfsavematrix nodes etc. inside dir_node
do
   local finalize_inner
   local function finalize_dir_node(db,new_dir)
      local b = getlist(db)
      while b and ((getid(b)~=id_hlist) and (getid(b)~=id_vlist)) do
         local ob = b; b = node_remove(b,b); setlist(db, b);
         node_free(ob)
      end
      finalize_inner(b)
      local w, h, d = getwhd(b)
      local dw, dh, dd = getwhd(db)
      local db_head, db_tail
      local t = dir_node_aux[get_box_dir(b, dir_yoko)%dir_math_mod][new_dir]
      t = t and t[getid(b)]; if not t then return end
      for _,v in ipairs(t) do
         local nn = v[1](v[2], b, w, h, d, dw, dh, dd)
         if db_head then
            insert_after(db_head, db_tail, nn)
            db_tail = nn
         else
            setlist(db, nn)
            db_head, db_tail = nn, nn
         end
      end
   end

   tex.setattribute(attr_dir, dir_yoko)
   local shipout_temp =  node_new(id_hlist)
   dnode.setattributelist(shipout_temp, nil)
   tex.setattribute(attr_dir, 0)

   finalize_inner = function (box)
      for n, nid in traverse(getlist(box)) do
         if (nid==id_hlist or nid==id_vlist) then
            local ndir = get_box_dir(n, dir_yoko)
            if ndir>=dir_node_auto then -- n is dir_node
               finalize_dir_node(n, ndir%dir_math_mod)
            else
               finalize_inner(n)
            end
         end
      end
   end
   local copy = dnode.copy
   function luatexja.direction.shipout_lthook (head)
      start_time_measure 'box_primitive_hook'
      local a = to_direct(head)
      local a_dir = get_box_dir(a, dir_yoko)
      if a_dir~=dir_yoko then
         local b = create_dir_node(a, a_dir, dir_yoko, false)
         setlist(b, a); a = b
      end
      setlist(shipout_temp, a); finalize_inner(shipout_temp)
      a = copy(getlist(shipout_temp)); setlist(shipout_temp, nil)
      stop_time_measure 'box_primitive_hook'
      return to_node(a)
   end
end
