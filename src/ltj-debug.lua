--
-- luatexja/debug.lua
--
luatexbase.provides_module({
  name = 'luatexja.debug',
  date = '2011/05/14',
  description = '',
})
module('luatexja.debug', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)

local table = table

-------------------- pretty-print

local function get_serialize_param()
  return table.serialize_functions,
         table.serialize_compact,
         table.serialize_inline
end
local function set_serialize_param(s_f, s_c, s_i)
  table.serialize_functions = s_f
  table.serialize_compact = s_c
  table.serialize_inline = s_i
end

local function normal_serialize(t)
  local s_f, s_c, s_i = get_serialize_param()
  set_serialize_param(true, true, true)
  local ret = table.serialize(t, false, false, true)
  set_serialize_param(s_f, s_c, s_i)
  return ret
end

function table_tosource(t)
  if not next(t) then return "{}" end
  local res_n = "\127"..normal_serialize({t}).."\127"
  local s, e, cap = res_n:find("\127{\n ({ .* }),\n}\127")
  if s == 1 and e == res_n:len() then return cap
  else return normal_serialize(t)
  end
end

function function_tosource(f)
  local res = normal_serialize({f})
  return res:sub(4, res:len() - 3)
end

--! 値 v をそれを表すソース文字列に変換する.
--! lualibs の table.serialize() の処理を利用している.
function tosource(v)
  local tv = type(v)
  if tv == "function" then return function_tosource(v)
  elseif tv == "table" then return table_tosource(v)
  elseif tv == "string" then return string.format('%q', v)
  else return tostring(v)
  end
end

local function coerce(f, v)
  if f == "q" then return "s", tosource(v)
  elseif f == "s" then return f, tostring(v)
  else return f, tonumber(v) or 0
  end
end

local function do_pformat(fmt, ...)
  fmt = fmt:gsub("``", "\127"):gsub("`", "%%"):gsub("\127", "`")
  local i, na, a = 0, {}, {...}
  local function proc(p, f)
    i = i + 1; f, na[i] = coerce(f, a[i])
    return p..f
  end
  fmt = fmt:gsub("(%%[-+#]?[%d%.]*)([a-zA-Z])", proc)
  return fmt:format(unpack(na))
end

--! string.format() の拡張版. 以下の点が異なる.
--!  - %q は全ての型について tosource() に変換
--!  - <%> の代わりに <`> も使える (TeX での使用のため)
--!  - %d, %s 等でキャストを行う
function pformat(fmt, ...)
  if type(fmt) == "string" then
    return do_pformat(fmt, ...)
  else 
    return tosource(fmt)
  end
end

-------------------- debug logging

local debug_show_term = true
local debug_show_log = true
--! デバッグログを端末に出力するか
function show_term(v)
  debug_show_term = v
end
--! デバッグログをログファイルに出力するか
function show_log(v)
  debug_show_log = v
end

local function write_debug_log(s)
  local target
  if debug_show_term and debug_show_log then
    texio.write_nl("term and log", s)
  elseif debug_show_term and not debug_show_log then
    texio.write_nl("term", s)
  elseif not debug_show_term and debug_show_log then
    texio.write_nl("log", s)
  end
end

--! デバッグログ出力. 引数は pformat() と同じ.
function debug(...)
  if debug_show_term or debug_show_log then
    write_debug_log("%DEBUG:"..pformat(...))
  end
end

--! デバッグログ出力, パッケージ名付き.
function package_debug(pkg, ...)
  if debug_show_term or debug_show_log then
    write_debug_log("%DEBUG("..pkg.."):"..pformat(...))
  end
end

--! パッケージ名付きデバッグログ出力器を得る.
function debug_logger(pkg)
  return function(...) package_debug(pkg, ...) end
end

if luatexja.base then
  luatexja.base.debug = debug
  luatexja.base.package_debug = package_debug
  luatexja.base.debug_logger = debug_logger
  luatexja.base.show_term = show_term
  luatexja.base.show_log = show_log
end

-------------------- all done
-- EOF
