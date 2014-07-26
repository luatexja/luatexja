#!/bin/bash

platex -jobname test54-p test54-lltjext
dvipdfmx test54-p
luajitlatex -jobname test54-l test54-lltjext

cat <<EOF > test54-res.tex
\documentclass{article}
\pdfpageattr {/Group << /S /Transparency /I true /CS /DeviceRGB>>}
\pdfoptionpdfminorversion 7
\usepackage[a6paper,landscape,margin=0mm]{geometry}
\usepackage{xcolor,graphicx}
\usepackage{transparent}

\def\E#1{\newpage\leavevmode
\hbox to 0pt{\transparent{0.5}\textcolor{red}{%
\includegraphics[width=\textwidth,page=#1]{test54-p.pdf}}\hss}%
\hbox to 0pt{\transparent{0.5}\textcolor{blue}{%
\includegraphics[width=\textwidth,page=#1]{test54-l.pdf}}\hss}%
}

\begin{document}
\parindent0pt

\newcount\D
\D=1
\loop\ifnum\D<25
  \E{\the\D}\advance\D1
 \repeat

\end{document}
EOF

pdflatex test54-res
