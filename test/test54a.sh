#!/bin/bash

platex -jobname test54a-p test54a-lltjext
dvipdfmx test54a-p
luajitlatex -jobname test54a-l test54a-lltjext

cat <<EOF > test54a-res.tex
\documentclass{article}
\pdfpageattr {/Group << /S /Transparency /I true /CS /DeviceRGB>>}
\pdfoptionpdfminorversion 7
\usepackage[a6paper,landscape,margin=0mm]{geometry}
\usepackage{xcolor,graphicx}
\usepackage{transparent}

\def\E#1{\newpage\leavevmode
\hbox to 0pt{\transparent{0.5}\textcolor{red}{%
\includegraphics[width=\textwidth,page=#1]{test54a-p.pdf}}\hss}%
\hbox to 0pt{\transparent{0.5}\textcolor{blue}{%
\includegraphics[width=\textwidth,page=#1]{test54a-l.pdf}}\hss}%
}

\begin{document}
\parindent0pt

\newcount\D
\D=1
\loop\ifnum\D<49
  \E{\the\D}\advance\D1
 \repeat

\end{document}
EOF

pdflatex test54a-res
