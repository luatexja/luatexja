--
-- luatexja/base.lua
--
luatexbase.provides_module({
  name = 'luatexja.base',
  date = '2011/11/18',
  description = '',
})
module('luatexja.base', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

local ltb = luatexbase
local tostring = tostring
local node, table, tex, token = node, table, tex, token

local cat_lp = luatexbase.catcodetables['latex-package']

-------------------- 

public_name = 'luatexja'
public_version = 'alpha'

-------------------- Fully-expandable error messaging
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

  function _error_set_break(str)
    err_break = str
  end

  function _error_set_message(msgcont, main, help)
    err_main = message_cont(main, msgcont)
    err_help = into_lines(help)
  end

  function _error_show(escchar)
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

  function generic_error(msgcont, main, ref, help)
    local mainref = main..".\n\n"..ref.."\n"..message_a
    _error_set_message(msgcont, mainref, help)
    _error_show(true)
  end

  function _generic_warn_info(msgcont, main, warn, line)
    local mainc = message_cont(main, msgcont)
    local br = warn and "\n" or ""
    local out = warn and "term and log" or "log"
    local on_line = line and (" on input line "..tex.inputlineno) or ""
    local newlinechar = tex.newlinechar
    tex.newlinechar = -1
    texio.write_nl(out, br..main..on_line.."."..br)
    tex.newlinechar = newlinechar
  end

  function generic_warning(msgcont, main)
    _generic_warn_info(msgcont, main, true, true)
  end
  function generic_warning_no_line(msgcont, main)
    _generic_warn_info(msgcont, main, true, false)
  end
  function generic_info(msgcont, main)
    _generic_warn_info(msgcont, main, false, true)
  end
  function generic_info_no_line(msgcont, main)
    _generic_warn_info(msgcont, main, false, false)
  end

  function package_error(pkgname, main, help)
    generic_error("("..pkgname.."                ",
      "Package "..pkgname.." Error: "..main,
      "See the "..pkgname.." package documentation for explanation.",
      help)
  end
  function package_warning(pkgname, main)
    generic_warning("("..pkgname.."                ",
      "Package "..pkgname.." Warning: "..main)
  end
  function package_warning_no_line(pkgname, main)
    generic_warning_no_line("("..pkgname.."                ",
      "Package "..pkgname.." Warning: "..main)
  end
  function package_info(pkgname, main)
    generic_info("("..pkgname.."             ",
      "Package "..pkgname.." Info: "..main)
  end
  function package_info_no_line(pkgname, main)
    generic_info_no_line("("..pkgname.."             ",
      "Package "..pkgname.." Info: "..main)
  end

  function ltj_error(main, help)
    package_error(public_name, main, help)
  end
  function ltj_warning_no_line(main)
    package_warning_no_line(public_name, main, help)
  end

end
-------------------- TeX stream I/O
do

--! ixbase.print() と同じ
  --- Extension to tex.print(). Each argument string may contain
  -- newline characters, in which case the string is output (to
  -- TeX input stream) as multiple lines.
  -- @param ... (string) string to output 
  function mprint(...)
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

end
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
  function to_dimen(val)
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
  function to_skip(val)
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
      if t[3] then
        res.stretch, res.stretch_order = parse_dimen(t[3])
      end
      if t[5] then
        res.shrink, res.shrink_order = parse_dimen(t[5])
      end
    end
    return res
  end

  function dump_skip(s)
    print(("%s+%s<%s>-%s<%s>"):format(
      s.width or 0, s.stretch or 0, s.stretch_order or 0,
      s.shrink or 0, s.shrink_order or 0))
  end

end
-------------------- Virtual table for LaTeX counters
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

--! ixbase.length は tex.skip と全く同じなので不要.

end
-------------------- Number handling in TeX source
do

  local tok_escape = token.create("ltj@@q@escape")
  local tok_num = token.create("ltj@@q@escapenum")
  local c_id_assign_int = token.command_id("assign_int")
  local c_id_char_given = token.command_id("char_given")

  local function error_scan()
    _M.package_error("luatexja",
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

  function scan_brace()
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

  function scan_number()
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

end
-------------------- TeX register allocation
do
  local cmod_base_count = token.create('ltj@@count@zero')[2]
  local cmod_base_attr = token.create('ltj@@attr@zero')[2]
  local cmod_base_dimen = token.create('ltj@@dimen@zero')[2]
  local cmod_base_skip = token.create('ltj@@skip@zero')[2]

  function const_number(name)
    if name:sub(1, 1) == '\\' then name = name:sub(2) end
    return token.create(name)[2]
  end

  function count_number(name)
    if name:sub(1, 1) == '\\' then name = name:sub(2) end
    return token.create(name)[2] - cmod_base_count
  end

  function attribute_number(name)
    if name:sub(1, 1) == '\\' then name = name:sub(2) end
    return token.create(name)[2] - cmod_base_attr
  end

  function dimen_number(name)
    if name:sub(1, 1) == '\\' then name = name:sub(2) end
    return token.create(name)[2] - cmod_base_dimen
  end

  function skip_number(name)
    if name:sub(1, 1) == '\\' then name = name:sub(2) end
    return token.create(name)[2] - cmod_base_skip
  end

end
-------------------- mock of debug logger

if not _M.debug or _M.debug == _G.debug then
  local function no_op() end
  debug = no_op
  package_debug = no_op
  show_term = no_op
  show_log = no_op
  function debug_logger()
    return no_op
  end
end

-------------------- getting next token
cstemp = nil
function get_cs(s)
   cstemp = token.csname_name(token.get_next())
   tex.sprint(cat_lp,'\\' .. s)
end

-------------------- all done
-- EOF
