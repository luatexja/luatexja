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
local traverse_id = Dnode.traverse_id

local id_kern = node.id('kern')
local id_hlist = node.id('hlist')
local id_vlist = node.id('vlist')
local id_whatsit = node.id('whatsit')
local sid_save = node.subtype('pdf_save')
local sid_restore = node.subtype('pdf_restore')
local sid_matrix = node.subtype('pdf_setmatrix')
local sid_user = node.subtype('user_defined')

local PROCESSED    = luatexja.icflag_table.PROCESSED
local PACKED       = luatexja.icflag_table.PACKED
local DIR = luatexja.stack_table_index.DIR
local STCK = luatexja.userid_table.STCK
local wh_DIR = luatexja.userid_table.DIR
local dir_tate = 3
local dir_yoko = 4

-- \tate, \yoko
do
  local node_next = node.next
  local function set_list_direction(v, name)
    if node.next(tex.nest[tex.nest.ptr].head) then
      ltjb.package_error('luatexja',
			 "Use `\\" .. name .. "' at top of list",
			 'Direction change command by LuaTeX-ja is available\n'
			    .. 'only while current list is null.')
    else
       ltjs.set_stack_table(luatexja.stack_table_index.DIR, v, true)
    end
  end
  luatexja.direction.set_list_direction = set_list_direction
end

-- ボックスに dir whatsit を追加
do
   local tex_getcount = tex.getcount
   local function set_dir_flag(h, gc)
      if gc=='fin_row' or gc == 'preamble'  then
	 return h
      else
	 local hd, new_dir = to_direct(h), ltjs.table_current_stack[DIR]
	 local w
	 if hd and getid(hd)==id_whatsit and getsubtype(hd)==sid_user
	 and getfield(hd, 'user_id')==wh_DIR then
	    w = hd
	 else
	    w = node_new(id_whatsit, sid_user)
	    setfield(w, 'next', hd)
	 end
	 setfield(w, 'user_id', wh_DIR)
	 setfield(w, 'type', 100)
	 setfield(w, 'value', new_dir)
	 return to_node(w)
      end
   end
   luatexbase.add_to_callback('hpack_filter', set_dir_flag, 'ltj.set_dir_flag', 10000)
   luatexbase.add_to_callback('vpack_filter',
			      function (h, gc)
				 local box_set, cl = 0, tex.currentgrouplevel + 1
				 local hd = to_direct(h)
				 for w in traverse_id(id_whatsit, hd) do
				    if getsubtype(w)==sid_user and
				    getfield(w, 'user_id')==STCK and
				    getfield(w, 'value')==cl then box_set = 1;
				       hd = node_remove(hd, w); node_free(w); break
				    end
				 end
				ltjs.report_stack_level(tex_getcount('ltj@@stack') + box_set)
				return set_dir_flag(to_node(hd), gc)
			      end, 'ltj.set_dir_flag', 1)
   luatexbase.add_to_callback('post_linebreak_filter',
			      function (h)
				 local new_dir = ltjs.table_current_stack[DIR]
				 for line in traverse_id(id_hlist, to_direct(h)) do
				    set_attr(line, attr_dir, new_dir)
				 end
				 return set_dir_flag(h, tostring(gc))
			      end, 'ltj.set_dir_flag', 100)

end



local make_dir_node
do
   local get_h =function (w,h,d) return h end
   local get_d =function (w,h,d) return d end
   local get_h_d =function (w,h,d) return h+d end
   local get_h_neg =function (w,h,d) return -h end
   local get_d_neg =function (w,h,d) return -d end
   local get_w_half =function (w,h,d) return 0.5*w end
   local get_w_neg_half =function (w,h,d) return -0.5*w end
   local get_w_neg =function (w,h,d) return -w end
   local get_w =function (w,h,d) return w end
   local dir_node_aux = {
      [dir_yoko] = { -- yoko を tate 中で組む
	 width  = get_h_d,
	 height = get_w_half,
	 depth  = get_w_half,
	 [id_hlist] = {
	    { 'kern', get_h },
	    { 'whatsit', sid_save },
	    { 'rotate', '0 1 -1 0' },
	    { 'kern', get_w_neg_half },
	    { 'box' },
	    { 'kern', get_w_neg_half },
	    { 'whatsit', sid_restore },
	 },
	 [id_vlist] = {
	    { 'kern', get_w},
	    { 'whatsit', sid_save },
	    { 'rotate', '0 1 -1 0' },
	    { 'box' },
	    { 'kern', get_h_neg},
	    { 'whatsit', sid_restore },
	 },
      },
      [dir_tate] = { -- tate を yoko 中で組む
	 width  = get_h_d,
	 height = get_w,
	 depth  = function() return 0 end,
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
   }

   clean_dir_whatsit = function(b)
      local bh = getlist(b)
      local dir
      for x in traverse_id(id_whatsit, bh) do
	 if getsubtype(bh)==sid_user and getfield(bh, 'user_id')==wh_DIR then
	     setfield(b, 'head', (node_remove(bh, x)))
	     dir = getfield(bh, 'value')
	     set_attr(b, attr_dir, dir)
	     set_attr(b, attr_icflag, PROCESSED)
	     node_free(x); break
	 end
      end
      return dir
   end
   luatexja.direction.clean_dir_whatsit = clean_dir_whatsit
   make_dir_node = function (head, b, new_dir, origin)
      -- head: list head, b: box
      -- origin: コール元 (for debug)
      -- return value: (new head), (next of b), (new b), (is_b_dir_node)
      -- (new b): b か dir_node に被せられた b
      local old_dir
      local bh = getlist(b)
      for x in traverse_id(id_whatsit, bh) do
	 if getsubtype(bh)==sid_user and getfield(bh, 'user_id')==wh_DIR then
	     old_dir = getfield(bh, 'value')
	     set_attr(b, attr_dir, old_dir)
	     setfield(b, 'head', (node_remove(bh, x)))
	     set_attr(b, attr_icflag, PROCESSED)
	     node_free(x); break
	 end
      end
      if not old_dir then
	 old_dir = has_attr(b, attr_dir) or dir_yoko
	 if old_dir==0 then old_dir =dir_yoko end
      end
      if old_dir==new_dir then
	 set_attr(b, attr_icflag, PROCESSED)
	 return head, node_next(b), b, false
      elseif  -old_dir == new_dir  then
	 return head, node_next(b), b, true
      else
	 local nh, nb, ret, flag
	 if old_dir < 0 then
	    -- b itself is a dir node; just unwrap
	    local bc = node_next(node_next(
				    node_next(node_next(bh))))
	    node_remove(bh, bc);
	    nh, nb =  insert_before(head, b, bc), nil
	    nh, nb = node_remove(head, b)
	    setfield(b, 'next', nil); Dnode.flush_list(b)
	    ret, flag = bc, false
	 else
	    local bid = getid(b)
	    local db = node_new(bid) -- dir node
	    nh, nb =  insert_before(head, b, db), nil
	    nh, nb = node_remove(nh, b)
	    local w = getfield(b, 'width')
	    local h = getfield(b, 'height')
	    local d = getfield(b, 'depth')
	    local info = dir_node_aux[old_dir]
	    set_attr(db, attr_dir, -new_dir)
	    set_attr(b, attr_icflag, PROCESSED)
	    set_attr(db, attr_icflag, PROCESSED)
	    setfield(db, 'dir', getfield(b, 'dir'))
	    setfield(db, 'shift', 0)
	    setfield(db, 'width',  info.width(w,h,d))
	    setfield(db, 'height', info.height(w,h,d))
	    setfield(db, 'depth',  info.depth(w,h,d))
	    local db_head, db_tail  = nil
	    for _,v in ipairs(info[bid]) do
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
      local h = to_direct(head)
      local x, new_dir = h, ltjs.table_current_stack[DIR] or dir_yoko
      while x do
	 local xid = getid(x)
	 if (xid==id_hlist and has_attr(x, attr_icflag)~=PACKED) or xid==id_vlist then
	    h, x = make_dir_node(h, x, new_dir, 'process_dir_node:' .. gc)
	 else
	    x = node_next(x)
	 end
      end
      return to_node(h)
   end
   luatexja.direction.make_dir_node = make_dir_node
   luatexbase.add_to_callback('vpack_filter',
			      process_dir_node, 'ltj.dir_node', 10001)
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

