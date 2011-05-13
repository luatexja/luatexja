--
-- luatexja/stack.lua
--
luatexbase.provides_module({
  name = 'luatexja.stack',
  date = '2011/04/01',
  version = '0.1',
  description = 'LuaTeX-ja stack system',
})
module('luatexja.stack', package.seeall)
local err, warn, info, log = luatexbase.errwarinf(_NAME)


-- EOF
