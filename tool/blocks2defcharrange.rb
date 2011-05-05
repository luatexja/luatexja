#! /usr/bin/ruby

# The following script converts Blocks.txt
# (http://unicode.org/Public/UNIDATA/Blocks.txt)
# to the character range definitions of LuaTeX-ja.

# USAGE: ruby blocks2defcharrange.rb > unicodeBlocks.tex

count = 1
open("Blocks.txt", "r").each_line {|line|
  if line =~ /#/
    line = $`
  end
  if line =~ /^\s*$/
    next
  end
  if line =~ /([0-9a-f]+)\.\.([0-9a-f]+); (.*)/i
    bcharcode = $1
    echarcode = $2
    blockname = $3
    print "\\defcharrange{", count
    print "}{\"", bcharcode, "-\"", echarcode, "} % ", blockname, "\n"
    count += 1
  end
}
