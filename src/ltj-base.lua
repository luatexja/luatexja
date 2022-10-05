--
-- ltj-base.lua
--
local ltb = luatexbase
local tostring = tostring
local node, table, tex, token = node, table, tex, token

local cat_lp = luatexbase.catcodetables['latex-package']

--------------------
local ltjb = {}
luatexja.base = ltjb

local public_name = 'luatexja'
local public_version = 'alpha'
ltjb.public_name = public_name
ltjb.public_version = public_version


-------------------- Fully-expandable error messaging
local _error_set_break, _error_set_message, _error_show
local generic_error, _generic_warn_info
local generic_warning, generic_warning_no_line
local generic_info, generic_info_no_line
local package_error, package_warning, package_warning_no_line
local package_info, package_info_no_line
local ltj_error, ltj_warning_no_line

do
--! LaTeX 形式のエラーメッセージ(\PackageError 等)を
--! Lua 関数の呼び出しで行う.

  local LF, BEL = "\n", "\a"
  local err_main = ""
  local err_help = ""

  local function message_cont(str, c)
    return str:gsub(LF, LF .. c)
  end
  local function into_lines(str)
    return str:explode(LF)
  end

  _error_set_message = function (msgcont, main, help)
    err_main = message_cont(main, msgcont):gsub(BEL, LF)
    err_help = (help and help~="") and into_lines(help)
       or {"Sorry, I don't know how to help in this situation.",
           "Maybe you should try asking a human?" }
  end

  _error_show = function (escchar)
    local escapechar = tex.escapechar
    local newlinechar = tex.newlinechar
    local errorcontextlines = tex.errorcontextlines
    if not escchar then tex.escapechar = -1 end
    tex.newlinechar = 10
    tex.errorcontextlines = -1
    tex.error(err_main, err_help)
    tex.escapechar = escapechar
    tex.newlinechar = newlinechar
    tex.errorcontextlines = errorcontextlines
  end

  local message_a = "Type  H <return>  for immediate help"

  generic_error = function (msgcont, main, ref, help)
    local mainref = main..".\a\a"..ref..BEL..message_a
    _error_set_message(msgcont, mainref, help)
    _error_show(true)
  end

  _generic_warn_info = function (msgcont, main, warn, line)
    local mainc = message_cont(main, msgcont)
    local br = warn and "\n" or ""
    local out = warn and "term and log" or "log"
    local on_line = line and (" on input line "..tex.inputlineno) or ""
    local newlinechar = tex.newlinechar
    tex.newlinechar = -1
    texio.write_nl(out, br..mainc..on_line.."."..br)
    tex.newlinechar = newlinechar
  end

  generic_warning = function (msgcont, main)
    _generic_warn_info(msgcont, main, true, true)
  end
  generic_warning_no_line = function (msgcont, main)
    _generic_warn_info(msgcont, main, true, false)
  end
  generic_info = function (msgcont, main)
    _generic_warn_info(msgcont, main, false, true)
  end
  generic_info_no_line = function (msgcont, main)
    _generic_warn_info(msgcont, main, false, false)
  end

  package_error = function (pkgname, main, help)
    generic_error("("..pkgname..")                ",
      "Package "..pkgname.." Error: "..main,
      "See the "..pkgname.." package documentation for explanation.",
      help)
  end
  package_warning = function (pkgname, main)
    generic_warning("("..pkgname..")                ",
      "Package "..pkgname.." Warning: "..main)
  end
  package_warning_no_line = function (pkgname, main)
    generic_warning_no_line("("..pkgname..")                ",
      "Package "..pkgname.." Warning: "..main)
  end
  package_info = function (pkgname, main)
    generic_info("("..pkgname..")             ",
      "Package "..pkgname.." Info: "..main)
  end
  package_info_no_line = function (pkgname, main)
    generic_info_no_line("("..pkgname..")             ",
      "Package "..pkgname.." Info: "..main)
  end

  ltj_error = function (main, help)
    package_error(public_name, main, help)
  end
  ltj_warning_no_line = function (main)
    package_warning_no_line(public_name, main, help)
  end

end
-------------------- TeX stream I/O
--! ixbase.print() と同じ
--- Extension to tex.print(). Each argument string may contain
-- newline characters, in which case the string is output (to
-- TeX input stream) as multiple lines.
-- @param ... (string) string to output
local function mprint(...)
   local arg = {...}
   local lines = {}
   if type(arg[1]) == "number" then
      table.insert(lines, arg[1])
      table.remove(arg, 1)
   end
   for _, cnk in ipairs(arg) do
      local ls = cnk:explode("\n")
      if ls[#ls] == "" then
	 table.remove(ls, #ls)
      end
      for _, l in ipairs(ls) do
	 table.insert(lines, l)
      end
   end
   return tex.print(unpack(lines))
end
ltjb.mprint = mprint

-------------------- Handling of TeX values
do

--! ixbase.to_dimen() と同じ
  local function to_dimen(val)
    if val == nil then
      return 0
    elseif type(val) == "number" then
      return val
    else
      return tex.sp(tostring(val))
    end
  end

  local function parse_dimen(val)
    val = tostring(val):lower()
    local r, fil = val:match("([-.%d]+)fi(l*)")
    if r then
      val, fil = r.."pt", fil:len() + 1
    else
      fil = 0
    end
    return tex.sp(val), fil
  end

  ltjb.to_dimen = to_dimen
end

-------------------- Virtual table for LaTeX counters
-- not used in current LuaTeX-ja
do
--! ixbase.counter と同じ
  local counter = {}
  local mt_counter = {}
  setmetatable(counter, mt_counter)

  function mt_counter.__index(tbl, key)
    return tex.count['c@'..key]
  end
  function mt_counter.__newindex(tbl, key, val)
    tex.count['c@'..key] = val
  end
  ltjb.counter = counter

--! ixbase.length は tex.skip と全く同じなので不要.
end

-------------------- common error message
do
   local function in_unicode(c, admit_math)
      local low = admit_math and -1 or 0
      if type(c)~='number' or c<low or c>0x10FFFF then
	 local s = 'A character number must be between ' .. tostring(low)
	    .. ' and 0x10ffff.\n'
	    .. (admit_math and "(-1 is used for denoting `math boundary')\n" or '')
	    .. 'So I changed this one to zero.'
	 package_error('luatexja',
			    'bad character code (' .. tostring(c) .. ')', s)
	 c=0
      end
      return c
   end
   ltjb.in_unicode = in_unicode
end

-------------------- cache management
-- load_cache (filename, outdate)
--   * filename: without suffix '.lua'
--   * outdate(t): return true iff the cache is outdated
--   * return value: non-nil iff the cache is up-to-date
-- save_cache (filename, t): no return value
-- save_cache_luc (filename, t): no return value
--   save_cache always calls save_cache_luc.
--   But sometimes we want to create only the precompiled cache,
--   when its 'text' version is already present in LuaTeX-ja distribution.

if not os.type then require'lualibs-os' end
if not string.split then  require'lualibs-lpeg' end
if not gzip then
  if kpse.find_file('lualibs-util-zip', 'lua') then require'lualibs-util-zip' 
  else require'lualibs-gzip' end
end

do
   local kpse_var_value = kpse.var_value
   local path, pathtmp = kpse_var_value("TEXMFVAR")
   pathtmp = kpse_var_value("TEXMFSYSVAR")
   if pathtmp then path = (path and path .. ';' or '') .. pathtmp end
   pathtmp = kpse_var_value("TEXMFCACHE")
   if pathtmp then path = (path and path .. ';' or '') .. pathtmp end

   if os.type~='windows' then path = string.gsub(path, ':', ';') end
   path = table.unique(string.split(path, ';'))

   local cache_dir = '/luatexja'
   local find_file = kpse.find_file
   local join, isreadable = file.join, file.isreadable
   local tofile, serialize = table.tofile, table.serialize
   local luc_suffix = jit and '.lub' or '.luc'
   local dump = string.dump

   -- determine save path
   local savepath = ''
   for _,v in pairs(path) do
      local testpath =  join(v, cache_dir)
      if not lfs.isdir(testpath) then dir.mkdirs(testpath) end
      if lfs.isdir(testpath) then savepath = testpath; break end
   end
   local serial_spec = {functions=false, noquotes=true}

   local function remove_file_if_exist(name)
     if os.rename(name,name) then os.remove(name) end
   end
   local function remove_cache (filename)
      local fullpath_wo_ext = savepath .. '/' ..  filename .. '.lu'
      remove_file_if_exist(fullpath_wo_ext .. 'a')
      remove_file_if_exist(fullpath_wo_ext .. 'a.gz')
      remove_file_if_exist(fullpath_wo_ext .. 'b')
      remove_file_if_exist(fullpath_wo_ext .. 'c')
   end

   local function save_cache_luc(filename, t, serialized)
      local fullpath = savepath .. '/' ..  filename .. luc_suffix
      local s = serialized or serialize(t, 'return', false, serial_spec)
      if s then
	 local sa = load(s)
	 local f = io.open(fullpath, 'wb')
	 if f and sa then
	    f:write(dump(sa, true))
	    texio.write('log', '(save cache: ' .. fullpath .. ')')
            f:close()
	 end
      end
   end

   local function save_cache(filename, t)
      local fullpath = savepath .. '/' ..  filename .. '.lua.gz'
      local s = serialize(t, 'return', false, serial_spec)
      if s then
         gzip.save(fullpath, s, 1)
         texio.write('log', '(save cache: ' .. fullpath .. ')')
         save_cache_luc(filename, t, s)
      end
   end

   local function load_cache_a(filename, outdate, compressed)
      local result
      for _,v in pairs(path) do
	 local fn = join(v, cache_dir, filename)
	 if isreadable(fn) then
	    texio.write('log','(load cache: ' .. filename .. ')')
	    if compressed then
	      result = loadstring(gzip.load(fn))
	    else
	      result = loadfile(fn)
	    end
	    result = result and result()
	    break
	 end
      end
      if (not result) or outdate(result) then
	 return nil
      else
	 return result
      end
   end

   local function load_cache(filename, outdate)
      remove_file_if_exist(savepath .. '/' ..  filename .. '.lua')
      local r = load_cache_a(filename ..  luc_suffix, outdate, false)
      if r then
	 return r
      else
         local r = load_cache_a(filename .. '.lua.gz', outdate, true)
	 if r then save_cache_luc(filename, r) end -- update the precompiled cache
	 return r
      end
   end

   ltjb.remove_cache = remove_cache
   ltjb.load_cache = load_cache
   ltjb.save_cache_luc = save_cache_luc
   ltjb.save_cache = save_cache
end

----
do
   local tex_set_attr, tex_get_attr = tex.setattribute, tex.getattribute
   function ltjb.ensure_tex_attr(a, v)
      if tex_get_attr(a)~=v then
	 tex_set_attr(a, v)
      end
   end
end
----

ltjb._error_set_message = _error_set_message
ltjb._error_show = _error_show
ltjb._generic_warn_info = _generic_warn_info

ltjb.package_error = package_error
ltjb.package_warning = package_warning
ltjb.package_warning_no_line = package_warning_no_line
ltjb.package_info = package_info
ltjb.package_info_no_line = package_info_no_line

ltjb.generic_error = generic_error
ltjb.generic_warning = generic_warning
ltjb.generic_warning_no_line = generic_warning_no_line
ltjb.generic_info = generic_info
ltjb.generic_info_no_line = generic_info_no_line

ltjb.ltj_warning_no_line = ltj_warning_no_line
ltjb.ltj_error = ltj_error

---- deterministic version of luatexbase.add_to_callback
function ltjb.add_to_callback(name,fun,description,priority)
    local priority= priority
    if priority==nil then
	priority=#luatexbase.callback_descriptions(name)+1
    end
    if(luatexbase.callbacktypes[name] == 3 and
    priority == 1 and
    #luatexbase.callback_descriptions(name)==1) then
	luatexbase.module_warning("luatexbase",
	"resetting exclusive callback: " .. name)
	luatexbase.reset_callback(name)
    end
    local saved_callback={}
    for k,v in ipairs(luatexbase.callback_descriptions(name)) do
	if k >= priority then
	    local ff,dd = luatexbase.remove_from_callback(name, v)
	    saved_callback[#saved_callback+1]={ff,dd}
	end
    end
    luatexbase.base_add_to_callback(name,fun,description)
    for _,v in ipairs(saved_callback) do
	luatexbase.base_add_to_callback(name,v[1],v[2])
    end
    return
end

-------------------- mock of debug logger
if not ltjb.out_debug then
   local function no_op() end
   ltjb.start_time_measure = no_op
   ltjb.stop_time_measure = no_op
   ltjb.out_debug = no_op
   ltjb.package_debug = no_op
   ltjb.debug_logger = function() return no_op end
   ltjb.show_term = no_op
   ltjb.show_log = no_op
end

-------------------- all done
-- EOF
