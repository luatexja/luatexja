#! /usr/bin/ruby
# -*- coding: utf-8 -*-

# The following script converts a set of chars except "\s", as Ruby defines,
# to the character range definition of LuaTeX-ja.

# USAGE: ruby __FILE__ ifile rangeNo [> ofile]

# Example (in Japanese)
# 教育漢字リスト (http://www.aozora.gr.jp/kanji_table/kyouiku_list.zip)
# に対して適用したいとき．
# 1. kyoikukanji.txt に対して，コメント部分の先頭に # をつける編集を加える;
# 2. ruby chars2defcharrange.rb kyoikukanji.txt 210 > kyoikukanjiChars.tex
#    を実行する．

def print_usage()
  print "USAGE: ruby ", __FILE__, "ifile rangeNo [> ofile]\n"
end

if __FILE__ == $0
  # コマンドライン引数の処理
  if ARGV.length < 2
    print_usage()
    exit
  end
  ifile = ARGV[0]
  rangeNo = ARGV[1]

  # 対象文字列の作成
  string = ""
  open(ifile, "r").each_line{|line|
    if line =~ /#/
      line = $`
    end
    line.gsub!(/\s/){}
    string += line
  }

  # 10 進 unicode code point 配列に変換
  decs = string.unpack("U*")

  # print
  print "\defcharrange{", rangeNo, "}{"
  decs.each_with_index{|code, index|
    if index != 0
      print ","
    end
    print "\"", code.to_s(16)
  }
  print "}\n"
end
