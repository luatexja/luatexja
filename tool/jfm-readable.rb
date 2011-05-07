#! /usr/bin/ruby
# -*- coding: utf-8 -*-

# The following script converts Unicode codepoints as 0x???? to real characters.

# USAGE: ruby __FILE__ ifile [> ofile]

def print_usage()
  print "USAGE: ruby ", __FILE__, "ifile [> ofile]\n"
end

if __FILE__ == $0
  # コマンドライン引数の処理
  if ARGV.length < 1
    print_usage()
    exit
  end
  ifile = ARGV[0]

  print "-- -*- coding: utf-8 -*-\n"
  open(ifile, "r").each_line{|line|
    line.gsub!(/0x[0-9a-fA-F]*/){|s| s.to_s + "(" + [s.to_i(0)].pack("U*") + ")"}
    print line
  }
end
