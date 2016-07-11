#!/bin/bash
for x in `grep '{\\\\def\\\\js@magscale' ../src*/ltjsarticle.cls | grep 'DeclareOption' | sed 's/\\\\DeclareOption{\\([0-9][0-9.]*[A-Za-z]*\\)}.*/\\1/'`
  do echo TEST: $x; luajitlatex "\\def\\fsize{$x}\\input test22-ltjs-mag" \
  | grep @ | sed 's/@//'
done
