#!/usr/bin/ruby


count = 1
print "luatexbase.provides_module({\n"
print "  name = 'luatexja.jisx0213'})\n"
print "module('luatexja.jisx0213', package.seeall)\n"
print "table_jisx0213_2004 = {\n"
print "-- [index: (men-1)*0x10000 + kuten] = ucs_code\n"
open("jisx0213-2004-8bit-std.txt", "r").each_line {|line|
  if line =~ /#/
    line = $`
  end
  if line =~ /^0x\.*$/
    next
  end
  if line =~ /0x([0-9A-F]+)\s+U\+([0-9A-F]+)\s+.*$/
    jxcode = $1.hex - 0x2020
    if jxcode > 0x8000 
      jxcode = jxcode - 0x8080 + 0x10000
    end
    ucscode = $2
    print  "  [0x", jxcode.to_s(16), "]=0x", ucscode, ",\n"
    count += 1
  end
}
print "}"

