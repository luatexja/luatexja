--
-- ltj-lineskip.lua
--
luatexja.load_module 'base'; local ltjb = luatexja.base
luatexja.load_module 'direction'; local ltjd = luatexja.direction
luatexja.lineskip = luatexja.lineskip or {}

local to_direct = node.direct.todirect
local ltjl = luatexja.lineskip
local id_glue    = node.id 'glue'
local id_penalty = node.id 'penalty'
local id_hlist   = node.id 'hlist'
local setfield = node.direct.setfield
local getfield = node.direct.getfield
local getlist = node.direct.getlist
local node_new = node.direct.new
local node_prev = node.direct.getprev
local node_next = node.direct.getnext
local getid = node.direct.getid
local getsubtype = node.direct.getsubtype

local node_getglue = node.getglue
local setglue = node.direct.setglue
local function copy_glue (new_glue, old_glue, subtype, new_w)
   setfield(new_glue, 'subtype', subtype)
   local w,st,sp,sto,spo = node_getglue(old_glue)
   setglue(new_glue, new_w or w, st, sp, sto, spo)
end
ltjl.copy_glue = copy_glue

function ltjl.p_dummy(before, after)
   return nil, 0
end
function ltjl.l_dummy(dist, g, adj, normal, bw, loc)
   if dist < tex.lineskiplimit then
      copy_glue(g, tex.lineskip, 1, tex.lineskip.width + adj)
   else
      copy_glue(g, tex.baselineskip, 2, normal)
   end
end

local ltj_profiler, ltj_skip = ltjl.p_dummy, ltjl.l_dummy
function ltjl.setting(profiler, skip_method)
   ltj_profiler = ltjl['p_'..tostring(profiler)] or ltjl.p_dummy
   ltj_skip = ltjl['l_'..tostring(skip_method)] or ltjl.l_dummy
end

do
local traverse_id = node.direct.traverse_id
local function adjust_glue(nh)
   local h = to_direct(nh)
   local bw = tex.baselineskip.width
   for x in traverse_id(id_glue, h) do
     local xs = getsubtype(x)
     if (xs==1) or (xs==2) then
        local p, n = node_prev(x), node_next(x)
        if p then
        local pid = getid(p)
           while (id_glue<=pid) and (pid<=id_penalty) and node_prev(p) do 
             p = node_prev(p); pid = getid(p)
           end
           if pid==id_hlist and getid(n)==id_hlist then
             local normal = bw - getfield(p, 'depth') - getfield(n, 'height')
             local lmin, adj = ltj_profiler(p, n, false, bw)
             ltj_skip(lmin or normal, x, adj, normal, bw)
           end
        end
     end
   end
   return true
end
ltjb.add_to_callback('post_linebreak_filter', adjust_glue, 'ltj.lineskip', 10000)
end

do
local p_dummy = ltjl.p_dummy
local make_dir_whatsit = luatexja.direction.make_dir_whatsit
local get_dir_count = luatexja.direction.get_dir_count
local node_write = node.direct.write

local function dir_adjust_append_vlist(b, loc, prev, mirrored)
   local old_b = to_direct(b)
   local new_b = loc=='box' and 
      make_dir_whatsit(old_b, old_b, get_dir_count(), 'append_vlist') or old_b
   if prev > -65536000 then
      local bw = tex.baselineskip.width
      local normal = bw - prev - getfield(new_b, mirrored and 'depth' or 'height')
      local lmin, adj = nil, 0
      local tail = to_direct(tex.nest[tex.nest.ptr].tail)
      if p_dummy~=ltj_profiler then
         while tail and (id_glue<=getid(tail)) and (getid(tail)<=id_penalty) do
            tail = node_prev(tail)
         end
      end
      if tail then
         if getid(tail)==id_hlist and getid(new_b)==id_hlist then
            if getfield(tail, 'depth')==prev then 
               lmin, adj = ltj_profiler(tail, new_b, mirrored, bw)
            end
         end
      end
      local g = node_new(id_glue)
      ltj_skip(lmin or normal, g, adj, normal, bw, loc); node_write(g)
   end
   node_write(new_b)
   tex.prevdepth = getfield(new_b, mirrored and 'height' or 'depth')
   return nil -- do nothing on tex side
end
ltjb.add_to_callback('append_to_vlist_filter', dir_adjust_append_vlist, 'ltj.lineskip', 10000)
end

