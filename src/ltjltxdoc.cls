%%
%% This is file `ltjltxdoc.cls',
%% generated with the docstrip utility.
%%
%% The original source files were:
%%
%% ltjltxdoc.dtx  (with options: `class')
%% 
%% IMPORTANT NOTICE:
%% 
%% For the copyright see the source file.
%% 
%% Any modified versions of this file must be renamed
%% with new filenames distinct from ltjltxdoc.cls.
%% 
%% For distribution of the original source see the terms
%% for copying and modification in the file ltjltxdoc.dtx.
%% 
%% This generated file may be distributed as long as the
%% original source files, as listed above, are part of the
%% same distribution. (The sources need not necessarily be
%% in the same archive or directory.)
%% File: ltjltxdoc.dtx

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ltjltxdoc}[2018/01/01 v1.0d-ltj-3 Standard LuaLaTeX-ja file]
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{ltxdoc}}
\ProcessOptions
\LoadClass{ltxdoc}
\RequirePackage{luatexja}
\def\Cjascale{0.962216}
\renewcommand{\normalsize}{%
    \@setfontsize\normalsize\@xpt{15}%
  \abovedisplayskip 10\p@ \@plus2\p@ \@minus5\p@
  \abovedisplayshortskip \z@ \@plus3\p@
  \belowdisplayshortskip 6\p@ \@plus3\p@ \@minus3\p@
   \belowdisplayskip \abovedisplayskip
   \let\@listi\@listI}
\renewcommand{\small}{%
  \@setfontsize\small\@ixpt{11}%
  \abovedisplayskip 8.5\p@ \@plus3\p@ \@minus4\p@
  \abovedisplayshortskip \z@ \@plus2\p@
  \belowdisplayshortskip 4\p@ \@plus2\p@ \@minus2\p@
  \def\@listi{\leftmargin\leftmargini
              \topsep 4\p@ \@plus2\p@ \@minus2\p@
              \parsep 2\p@ \@plus\p@ \@minus\p@
              \itemsep \parsep}%
  \belowdisplayskip \abovedisplayskip}
\normalsize
\setlength\parindent{1\zw}
\providecommand*{\file}[1]{\texttt{#1}}
\providecommand*{\pstyle}[1]{\textsl{#1}}
\providecommand*{\Lcount}[1]{\textsl{\small#1}}
\providecommand*{\Lopt}[1]{\textsf{#1}}
\providecommand\dst{{\normalfont\scshape docstrip}}
\providecommand\NFSS{\textsf{NFSS}}
\newcounter{@clineno}
\def\mlineplus#1{\setcounter{@clineno}{\arabic{CodelineNo}}%
   \addtocounter{@clineno}{#1}\arabic{@clineno}}
\def\tsample#1{%
  \hbox to\linewidth\bgroup\vrule width.1pt\hss
    \vbox\bgroup\hrule height.1pt
      \vskip.5\baselineskip
      \vbox to\linewidth\bgroup\tate\hsize=#1\relax\vss}
\def\endtsample{%
      \vss\egroup
      \vskip.5\baselineskip
    \hrule height.1pt\egroup
  \hss\vrule width.1pt\egroup}
\def\verb{\relax\ifmmode\hbox\else\leavevmode\vadjust{}\fi
  \bgroup \let\do\do@noligs \verbatim@nolig@list
    \ttfamily \verb@eol@error \let\do\@makeother \dospecials
    \@ifstar{\@sverb}{\@vobeyspaces \frenchspacing \@sverb}}
\ltjsetparameter{alxspmode={"5C,3}} %% \
\ltjsetparameter{alxspmode={"22,3}} %% "
\def\mod@math@codes{\mathcode`\|="207C \mathcode`\&="2026
                    \mathcode`\-="702D \mathcode`\+="702B
                    \mathcode`\:="703A \mathcode`\=="703D }
\endinput
%%
%% End of file `ltjltxdoc.cls'.
