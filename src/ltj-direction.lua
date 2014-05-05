--
-- src/ltj-direction.lua
--

luatexja.load_module('base');      local ltjb = luatexja.base
luatexja.load_module('stack');     local ltjs = luatexja.stack
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
local wh_DIR = luatexja.userid_table.DIR
local dir_tate = 3
local dir_yoko = 4

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

do 
   local tex_getcount = tex.getcount
   local function set_dir_flag(h)
      local new_dir = ltjs.table_current_stack[DIR]
      local w = node_new(id_whatsit, sid_user)
      setfield(w, 'user_id', wh_DIR)
      setfield(w, 'type', 100)
      setfield(w, 'value', new_dir)
      setfield(w, 'next', to_direct(h))
      return to_node(w)
   end
   luatexbase.add_to_callback('hpack_filter', set_dir_flag, 'ltj.set_dir_flag', 10000)
   luatexbase.add_to_callback('vpack_filter', 
			      function (h)
				 local box_set, cl = 0, tex.currentgrouplevel + 1
				 for w in traverse_id(id_whatsit, to_direct(h)) do
				    if getfield(w, 'value')==cl then box_set = 1; break end
				 end
				 ltjs.report_stack_level(tex_getcount('ltj@@stack') + box_set)
				 return set_dir_flag(h)
			      end, 'ltj.set_dir_flag', 1)
   luatexbase.add_to_callback('post_linebreak_filter', 
			      function (h)
				 local new_dir = ltjs.table_current_stack[DIR]
				 for line in traverse_id(id_hlist, to_direct(h)) do
				    set_attr(line, attr_dir, new_dir)
				 end
				 return h
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

   make_dir_node = function (head, b, new_dir)
      -- head: list head, b: box
      -- return value: (new head), (next of b), (new b), (is_b_dir_node)
      -- (new b): b か dir_node に被せられた b
      local old_dir
      local bh = getlist(b)
      if bh and getid(bh)==id_whatsit and getsubtype(bh)==sid_user
          and getfield(bh, 'user_id')==wh_DIR then
	     old_dir = getfield(bh, 'value')
	     setfield(b, 'head', node_next(bh))
	    set_attr(b, attr_icflag, PROCESSED)
	     node_free(bh)
	     print('FROM WHATSit')
      else
	 old_dir = has_attr(b, attr_dir)
	 if old_dir==0 then old_dir =4 end
      end
      print(old_dir, new_dir)
      if old_dir==new_dir  then 
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
   local function process_dir_node(head)
      local h = to_direct(head)
      local x, new_dir = h, ltjs.table_current_stack[DIR]
      while x do
	 local xid = getid(x)
	 if (xid==id_hlist and has_attr(x, attr_icflag)~=PACKED) or xid==id_vlist then
	    h, x = make_dir_node(h, x, new_dir)
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
