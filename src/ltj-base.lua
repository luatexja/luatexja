--
-- luatexja/ltj-base.lua
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

  local LF = "\n"
  local err_break = ""
  local err_main = ""
  local err_help = ""

  local function message_cont(str, c)
    return str:gsub(err_break, LF .. c)
  end
  local function into_lines(str)
    return str:gsub(err_break, LF):explode(LF)
  end

  _error_set_break = function (str)
    err_break = str
  end

  _error_set_message = function (msgcont, main, help)
    err_main = message_cont(main, msgcont)
    err_help = into_lines(help)
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
    local mainref = main..".\n\n"..ref.."\n"..message_a
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
    texio.write_nl(out, br..main..on_line.."."..br)
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
    generic_error("("..pkgname.."                ",
      "Package "..pkgname.." Error: "..main,
      "See the "..pkgname.." package documentation for explanation.",
      help)
  end
  package_warning = function (pkgname, main)
    generic_warning("("..pkgname.."                ",
      "Package "..pkgname.." Warning: "..main)
  end
  package_warning_no_line = function (pkgname, main)
    generic_warning_no_line("("..pkgname.."                ",
      "Package "..pkgname.." Warning: "..main)
  end
  package_info = function (pkgname, main)
    generic_info("("..pkgname.."             ",
      "Package "..pkgname.." Info: "..main)
  end
  package_info_no_line = function (pkgname, main)
    generic_info_no_line("("..pkgname.."             ",
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

  local glue_spec_id = node.id("glue_spec")

  local function copy_skip(s1, s2)
    if not s1 then
      s1 = node.new(glue_spec_id)
    end
    s1.width = s2.width or 0
    s1.stretch = s2.stretch or 0
    s1.stretch_order = s2.stretch_order or 0
    s1.shrink = s2.shrink or 0
    s1.shrink_order = s2.shrink_order or 0
    return s1
  end

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

--! ixbase.to_skip() と同じ
  local function to_skip(val)
    if type(val) == "userdata" then
      return val
    end
    local res = node.new(glue_spec_id)
    if val == nil then
      res.width = 0
    elseif type(val) == "number" then
      res.width = val
    elseif type(val) == "table" then
      copy_skip(res, val)
    else
      local t = tostring(val):lower():explode()
      local w, p, m = t[1], t[3], t[5]
      if t[2] == "minus" then
        p, m = nil, t[3]
      end
      res.width = tex.sp(t[1])
      if p then
        res.stretch, res.stretch_order = parse_dimen(p)
      end
      if m then
        res.shrink, res.shrink_order = parse_dimen(m)
      end
    end
    return res
  end

  local function dump_skip(s)
    print(("%s+%s<%s>-%s<%s>"):format(
      s.width or 0, s.stretch or 0, s.stretch_order or 0,
      s.shrink or 0, s.shrink_order or 0))
  end

  ltjb.to_dimen = to_dimen
  ltjb.dump_skip = dump_skip
  ltjb.to_skip = to_skip
end

-------------------- Virtual table for LaTeX counters
-- not used in current LuaTeX-ja
do
--! ixbase.counter と同じ
  counter = {}
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

-------------------- Number handling in TeX source
do

  local tok_escape = token.create("ltj@@q@escape")
  local tok_num = token.create("ltj@@q@escapenum")
  local c_id_assign_int = token.command_id("assign_int")
  local c_id_char_given = token.command_id("char_given")

  local function error_scan()
    package_error("luatexja",
      "Missing number of a permitted form, treated as zero",
      "A number should have been here; I inserted '0'.")
  end

  local function get_expd_next()
    local next = token.get_next()
    while token.is_expandable(next) do
      token.expand(next)
      next = token.get_next()
    end
    return next
  end

  local function grab_decimal(next, res)
    table.insert(res, next)
    while true do
      next = get_expd_next()
      if not (next[1] == 12 and 0x30 <= next[2] and next[2] <= 0x39) then
        break
      end
      table.insert(res, next)
    end
    if next[1] == 10 then next = nil end
    return true, next
  end

  local function grab_hexa(next, res)
    local ok = false
    table.insert(res, next)
    while true do
      next = get_expd_next()
      if not ((next[1] == 12 and (0x30 <= next[2] and next[2] <= 0x39)) or
              ((next[1] == 12 or next[1] == 11) and
               (0x41 <= next[2] and next[2] <= 0x46))) then
        break
      end
      ok = true
      table.insert(res, next)
    end
    if next[1] == 10 then next = nil end
    return ok, next
  end

  local function grab_octal(next, res)
    local ok = false
    table.insert(res, next)
    while true do
      next = get_expd_next()
      if not (next[1] == 12 and (0x30 <= next[2] and next[2] <= 0x37)) then
        break
      end
      ok = true
      table.insert(res, next)
    end
    if next[1] == 10 then next = nil end
    return ok, next
  end

  local function grab_charnum(next, res)
    table.insert(res, next)
    next = token.get_next()
    table.insert(res, next)
    next = get_expd_next()
    if next[1] == 10 then next = nil end
    return true, next
  end

  local function scan_with(delay, scanner)
    local function proc()
      if delay ~= 0 then
        if delay > 0 then delay = delay - 1 end
        return token.get_next()
      else
        local cont, back = scanner()
        if not cont then
          ltb.remove_from_callback("token_filter", "ltj@grab@num")
        end
        return back
      end
    end
    ltb.add_to_callback("token_filter", proc, "ltj@grab@num", 1)
  end

  local function scan_brace()
    scan_with(1, function()
      local next = token.get_next()
      if next[1] == 1 then
        return false, { tok_escape, next }
      elseif next[1] == 10 then
        return true, { next }
      else
        return false, { next }
      end
    end)
  end

  local function scan_number()
    scan_with(1, function()
      local next = get_expd_next()
      local res, ok = { tok_num }, false
      while true do
        if next[1] == 12 and (next[2] == 0x2B or next[2] == 0x2D) then
          table.insert(res, next)
        elseif next[1] ~= 10 then
          break
        end
        next = get_expd_next()
      end
      if next[1] == 12 and 0x30 <= next[2] and next[2] <= 0x39 then
        ok, next = grab_decimal(next, res)
      elseif next[1] == 12 and next[2] == 0x22 then
        ok, next = grab_hexa(next, res)
      elseif next[1] == 12 and next[2] == 0x27 then
        ok, next = grab_octal(next, res)
      elseif next[1] == 12 and next[2] == 0x60 then
        ok, next = grab_charnum(next, res)
      elseif next[1] == c_id_assign_int or next[1] == c_id_char_given then
        table.insert(res, next)
        ok, next = true, nil
      end
      if ok then
         table.insert(res, tok_num)
      else
         error_scan()
         res = { tok_escape }
      end
       if next then table.insert(res, next) end
       return false, res
    end)
  end

  ltjb.scan_brace = scan_brace
  ltjb.scan_number = scan_number
end

-------------------- TeX register allocation
-- not used in current LuaTeX-ja

do
  local cmod_base_count = token.create('ltj@@count@zero')[2]
  local cmod_base_attr = token.create('ltj@@attr@zero')[2]
  local cmod_base_dimen = token.create('ltj@@dimen@zero')[2]
  local cmod_base_skip = token.create('ltj@@skip@zero')[2]

  local function const_number(name)
    if name:sub(1, 1) == '\\' then name = name:sub(2) end
    return token.create(name)[2]
  end

  local function count_number(name)
    if name:sub(1, 1) == '\\' then name = name:sub(2) end
    return token.create(name)[2] - cmod_base_count
  end

  local function attribute_number(name)
    if name:sub(1, 1) == '\\' then name = name:sub(2) end
    return token.create(name)[2] - cmod_base_attr
  end

  local function dimen_number(name)
    if name:sub(1, 1) == '\\' then name = name:sub(2) end
    return token.create(name)[2] - cmod_base_dimen
  end

  local function skip_number(name)
    if name:sub(1, 1) == '\\' then name = name:sub(2) end
    return token.create(name)[2] - cmod_base_skip
  end

  ltjb.const_number = const_number
  ltjb.count_number = count_number
  ltjb.attribute_number = attribute_number
  ltjb.dimen_number = dimen_number
  ltjb.skip_number = skip_number
end

-------------------- getting next token
local cstemp = nil
local function get_cs(s)
   cstemp = token.csname_name(token.get_next())
   tex.sprint(cat_lp,'\\' .. s)
end
ltjb.get_cs = get_cs

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

require('lualibs-lpeg') -- string.split
require('lualibs-os')   -- os.type

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

   -- determine save path
   local savepath = ''
   for _,v in pairs(path) do
      local testpath =  join(v, cache_dir)
      if not lfs.isdir(testpath) then dir.mkdirs(testpath) end
      if lfs.isdir(testpath) then savepath = testpath; break end
   end

   save_cache_luc = function (filename, t, serialized)
      local fullpath = savepath .. '/' ..  filename .. luc_suffix
      local s = serialized or serialize(t, 'return', false)
      if s then
	 local sa = load(s)
	 local f = io.open(fullpath, 'wb')
	 if f and sa then 
	    f:write(string.dump(sa, true)) 
	    texio.write('(save cache: ' .. fullpath .. ')')
	 end
	 f:close()
      end
   end

   save_cache = function (filename, t)
      local fullpath = savepath .. '/' ..  filename .. '.lua'
      local s = serialize(t, 'return', false)
      if s then
	 local f = io.open(fullpath, 'w')
	 if f then 
	    f:write(s) 
	    texio.write('(save cache: ' .. fullpath .. ')')
	 end
	 f:close()
	 save_cache_luc(filename, t, s)
      end
   end

   local function load_cache_a (filename, outdate)
      local result
      for _,v in pairs(path) do
	 local fn = join(v, cache_dir, filename)
	 if isreadable(fn) then 
	    texio.write('(load cache: ' .. fn .. ')')
	    result = loadfile(fn)
	    result = result and result(); break
	 end
      end
      if (not result) or outdate(result) then 
	 return nil 
      else 
	 return result 
      end
   end
   
   load_cache = function (filename, outdate)
      local r = load_cache_a(filename ..  luc_suffix, outdate)
      if r then 
	 return r
      else
         local r = load_cache_a(filename .. '.lua', outdate)
	 if r then save_cache_luc(filename, r) end -- update the precompiled cache
	 return r
      end
   end

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

ltjb._error_set_break = _error_set_break
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
