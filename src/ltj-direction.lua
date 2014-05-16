--
-- src/ltj-direction.lua
--

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('stack');     local ltjs = luatexja.stack
luatexja.load_module('rmlgbm');    local ltjr = luatexja.rmlgbm
luatexja.direction = {}

local attr_dir = luatexbase.attributes['ltj@dir']
local attr_icflag = luatexbase.attributes['ltj@icflag']

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

local id_kern = node.id('kern')
local id_hlist = node.id('hlist')
local id_vlist = node.id('vlist')
local id_whatsit = node.id('whatsit')
local sid_save = node.subtype('pdf_save')
local sid_restore = node.subtype('pdf_restore')
local sid_matrix = node.subtype('pdf_setmatrix')
local sid_user = node.subtype('user_defined')

local PROCESSED    = luatexja.icflag_table.PROCESSED
local PROCESSED_BEGIN_FLAG = luatexja.icflag_table.PROCESSED_BEGIN_FLAG
local PACKED       = luatexja.icflag_table.PACKED
local STCK = luatexja.userid_table.STCK
local DIR  = luatexja.userid_table.DIR
local dir_tate = luatexja.dir_table.dir_tate
local dir_yoko = luatexja.dir_table.dir_yoko
local dir_dtou = luatexja.dir_table.dir_dtou


local get_dir_count 
do
   local gc = tex.getcount
   get_dir_count = function() return gc('ltj@dir@count') end
end
luatexja.direction.get_dir_count = get_dir_count 

-- \tate, \yoko
do
  local node_next = node.next
  local node_set_attr = node.set_attribute
  local function set_list_direction(v, name)
     local lv, w = tex.nest[tex.nest.ptr], tex.lists.page_head
     if lv.mode == 1 and w then
        if w.id==id_whatsit and w.subtype==sid_user
        and w.user_id==DIR then
	   node_set_attr(w, attr_dir, v)
	   
        end
     else
        local w = node_next(to_direct(lv.head))
        if to_node(w) then
           if getid(w)==id_whatsit and getsubtype(w)==sid_user
           and getfield(w, 'user_id')==DIR  then
	      set_attr(w, attr_dir, v)
	      tex.setattribute('global', attr_dir, 0)  
	   else
              ltjb.package_error(
                 'luatexja',
                 "Use `\\" .. name .. "' at top of list",
                 'Direction change command by LuaTeX-ja is available\n'
                 .. 'only while current list is null.')
           end
        else
           local w = node_new(id_whatsit, sid_user)
           setfield(w, 'next', hd)
           setfield(w, 'user_id', DIR)
           setfield(w, 'type', 110)
           set_attr(w, attr_dir, v)
           Dnode.write(w)
	   tex.setattribute('global', attr_dir, 0)
        end
	tex.setattribute('global', attr_icflag, 0)
     end
  end
  luatexja.direction.set_list_direction = set_list_direction
end

-- ボックスに dir whatsit を追加
local function create_dir_whatsit(hd, gc, new_dir)
      local w = node_new(id_whatsit, sid_user)
      setfield(w, 'next', hd)
      setfield(w, 'user_id', DIR)
      setfield(w, 'type', 110)
      set_attr(w, attr_dir, new_dir)
      tex.setattribute('global', attr_dir, 0)  
      set_attr(w, attr_icflag, PROCESSED_BEGIN_FLAG)
      set_attr(hd, attr_icflag, (has_attr(hd, attr_icflag) or 0) + PROCESSED_BEGIN_FLAG)
      tex.setattribute('global', attr_icflag, 0)
      return w
end

-- hpack_filter, vpack_filter, post_line_break_filter
-- の結果を組方向を明示するため，先頭に dir_node を設置
do
   local tex_getcount = tex.getcount
   local function create_dir_whatsit_hpack(h, gc)
      local hd = to_direct(h)
      if gc=='fin_row' or gc == 'preamble'  then
	 if hd  then
	    set_attr(hd, attr_icflag, PROCESSED_BEGIN_FLAG)
	    tex.setattribute('global', attr_icflag, 0)
	 end
	 return h
      else
	 return to_node(create_dir_whatsit(hd, gc, ltjs.list_dir))
      end
   end

   luatexbase.add_to_callback('hpack_filter', 
			      create_dir_whatsit_hpack, 'ltj.create_dir_whatsit', 10000)

   local function create_dir_whatsit_vbox(h, gc)
      local hd= to_direct(h)
      ltjs.list_dir = get_dir_count()
      if getid(hd)==id_whatsit and getsubtype(hd)==sid_user
      and getfield(hd, 'user_id')==DIR then
         ltjs.list_dir = has_attr(hd, attr_dir)
         return h
      elseif gc=='fin_row' or gc == 'preamble'  then
	 if hd  then
	    set_attr(hd, attr_icflag, PROCESSED_BEGIN_FLAG)
	    tex.setattribute('global', attr_icflag, 0)
	 end
	 return h
      else
         return to_node(create_dir_whatsit(hd, gc, ltjs.list_dir))
      end
   end
   luatexbase.add_to_callback('vpack_filter', 
			      create_dir_whatsit_vbox, 'ltj.create_dir_whatsit', 1)

   local function create_dir_whatsit_parbox(h, gc)
      stop_time_measure('tex_linebreak')
      -- start 側は ltj-debug.lua に
      local new_dir, hd = ltjs.list_dir, to_direct(h)
      for line in traverse_id(id_hlist, hd) do
	 set_attr(line, attr_dir, new_dir)
      end
      return to_node(create_dir_whatsit(hd, gc, new_dir))
   end
   luatexbase.add_to_callback('post_linebreak_filter',
			      create_dir_whatsit_parbox, 'ltj.create_dir_whatsit', 10000)

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
	       { 'box' },
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
	       { 'kern', get_d },
	       { 'whatsit', sid_save },
	       { 'rotate', '0 -1 1 0' },
	       { 'kern', get_w_neg },
	       { 'box' },
	       { 'whatsit', sid_restore },
	    },
	    [id_vlist] = {
	       { 'whatsit', sid_save },
	       { 'rotate', '0 -1 1 0' },
	       { 'kern', get_h_neg },
	       { 'kern', get_d_neg },
	       { 'box' },
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
	       { 'box' },
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
      },
      [dir_dtou] = { -- dtou を
	 [dir_yoko] = { -- yoko 中で組む
	    width  = get_h_d,
	    height = zero,
	    depth  = get_w,
	    [id_hlist] = {
	       { 'kern', get_h },
	       { 'whatsit', sid_save },
	       { 'rotate', '0 1 -1 0' },
               { 'kern', get_w_neg },
	       { 'box' },
	       { 'whatsit', sid_restore },
	    },
	    [id_vlist] = {
               { 'kern', get_w },
	       { 'whatsit', sid_save },
	       { 'rotate', '0 1 -1 0' },
	       { 'box' },
	       { 'kern', get_h_neg },
	       { 'kern', get_d_neg },
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
	       { 'box' },
	       { 'whatsit', sid_restore },
	    },
	    [id_vlist] = {-- TODO
	       { 'whatsit', sid_save },
	       { 'rotate', ' -1 0 0 -1' },
	       { 'kern', get_h_d_neg }, 
	       { 'box', get_w_neg },
	       { 'whatsit', sid_restore },
	    },
	 },
      },
   }
end

-- b に DIR whatsit があればその内容を attr_dir にうつす (1st ret val)
-- 2nd ret val はその DIR whatsit
local function get_box_dir(b, default)
   local dir = has_attr(b, attr_dir) or 0
   local bh = getlist(b)
   local c
   if bh and getid(bh)==id_whatsit
   and getsubtype(bh)==sid_user and getfield(bh, 'user_id')==DIR then
     c = bh
      if dir==0 then
	 dir = has_attr(bh, attr_dir)
	 set_attr(b, attr_dir, dir)
	 tex.setattribute('global', attr_dir, 0)
      end
   end
   return (dir==0 and default or dir), c
end

-- dir_node に包まれている「本来の中身」を取り出し，
-- dir_node 自体は DIR whatsit にカプセル化する
local function unwrap_dir_node(b, head)
   -- head: nil or nil-nil
   -- if head is non-nil, return values are (new head), (next of b), (contents)
   local bh = getlist(b)
   local bc = node_next(node_next(node_next(node_next(bh))))
   local nh, nb
   node_remove(bh, bc); 
   if head then
      nh = insert_before(head, b, bc)
      nh, nb = node_remove(nh, b)
   end
   setfield(b, 'list', nil); Dnode.flush_list(bh)
   local d, wh = get_box_dir(bc, 0)
   if not wh then
      wh = create_dir_whatsit(getlist(bc), 'unwrap', d)
      setfield(bc, 'head', wh)
   end
   local h = getfield(wh, 'value')
   if h then setfield(b, 'next', h) end
   setfield(wh, 'value', to_node(b))
   return nh, nb, bc
end

local function create_dir_node(b, b_dir, new_dir)
   local info = dir_node_aux[b_dir][new_dir]
   local w = getfield(b, 'width')
   local h = getfield(b, 'height')
   local d = getfield(b, 'depth')
   local db = node_new(getid(b))
   set_attr(db, attr_dir, -new_dir)
   set_attr(db, attr_icflag, PROCESSED)
   set_attr(b, attr_icflag, PROCESSED)
   setfield(db, 'dir', getfield(b, 'dir'))
   setfield(db, 'shift', 0)
   setfield(db, 'width',  info.width(w,h,d))
   setfield(db, 'height', info.height(w,h,d))
   setfield(db, 'depth',  info.depth(w,h,d))
   return db
end

-- 異方向のボックスの処理
local make_dir_whatsit
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
	 return head, node_next(b), b, false
      elseif  -box_dir == new_dir  then
	 return head, node_next(b), b, true
      else
         local nh, nb, ret, flag
	 if box_dir < 0 then -- unwrap
            nh, nb, ret = unwrap_dir_node(b,head)
            flag = false
         else
            local db
            local dnh = getfield(dn, 'value')
            for x in traverse(dnh) do
               if has_attr(x, attr_dir) == -new_dir then
                  setfield(dn, 'value', to_node(node_remove(dnh, x)))
                  db=x; break
               end
            end
            db = db or create_dir_node(b, box_dir, new_dir)
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
                  if arg then setfield(nn, 'shift', arg(w,h,d)) end
               end
               if db_head then
                  insert_after(db_head, db_tail, nn)
                  db_tail = nn
	       else
		  db_head, db_tail = nn, nn
	       end
	    end
	    setfield(db, 'head', db_head)
	    ret, flag = db, true
	 end
	 return nh, nb, ret, flag
      end
   end
   local function process_dir_node(head, gc)
      start_time_measure('direction_vpack')
      local h = to_direct(head)
      local x, new_dir = h, ltjs.list_dir or dir_yoko
      while x do
	 local xid = getid(x)
	 if (xid==id_hlist and has_attr(x, attr_icflag)%PROCESSED_BEGIN_FLAG~=PACKED) 
	 or xid==id_vlist then
	    h, x = make_dir_whatsit(h, x, new_dir, 'process_dir_node:' .. gc)
	 else
	    x = node_next(x)
	 end
      end
      stop_time_measure('direction_vpack')
      return to_node(h)
   end
   luatexja.direction.make_dir_whatsit = make_dir_whatsit
   luatexbase.add_to_callback('vpack_filter',
			      process_dir_node, 'ltj.dir_whatsit', 10001)
end

-- \wd, \ht, \dp の代わり
do
   local getbox = tex.getbox
   local function get_box_dim_common(key, s, l_dir)
      local s_dir, wh = get_box_dir(s, dir_yoko)
      if s_dir ~= l_dir then
         local not_found = true
         for x in traverse(getfield(wh, 'value')) do
            if l_dir == -has_attr(x, attr_dir) then
               tex.setdimen('ltj@tempdima', getfield(x, key))
               not_found = false; break
            end
         end
         if not_found then
            local w = getfield(s, 'width')
            local h = getfield(s, 'height')
            local d = getfield(s, 'depth')
            tex.setdimen('ltj@tempdima', 
                         dir_node_aux[s_dir][l_dir][key](w,h,d))
         end
      else
         tex.setdimen('ltj@tempdima', getfield(s, key))
      end
   end
   local function get_box_dim(key, n)
      local gt = tex.globaldefs; tex.globaldefs = 0
      local s = getbox(n)
      if s then
         local l_dir = get_dir_count()
         s = to_direct(s)
         local b_dir = has_attr(s, attr_dir) or 0
         if b_dir>=0 then
            get_box_dim_common(key, s, l_dir)
         elseif b_dir==-l_dir then -- dir_node case 1
            tex.setdimen('ltj@tempdima', getfield(s, key))
         else
            get_box_dim_common(
               key, 
               node_next(node_next(node_next(node_next(getlist(s))))),
               l_dir)
         end
      else
         tex.setdimen('ltj@tempdima', 0)
      end
      tex.globaldefs = gt
   end
   luatexja.direction.get_box_dim = get_box_dim

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
            if has_attr(x, attr_dir)==-l_dir then
               db = x; break
            end
         end
         if not db then
            db = create_dir_node(s, s_dir, l_dir)
            setfield(db, 'next', dnh)
            setfield(wh, 'value',to_node(db))
         end
         setfield(db, key, tex.getdimen('ltj@tempdima'))
      else
         setfield(s, key, tex.getdimen('ltj@tempdima'))
      end
   end
   local function set_box_dim(key)
      local n = tex.getcount('ltj@tempcnta')
      local s = getbox(n)
      if s then
	 local l_dir = get_dir_count()
	 s = to_direct(s)
         local b_dir = has_attr(s, attr_dir) or 0
         if b_dir>=0 then
            set_box_dim_common(key, s, l_dir)
            elseif b_dir == -l_dir then
               setfield(s, key, tex.getdimen('ltj@tempdima'))
         else
            set_box_dim_common(
               key, 
               node_next(node_next(node_next(node_next(getlist(s))))),
               l_dir)
         end
      end
   end
   luatexja.direction.set_box_dim = set_box_dim
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
