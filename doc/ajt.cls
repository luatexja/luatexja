%% 
%% Copyright (C) 2010 The Korean TeX Society.
%% 
%%     This program is free software; you can redistribute it and/or modify
%%     it under the terms of the GNU General Public License as published by
%%     the Free Software Foundation; either version 2 of the License, or
%%     (at your option) any later version.
%% 
%%     This program is distributed in the hope that it will be useful,
%%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%     GNU General Public License for more details.
%% 
%%     You should have received a copy of the GNU General Public License
%%     along with this program; if not, write to the Free Software
%%     Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
%% 
\NeedsTeXFormat{LaTeX2e}[1999/12/01]
\ProvidesClass{ajt}
    [2010/12/31 v0.73 The Asian Journal of TeX Class]
\let\ExecuteOptions@ltx\ExecuteOptions
\def\ExecuteOptions#1{%
 \ExecuteOptions@ltx{a4paper,10pt,twoside,onecolumn,final}%
}%
\LoadClassWithOptions{article}
\let\ExecuteOptions\ExecuteOptions@ltx
\def\normal@body@spread{1.069}
\def\normal@info@spread{1.0}
\def\normalbodyspread{\linespread{\normal@body@spread}\selectfont}
\linespread{\normal@body@spread}
%%%
%%% korean option: use ko.TeX for Korean typesetting (default: english)
%%% ptexjs option: use pTeX (jsclasses appearance) for Japanese typesetting (default: english)
%%% dvips option: use dvips instead of dvipdfmx, xetex or pdftex
%%% print option: final version (default: preprint)
%%% reprint option: print option without crop (default: preprint)
%%% koreanabstract option: abstract is korean not english (default: english)
%%% ptexjsabstract option: abstract is japanese (jsclasses appearance) not english (default: english)
%%%
\newif\if@korean\@koreanfalse
\newif\if@ptexjs\@ptexjsfalse
\newif\if@print\@printfalse
\newif\if@reprint\@reprintfalse
\newif\if@korabstract\@korabstractfalse
\newif\if@ptexjsabstract\@ptexjsabstractfalse
\def\tpd@driver{pdftex}
\def\dps@driver{dvips}
\def\dpx@driver{dvipdfmx}
\def\xtx@driver{xetex}
%%%
\RequirePackage{ifpdf}
\ifpdf
  \let\@dvi@driver\tpd@driver
\else
  \expandafter\ifx\csname XeTeXrevision\endcsname\relax
    \let\@dvi@driver\dpx@driver
  \else
    \let\@dvi@driver\xtx@driver
  \fi
\fi
%%%
\DeclareOption{korean}{\@koreantrue\@ptexjsfalse}
\DeclareOption{ptexjs}{\@ptexjstrue\@koreanfalse}
\DeclareOption{dvips}{\let\@dvi@driver\dps@driver}
\DeclareOption{print}{\@printtrue\@reprintfalse}
\DeclareOption{reprint}{\@printtrue\@reprinttrue}
\DeclareOption{koreanabstract}{\@korabstracttrue\@ptexjsabstractfalse}
\DeclareOption{ptexjsabstract}{\@ptexjsabstracttrue\@korabstractfalse}
\ProcessOptions
%%%
\setlength\paperwidth{170mm}
\setlength\paperheight{254mm}
\setlength\textwidth{132mm}
\setlength\oddsidemargin{-6.4mm}
\setlength\evensidemargin\oddsidemargin
\if@print\if@reprint\else% for final printing only
  \addtolength\oddsidemargin{1.5mm}
  \addtolength\evensidemargin{-1.5mm}
\fi\fi
\setlength\textheight{210mm}
\setlength\headheight{12pt}
\setlength\headsep{14pt}
\setlength\topmargin{-10mm}
\setlength\footskip{24pt}
%%%
%%% AJT use CM math fonts, not mathpazo.sty
%%%
\ifx\@dvi@driver\xtx@driver % XeTeX
  \if@print
    \RequirePackage{fontspec,xunicode}
    \RequirePackage[no-sscript]{xltxtra}
    \setmainfont[Mapping=tex-text]{Palatino LT Std}
    \setsansfont[Mapping=tex-text]{Optima LT Std}
  \else
    \RequirePackage{fontspec,xunicode,xltxtra}
  \fi
\else % pdfTeX, DVIPDFMx, DVIPS
  \renewcommand\rmdefault{ppl} % URW Palatino
  \if@print
    \renewcommand\sfdefault{pop} % Adobe Optima
    %\renewcommand\sfdefault{uop} % URW Classico (Optima clone)
  \fi
  \if@korean
    \renewcommand\bfdefault{b}
  \fi
\fi
%%%
\ifx\@dvi@driver\dpx@driver
  \RequirePackage[dvipdfmx]{color,graphicx}
  \RequirePackage[unicode,dvipdfmx]{hyperref}
\else
  \RequirePackage{color,graphicx}
  \ifx\@dvi@driver\xtx@driver
    \RequirePackage{hyperref}
  \else
    \RequirePackage[unicode]{hyperref}
  \fi
\fi
\if@print\setkeys{Hyp}{nolinks=true}\fi
%%%
\RequirePackage{calc}
\RequirePackage{amsmath}
\RequirePackage{textcomp}
%%%
\if@print\if@reprint\else
  \IfFileExists{crop.sty}
    {\ifx\@dvi@driver\tpd@driver% pdftex
       \RequirePackage[a4,center,cam,pdftex!]{crop}%
     \else% dvips or dvipdfmx or xetex
       \RequirePackage[a4,center,cam,dvips!]{crop}%
     \fi
    }{}
\fi\fi
\if@korean
  \ifx\@dvi@driver\xtx@driver % XeTeX
    \RequirePackage{xetexko}
    \if@print
      \setmainhangulfont[
        BoldFont={YoonMyungjo Medium},
        Mapping=tex-text, Renderer=ICU,
        preperiodkern={-.3ex}, precommakern={-.3ex}
      ]{YoonMyungjo Light}
      \setsanshangulfont[
        BoldFont={YoonGothic Medium},
        Mapping=tex-text, Renderer=ICU,
        preperiodkern={-.1ex}, precommakern={-.1ex}
      ]{YoonGothic Light}
      \setmonohangulfont[
        BoldFont={YoonGothic Medium},
        Mapping=tex-text, Renderer=ICU
      ]{YoonGothic Light}
    \fi
    \linespread{\normal@body@spread}
    \hangulquotes
  \else
    \RequirePackage[utf,finemath]{kotex}
    \RequirePackage[default]{dhucs-interword}
    \if@print
      \RequirePackage[gremphhangul=yngt,gremphhanja=yngt]{dhucs-gremph}
      \usehangulfontspec{yn}
      \SetHangulFonts{ynmj}{yngt}{yngt}
      \SetHanjaFonts{ynmj}{yngt}{yngt}
      \DeclareFontFamily{LUC}{grem}{\hyphenchar \font\m@ne}
      \DeclareFontShape{LUC}{grem}{m}{n}{<-> LUC * o\GrEmphFont l}{}
      \DeclareFontShape{LUC}{grem}{m}{it}{<-> LUC * o\GrEmphFont l}{}
      \DeclareFontShape{LUC}{grem}{m}{sl}{<-> LUC * o\GrEmphFont l}{}
      \DeclareFontFamily{LUC}{gremhj}{\hyphenchar \font\m@ne}
      \DeclareFontShape{LUC}{gremhj}{m}{n}{<-> LUC * o\GrEmphHanjaFont l}{}
      \DeclareFontShape{LUC}{gremhj}{m}{it}{<-> LUC * o\GrEmphHanjaFont l}{}
      \DeclareFontShape{LUC}{gremhj}{m}{sl}{<-> LUC * o\GrEmphHanjaFont l}{}
    \else
      \RequirePackage{dhucs-gremph}
      \usehangulfontspec{ut}
      \SetHangulFonts{utmj}{utgt}{utgt}
      \SetHanjaFonts{utmj}{utgt}{utgt}
    \fi
  \fi
  \def\korean@body@spread{1.35}
  \def\korean@info@spread{1.15}
  \def\koreanbodyspread{\linespread{\korean@body@spread}\selectfont}
  \def\koreaninfospread{\linespread{\korean@info@spread}\selectfont}
  \renewcommand{\figurename}{그림}
  \renewcommand{\tablename}{표}
  \newcommand\hcntdot{\nobreak\mbox{$\cdot$}}
  \newcommand\cntrdot{\kern.2em\hcntdot\nobreak\hskip.2em}
  \newcommand\cntrdots{\kern.2em\hcntdot\nobreak\hskip.2em\hcntdot\nobreak\hskip.2em\hcntdot\nobreak\hskip.4em}
  \ifx\@dvi@driver\xtx@driver % XeTeX
    \newcommand\cnm[1]{〈#1〉}
    \newcommand\ccnm[1]{《#1》}
    \newcommand\snm[1]{「#1」}
    \newcommand\bnm[1]{『#1』}
  \else
    \newcommand\cnm[1]{\kern-.10em〈#1〉\kern-.10em}
    \newcommand\ccnm[1]{\kern-.198em《#1》\kern-.198em}
    \newcommand\snm[1]{\kern-.10em「#1」\kern-.10em}
    \newcommand\bnm[1]{\kern-.20em『#1』\kern-.20em}
  \fi
\else\if@ptexjs
  \DeclareFontShape{JY1}{mc}{m}{n}{<-> s * [0.961] jis}{}
  \DeclareFontShape{JY1}{gt}{m}{n}{<-> s * [0.961] jisg}{}
  \DeclareFontShape{JT1}{mc}{m}{n}{<-> s * [0.961] tmin10}{}
  \DeclareFontShape{JT1}{gt}{m}{n}{<-> s * [0.961] tgoth10}{}
  %
  \DeclareFontShape{JY1}{mc}{m}{it}{<->ssub*mc/m/n}{}
  \DeclareFontShape{JY1}{mc}{m}{sl}{<->ssub*mc/m/n}{}
  \DeclareFontShape{JY1}{mc}{m}{sc}{<->ssub*mc/m/n}{}
  \DeclareFontShape{JY1}{gt}{m}{it}{<->ssub*gt/m/n}{}
  \DeclareFontShape{JY1}{gt}{m}{sl}{<->ssub*gt/m/n}{}
  \DeclareFontShape{JY1}{mc}{bx}{it}{<->ssub*gt/m/n}{}
  \DeclareFontShape{JY1}{mc}{bx}{sl}{<->ssub*gt/m/n}{}
  \DeclareFontShape{JT1}{mc}{m}{it}{<->ssub*mc/m/n}{}
  \DeclareFontShape{JT1}{mc}{m}{sl}{<->ssub*mc/m/n}{}
  \DeclareFontShape{JT1}{mc}{m}{sc}{<->ssub*mc/m/n}{}
  \DeclareFontShape{JT1}{gt}{m}{it}{<->ssub*gt/m/n}{}
  \DeclareFontShape{JT1}{gt}{m}{sl}{<->ssub*gt/m/n}{}
  \DeclareFontShape{JT1}{mc}{bx}{it}{<->ssub*gt/m/n}{}
  \DeclareFontShape{JT1}{mc}{bx}{sl}{<->ssub*gt/m/n}{}
  \DeclareRobustCommand\rmfamily
          {\not@math@alphabet\rmfamily\mathrm
           \romanfamily\rmdefault\kanjifamily\mcdefault\selectfont}
  \DeclareRobustCommand\sffamily
          {\not@math@alphabet\sffamily\mathsf
           \romanfamily\sfdefault\kanjifamily\gtdefault\selectfont}
  \DeclareRobustCommand\ttfamily
          {\not@math@alphabet\ttfamily\mathtt
           \romanfamily\ttdefault\kanjifamily\gtdefault\selectfont}
  \def\textmc#1{\relax\ifmmode\hbox\fi{\mcfamily #1}}
  \def\textgt#1{\relax\ifmmode\hbox\fi{\gtfamily #1}}
  \def\ptexjs@body@spread{1.333}
  \def\ptexjs@info@spread{1.15}
  \def\ptexjsbodyspread{\linespread{\ptexjs@body@spread}\selectfont}
  \def\ptexjsinfospread{\linespread{\ptexjs@info@spread}\selectfont}
  \renewcommand{\figurename}{図}
  \renewcommand{\tablename}{表}
  \renewcommand{\appendixname}{付録}
  \prebreakpenalty\jis"2147=10000      % 5000   ’
  \postbreakpenalty\jis"2148=10000     % 5000   “
  \prebreakpenalty\jis"2149=10000      % 5000   ”
  \inhibitxspcode`〒=2
  \xspcode`+=3
  \xspcode`\%=3
  \xspcode`^^80=3
  \xspcode`^^81=3
  \xspcode`^^82=3
  \xspcode`^^83=3
  \xspcode`^^84=3
  \xspcode`^^85=3
  \xspcode`^^86=3
  \xspcode`^^87=3
  \xspcode`^^88=3
  \xspcode`^^89=3
  \xspcode`^^8a=3
  \xspcode`^^8b=3
  \xspcode`^^8c=3
  \xspcode`^^8d=3
  \xspcode`^^8e=3
  \xspcode`^^8f=3
  \xspcode`^^90=3
  \xspcode`^^91=3
  \xspcode`^^92=3
  \xspcode`^^93=3
  \xspcode`^^94=3
  \xspcode`^^95=3
  \xspcode`^^96=3
  \xspcode`^^97=3
  \xspcode`^^98=3
  \xspcode`^^99=3
  \xspcode`^^9a=3
  \xspcode`^^9b=3
  \xspcode`^^9c=3
  \xspcode`^^9d=3
  \xspcode`^^9e=3
  \xspcode`^^9f=3
  \xspcode`^^a0=3
  \xspcode`^^a1=3
  \xspcode`^^a2=3
  \xspcode`^^a3=3
  \xspcode`^^a4=3
  \xspcode`^^a5=3
  \xspcode`^^a6=3
  \xspcode`^^a7=3
  \xspcode`^^a8=3
  \xspcode`^^a9=3
  \xspcode`^^aa=3
  \xspcode`^^ab=3
  \xspcode`^^ac=3
  \xspcode`^^ad=3
  \xspcode`^^ae=3
  \xspcode`^^af=3
  \xspcode`^^b0=3
  \xspcode`^^b1=3
  \xspcode`^^b2=3
  \xspcode`^^b3=3
  \xspcode`^^b4=3
  \xspcode`^^b5=3
  \xspcode`^^b6=3
  \xspcode`^^b7=3
  \xspcode`^^b8=3
  \xspcode`^^b9=3
  \xspcode`^^ba=3
  \xspcode`^^bb=3
  \xspcode`^^bc=3
  \xspcode`^^bd=3
  \xspcode`^^be=3
  \xspcode`^^bf=3
  \xspcode`^^c0=3
  \xspcode`^^c1=3
  \xspcode`^^c2=3
  \xspcode`^^c3=3
  \xspcode`^^c4=3
  \xspcode`^^c5=3
  \xspcode`^^c6=3
  \xspcode`^^c7=3
  \xspcode`^^c8=3
  \xspcode`^^c9=3
  \xspcode`^^ca=3
  \xspcode`^^cb=3
  \xspcode`^^cc=3
  \xspcode`^^cd=3
  \xspcode`^^ce=3
  \xspcode`^^cf=3
  \xspcode`^^d0=3
  \xspcode`^^d1=3
  \xspcode`^^d2=3
  \xspcode`^^d3=3
  \xspcode`^^d4=3
  \xspcode`^^d5=3
  \xspcode`^^d6=3
  \xspcode`^^d7=3
  \xspcode`^^d8=3
  \xspcode`^^d9=3
  \xspcode`^^da=3
  \xspcode`^^db=3
  \xspcode`^^dc=3
  \xspcode`^^dd=3
  \xspcode`^^de=3
  \xspcode`^^df=3
  \xspcode`^^e0=3
  \xspcode`^^e1=3
  \xspcode`^^e2=3
  \xspcode`^^e3=3
  \xspcode`^^e4=3
  \xspcode`^^e5=3
  \xspcode`^^e6=3
  \xspcode`^^e7=3
  \xspcode`^^e8=3
  \xspcode`^^e9=3
  \xspcode`^^ea=3
  \xspcode`^^eb=3
  \xspcode`^^ec=3
  \xspcode`^^ed=3
  \xspcode`^^ee=3
  \xspcode`^^ef=3
  \xspcode`^^f0=3
  \xspcode`^^f1=3
  \xspcode`^^f2=3
  \xspcode`^^f3=3
  \xspcode`^^f4=3
  \xspcode`^^f5=3
  \xspcode`^^f6=3
  \xspcode`^^f7=3
  \xspcode`^^f8=3
  \xspcode`^^f9=3
  \xspcode`^^fa=3
  \xspcode`^^fb=3
  \xspcode`^^fc=3
  \xspcode`^^fd=3
  \xspcode`^^fe=3
  \xspcode`^^ff=3
  \def\@{\spacefactor3000\space}
  \let\footnotes@ve=\footnote
  \def\footnote{\inhibitglue\footnotes@ve}
  \let\footnotemarks@ve=\footnotemark
  \def\footnotemark{\inhibitglue\footnotemarks@ve}
  \def\@inhibitglue{%
    \futurelet\@let@token\@@inhibitglue}
  \def\@@inhibitglue{%
    \ifx\@let@token「
      \inhibitglue
    \else
      \ifx\@let@token（
        \inhibitglue
      \else
        \ifx\@let@token『
          \inhibitglue
        \else
          \ifx\@let@token［
            \inhibitglue
          \fi
        \fi
      \fi
    \fi}
  \let\everyparhook=\@inhibitglue
  \setlength\parskip{0\p@}
  \setlength\parindent{1zw}
  \let\@startsection@orig\@startsection
  \def\@startsection{\@afterindenttrue\@startsection@orig}
  \AtBeginDocument{\everypar{\everyparhook}}
\else
  \IfFileExists{microtype.sty}{\RequirePackage[protrusion=true,expansion=false]{microtype}}{}
\fi\fi
%%%
\definecolor{linkcolour}{rgb}{0,0.2,0.6}
\hypersetup{colorlinks,breaklinks,
            linkcolor=linkcolour,citecolor=linkcolour,
            filecolor=linkcolour, urlcolor=linkcolour}
\IfFileExists{switcheml.sty}
             {\RequirePackage{switcheml}
              \AtBeginDocument{\@ifx@undefined{\typesetemail}{\obfuscateemail}{}}}
             {\AtBeginDocument{\@ifx@undefined{\typesetemail}{\hyperlinkemail}{}}}
\renewcommand\maketitle{\par
  \ifajt@noabstract\else
    \@ifx@undefined{\ajt@info@Abstract}
      {\ClassError{ajt}
        {Please specify an \string\abstract\space before \string\maketitle}
        {It is a Asian Journal of TeX requirement to include an abstract.   \MessageBreak
                                                                       \MessageBreak
         If you have exceptional reasons for not having one in this    \MessageBreak
         article, write \string\noabstract\space somewhere before \string\maketitle.}}{}
  \fi
  \begingroup
    \renewcommand\thefootnote{\@fnsymbol\c@footnote}%
    \def\@makefnmark{\rlap{\@textsuperscript{\normalfont\@thefnmark}}}%
    \long\def\@makefntext##1{\parindent 1em\noindent
            \hb@xt@1.8em{%
                \hss\@textsuperscript{\normalfont\@thefnmark}}##1}%
    \newpage
    \global\@topnum\z@   % Prevents figures from going at top of page.
    \@maketitle
    \thispagestyle{titlepage}\@thanks
  \endgroup
  \setcounter{footnote}{0}%
  \global\let\thanks\relax
  \global\let\maketitle\relax
  \global\let\@maketitle\relax
  \global\let\title\relax
  \global\let\author\relax
  \global\let\date\relax
  \global\let\and\relax
  \if@korean\koreanbodyspread\fi
  \if@ptexjs\ptexjsbodyspread\fi
}%
\def\@maketitle{%
  \newpage
  \null
  \write@ID@aux\read@issue
  \begin{flushleft}
    \let\footnote\thanks
    \begingroup
      \LARGE\@title
      \ifx\@empty\@etitle\else
        \settowidth\@tempdima{\@title}%
        \settowidth\@tempdimb{\@etitle}%
        \advance\@tempdima\@tempdimb
        \ifdim\@tempdima>\textwidth\\[-0.1\baselineskip]\noindent\thinspace
          \vtop{%
            \setlength\hsize{\textwidth-2em}%
            \normalbodyspread\large\@etitle}
        \else\enspace
          {\normalbodyspread\large\@etitle}
        \fi
      \fi\par
    \endgroup
    \vspace{24pt}%
    \@tempcnta\z@\loop\ifnum\@tempcnta<\value{num@author}\@makeauthors\repeat
  \end{flushleft}
  \ajt@optional@author@info
  \vspace{12pt}
  \ajt@info@container{Keywords}
  \ifajt@noabstract\else
    \vspace{12pt}%
    \ajt@info@container{Abstract}
  \fi
  \vspace{24pt}}
\def\@makeauthors{%
  \advance\@tempcnta\@ne
  \def\@author{{\large\csname @author\the\@tempcnta\endcsname}}%
  \def\@eauthor{{\normalsize\csname @eauthor\the\@tempcnta\endcsname}}%
  \def\@address{\csname @address\the\@tempcnta\endcsname}%
  \def\@email{\csname @email\the\@tempcnta\endcsname}%
  \begin{minipage}[t]{\ifnum\value{num@author}>1 0.5\fi\textwidth}
    \small
    \@author
    \ifx\@empty\@eauthor\else\enspace\@eauthor\fi
    \\[0.3\baselineskip]
    \ifx\@empty\@address\else
      \settowidth\@tempdima{\@address}%
      \@address
      \ifdim\@tempdima>0.5\textwidth\\\else\enspace\fi
    \fi
    \ifx\@empty\@email\else\typesetemail\@email\fi
  \end{minipage}\hfill
  \ifodd\@tempcnta\else\par\vspace{\baselineskip}\fi
}
\newcounter{num@author}\setcounter{num@author}{0}
\renewcommand*{\title}[2][]{\gdef\@etitle{#1}\gdef\@title{#2}}
\renewcommand*{\author}[2][]{%
  \stepcounter{num@author}%
  \expandafter\gdef\csname @eauthor\thenum@author\endcsname{#1}%
  \expandafter\gdef\csname @author\thenum@author\endcsname{#2}%
}
\newcommand*{\address}[1]{%
  \expandafter\gdef\csname @address\thenum@author\endcsname{#1}%
}
\newcommand*{\email}[1]{%
  \expandafter\gdef\csname @email\thenum@author\endcsname{#1}%
}
\if@ptexjs
\renewcommand\section{\@startsection {section}{1}{\z@}%
                                     {3.5ex \@plus 1ex \@minus .2ex}%
                                     {2.5ex \@plus.2ex}%
                                     {\normalfont\sffamily\bfseries\large\raggedright}}
\renewcommand\subsection{\@startsection{subsection}{2}{\z@}%
                                     {2.5ex \@plus 1ex \@minus .2ex}%
                                     {1.5ex \@plus .2ex}%
                                     {\normalfont\sffamily\bfseries\raggedright}}
\renewcommand\subsubsection{\@startsection{subsubsection}{3}{\z@}%
                                     {2ex \@plus .5ex \@minus .2ex}%
                                     {1ex \@plus .2ex}%
                                     {\normalfont\normalsize\raggedright}}
\renewcommand\paragraph{\@startsection{paragraph}{4}{\z@}%
                                     {2.5ex \@plus1ex \@minus.2ex}%
                                     {-1em}%
                                     {\normalfont\normalsize\sffamily\itshape}}
\renewcommand\subparagraph{\@startsection{subparagraph}{5}{\z@}%
                                     {2.5ex \@plus1ex \@minus .2ex}%
                                     {-1em}%
                                     {\normalfont\normalsize\sffamily\itshape}}
\else
\renewcommand\section{\@startsection {section}{1}{\z@}%
                                     {-3.5ex \@plus -1ex \@minus -.2ex}%
                                     {2.5ex \@plus.2ex}%
                                     {\normalfont\bfseries\large\raggedright}}
\renewcommand\subsection{\@startsection{subsection}{2}{\z@}%
                                     {-2.5ex\@plus -1ex \@minus -.2ex}%
                                     {1.5ex \@plus .2ex}%
                                     {\normalfont\bfseries\raggedright}}
\renewcommand\subsubsection{\@startsection{subsubsection}{3}{\z@}%
                                     {-2ex\@plus -.5ex \@minus -.2ex}%
                                     {1ex \@plus .2ex}%
                                     {\normalfont\normalsize\raggedright}}
\renewcommand\paragraph{\@startsection{paragraph}{4}{\z@}%
                                     {2.5ex \@plus1ex \@minus.2ex}%
                                     {-1em}%
                                     {\normalfont\normalsize\itshape}}
\renewcommand\subparagraph{\@startsection{subparagraph}{5}{\parindent}%
                                     {2.5ex \@plus1ex \@minus .2ex}%
                                     {-1em}%
                                     {\normalfont\normalsize\itshape}}
\fi
\let\ajt@itemize\itemize
\let\ajt@enditemize\enditemize
\let\ajt@enum\enumerate
\let\ajt@endenum\endenumerate
\let\ajt@desc\description
\let\ajt@enddesc\enddescription
\renewenvironment{itemize}
  {\ajt@itemize\parskip0pt}{\ajt@enditemize}
\renewenvironment{enumerate}
  {\ajt@enum\parskip0pt}{\ajt@endenum}
\renewenvironment{description}
  {\ajt@desc\parskip0pt\parindent1.8em}{\ajt@enddesc}
\let\itemise\itemize
\let\enditemise\enditemize
\renewcommand\labelitemi{\normalfont\bfseries\textendash}
\renewcommand\labelitemii{\normalfont\bfseries\textperiodcentered}
\if@ptexjs
  \renewcommand*\descriptionlabel[1]{\hspace\labelsep\normalfont\gtfamily\itshape #1}
\else
  \renewcommand*\descriptionlabel[1]{\hspace\labelsep\normalfont\itshape #1}
\fi
\newlength\captionindent
\if@ptexjs
  \setlength\captionindent{1pc}
  \setlength\abovecaptionskip{5\p@}
  \setlength\belowcaptionskip{5\p@}
  \newcommand*\@captionheadfont{\ptexjsinfospread\small\scshape}
  \newcommand*\@captionfont{\ptexjsinfospread\normalfont\small}
\else
  \setlength\captionindent{3pc}
  \setlength\abovecaptionskip{10\p@}
  \setlength\belowcaptionskip{0\p@}
  \newcommand*\@captionheadfont{\scshape}
  \newcommand*\@captionfont{\normalfont}
\fi
\long\def\@makecaption#1#2{%
  \setbox\@tempboxa\vbox{\color@setgroup
    \advance\hsize-2\captionindent\noindent
    \@captionfont\@captionheadfont#1\@xp\@ifnotempty\@xp
        {\@cdr#2\@nil}{.\@captionfont\upshape\enspace#2}%
    \unskip\kern-2\captionindent\par
    \global\setbox\@ne\lastbox\color@endgroup}%
  \ifhbox\@ne % the normal case
    \setbox\@ne\hbox{\unhbox\@ne\unskip\unskip\unpenalty\unkern}%
  \fi
  \ifdim\wd\@tempboxa=\z@ % this means caption will fit on one line
    \setbox\@ne\hbox to\columnwidth{\hss\kern-2\captionindent\box\@ne\hss}%
  \else % tempboxa contained more than one line
    \setbox\@ne\vbox{\unvbox\@tempboxa\parskip\z@skip
        \noindent\unhbox\@ne\advance\hsize-2\captionindent\par}%
  \fi
  \ifnum\@tempcnta<64 % if the float IS a figure...
    \addvspace\abovecaptionskip
    \hbox to\hsize{\kern\captionindent\box\@ne\hss}%
  \else % if the float IS NOT a figure...
    \hbox to\hsize{\kern\captionindent\box\@ne\hss}%
    \nobreak
    \vskip\belowcaptionskip
  \fi
\relax
}
\renewcommand\@footnotetext[1]{\insert\footins{%
    \if@korean\linespread{\korean@info@spread}\fi%
    \if@ptexjs\linespread{\ptexjs@info@spread}\fi%
    \reset@font\footnotesize
    \interlinepenalty\interfootnotelinepenalty
    \splittopskip\footnotesep
    \splitmaxdepth \dp\strutbox \floatingpenalty \@MM
    \hsize\columnwidth \@parboxrestore
    \protected@edef\@currentlabel{%
       \csname p@footnote\endcsname\@thefnmark
    }%
    \color@begingroup
      \@makefntext{%
        \rule\z@\footnotesep\ignorespaces#1\@finalstrut\strutbox}%
    \color@endgroup}}%
\renewcommand\@makefntext[1]{%
  \parindent 1.8em%
  \noindent
  \hb@xt@1.8em{\hbox{\strut\normalfont\footnotesize\@thefnmark.}\hss}#1}
\def\@ifx@empty#1{% Implicit #2#3
  \ifx#1\@empty
    \expandafter\@firstoftwo
  \else
    \expandafter\@secondoftwo
  \fi}%
\def\@ifx@undefined#1{% Implicit #2#3
  \ifx#1\@undefined
    \expandafter\@firstoftwo
  \else
    \expandafter\@secondoftwo
  \fi}%
\def\@ifeof#1{% Implicit #2#3
 \ifeof#1
   \expandafter\@firstoftwo
 \else
   \expandafter\@secondoftwo
 \fi}%
\def\boolean@true#1{\let#1\@firstoftwo}%
\def\boolean@false#1{\let#1\@secondoftwo}%
\def\ps@titlepage{%
  \def\@oddhead{\titlepage@head\hfil}%
  \let\@evenhead\@oddhead
  \def\@oddfoot{\hfil\titlepage@foot}%
  \let\@evenfoot\@oddfoot}%
\def\titlepage@head{\footnotesize
  \parbox{\linewidth}{%
    \normalbodyspread
    \@ifx@empty\@AJTissue{For submission to \AJT}{\AJT, \@AJTissue\hfill\raisebox{-\height+.6\baselineskip}[0pt][0pt]{\@KTSlogo}}\par
    \@ifx@empty\@AJTissue
       {\@ifx@empty\@AJTrevision{Draft of \today}{Article revision \@AJTrevision}}%
       {\@ifx@empty\@AJTrevision
          {\ClassError{ajt}
            {\string\AJTrevision\space must be defined if
             \string\AJTissue\space is also}
            {It is a requirement for PracTeX Journal articles to contain\MessageBreak
             revision information for version tracking. Please input this\MessageBreak
             information, or omit \protect\AJTissue.}}
          {Article revision \@AJTrevision}}}}%
\def\titlepage@foot{%
  \vtop{\raggedleft\footnotesize\@AJTcopyright}}%
\def\odd@heading@rule{\makebox[0pt][l]{\rule[-3.5pt]{\textwidth}{0.3pt}}}%
\let\even@heading@rule\odd@heading@rule
\def\ps@headings{%
  \def\@oddhead{\odd@heading@rule\small\scshape\@AJTissue\hfil\thepage}%
  \def\@evenhead{\even@heading@rule\small\scshape\thepage\hfil\AJT}%
  \let\@oddfoot\@empty
  \let\@evenfoot\@oddfoot}%
\renewcommand{\topfraction}{.85}
\renewcommand{\bottomfraction}{.7}
\renewcommand{\textfraction}{.15}
\renewcommand{\floatpagefraction}{.66}
\renewcommand{\dbltopfraction}{.66}
\renewcommand{\dblfloatpagefraction}{.66}
\setcounter{topnumber}{9}
\setcounter{bottomnumber}{9}
\setcounter{totalnumber}{20}
\setcounter{dbltopnumber}{9}
\newcommand\addinfo[2][]{%
  \ajt@define@info@block[#1]{#2}%
  \g@addto@macro\ajt@optional@author@info{\ajt@info@container[#1]{#2}}}
\newcommand\addinfospace[1]{\g@addto@macro\ajt@optional@author@info{\vspace{#1}}}
\newcommand\ajt@define@info@block[2][]{%
  \lowercase{\expandafter\long\expandafter\def\csname#2\endcsname}%
  ##1{\expandafter\def\csname ajt@info@#2\endcsname{##1}}}
\newcommand\clearinfo{\let\ajt@optional@author@info\@empty}
\clearinfo
%\addinfo[\typesetemail]{Email}
%\addinfo[\url]{Website}
%\addinfo[\linespread{0.9}\selectfont]{Address}
\ajt@define@info@block{Keywords}
\ajt@define@info@block{Abstract}
\newif\ifajt@noabstract
\newcommand\noabstract{\ajt@noabstracttrue}
\def\endabstract{%
  \ClassError{ajt}
   {Please input the abstract with \string\abstract{...}, before \string\begin{document}}
   {Instead of the \string\begin{abstract}...\string\end{abstract} \MessageBreak
    environment, use \string\abstract{...}. Paragraphs are allowed!\MessageBreak
                                                                   \MessageBreak
    Because the abstract is typeset with the title block,          \MessageBreak
    it must be input before the \string\begin{document}\space command.}}
\newcommand{\AJTissue}[3]{\gdef\@AJTissue{Volume #1, No.\thinspace #2, #3}}%
\newcommand{\AJTpage}[1]{\setcounter{page}{#1}}%
\newcommand{\AJTlang}[1]{\gdef\@AJTlang{#1}}%
\newcommand{\AJTrevision}[3]{\gdef\@AJTrevision{#1/#2/#3}}%
\newcommand{\AJTcopyright}[1]{\gdef\@AJTcopyright{#1}}%
\def\logo@setup#1{%
  \IfFileExists{#1}
    {\def\@KTSlogo{\includegraphics[height=12mm]{#1}}}
    {\let\@KTSlogo\@empty}}%
\ifx\@dvi@driver\dps@driver
  \logo@setup{KTS-logo.eps}
\else
  \logo@setup{KTS-logo.pdf}
\fi
\let\@AJTissue\@empty
\let\@AJTrevision\@empty
\let\@AJTcopyright\@empty
\let\license\AJTcopyright
\newcommand\ajt@info@container[2][]{%
  \lowercase{\expandafter\gdef\csname#2\endcsname}%
    {\ClassError{ajt}{#2 must be defined BEFORE \string\maketitle}{}}
  \expandafter\ifx\csname ajt@info@#2\endcsname\relax\else
    \noindent\small
    \begin{minipage}[t]{0.12\textwidth}
      \noindent\rmfamily\scshape#2\hfill
    \end{minipage}\hfill
    \begin{minipage}[t]{0.85\textwidth}
      \if@korean\if@korabstract\koreanbodyspread\else\koreaninfospread\fi\fi
      \if@ptexjs\if@ptexjsabstract\ptexjsbodyspread\else\ptexjsinfospread\fi\fi
      \setlength\parindent{1.8em}%
      \noindent\ignorespaces
      \expandafter#1\expandafter{\csname ajt@info@#2\endcsname}
    \end{minipage}\par
  \fi}
\newcommand\obfuscateemail{%
  \def\typesetemail##1{\ttfamily\switchemail{##1}}}
\newcommand\hyperlinkemail{%
  \def\typesetemail##1{\ttfamily\ajt@compose@mailto{##1}{Re: AJT article}{##1}}}
\newcommand\ajt@compose@mailto[3]{%
  \edef\@tempa{mailto:#1?subject=#2 }%
  \edef\@tempb{\expandafter\html@spaces\@tempa\@empty}%
  \href{\@tempb}{#3}}

\catcode`\%=11
\def\html@spaces#1 #2{#1%20\ifx#2\@empty\else\expandafter\html@spaces\fi#2}
\catcode`\%=14
\newcommand\note[1]{\unskip\footnote{#1}}
\DeclareRobustCommand\dash{%
  \unskip\nobreak\thinspace\textemdash\thinspace\ignorespaces}
%\pdfstringdefDisableCommands{\renewcommand{\dash}{ - }}
\newcommand\ctanfile[1]{%
  \href{http://www.ctan.org/get?fn=/#1}
       {\path{CTAN:#1}}}
\newcommand\ctanloc[1]{%
  \href{http://www.ctan.org/tex-archive/#1}
       {\path{CTAN:#1}}}
\ifx\@dvi@driver\xtx@driver\else % not XeTeX
  \DeclareTextSymbol{\textbackslash}{OT1}{`\\}
  \DeclareTextSymbol{\textbraceleft}{OT1}{`\{}
  \DeclareTextSymbol{\textbraceright}{OT1}{`\}}
\fi
\newcommand\cs[1]{%
  \texttt{\textbackslash#1}}
\DeclareRobustCommand\TeX{T\kern-.15em\lower.5ex\hbox{E}\kern-.07em X\spacefactor1000\relax}
\DeclareRobustCommand\eTeX{\ensuremath{\varepsilon}-\kern-.125em\TeX}
\DeclareRobustCommand\LaTeX{L\kern-.32em\raise.37ex\hbox{\scalebox{0.76}{A}}\kern-.15em\TeX}
\DeclareRobustCommand\LaTeXe{\LaTeX2$_{\textstyle\varepsilon}$}
\DeclareRobustCommand\LuaTeX{Lua\TeX}
\DeclareRobustCommand\LuaLaTeX{Lua\LaTeX}
\DeclareRobustCommand\kotex{\textsf{k}\textit{o}\kern-1pt\lower.15ex\hbox{.}\kern-1pt\TeX}
\DeclareRobustCommand\xetexko{\XeTeX-\textsf{k}\textit{o}}
\DeclareRobustCommand\luatexko{\LuaTeX-\textsf{k}\textit{o}}
\DeclareRobustCommand\BibTeX{B{\textsc i\kern-.025em\textsc b}\kern-.08em\TeX}
\DeclareRobustCommand\logofamily{%
  \not@math@alphabet\logofamily\relax
  \fontencoding{U}\fontfamily{logo}\selectfont}
\DeclareTextFontCommand{\textlogo}{\logofamily}
\DeclareRobustCommand\MF{\textlogo{META}\@dischyph\textlogo{FONT}\@}
\DeclareRobustCommand\MP{\textlogo{META}\@dischyph\textlogo{POST}\@}
\DeclareRobustCommand\ConTeXt{C\kern-.03em on\-\kern-.10em\TeX\kern-0.04em t}%
\DeclareRobustCommand\pdfTeX{pdf\/\TeX}
\DeclareRobustCommand\pdfeTeX{pdf\/\eTeX}
\DeclareRobustCommand\pdfLaTeX{pdf\/\LaTeX}
\DeclareRobustCommand\PS{PostScript}
\DeclareRobustCommand\PracTeX{Prac\kern-0.07em\TeX}
\DeclareRobustCommand\pTeX{p\kern-0.05em\TeX}
\DeclareRobustCommand\AJT{The Asian Journal of \TeX}
\DeclareRobustCommand\XeTeX{%
      X\lower.5ex\hbox{\kern-.07em\reflectbox{E}}%
      \kern-.15em\TeX}
\DeclareRobustCommand\ExTeX{\textrm{\relax
 \ensuremath{\textstyle\varepsilon_{\kern-0.15em\mathcal{X}}}\relax
 \kern-.15em\TeX}}
\def\write@ID@aux{%
 \@ifx@empty\@AJTrevision{}{%
  \begingroup
   \let\thanks\@gobble
   \immediate\openout\ID@aux _rev.tex
   \immediate\write\ID@aux{\@AJTrevision}%
   \immediate\closeout\ID@aux
  \endgroup
 }%
}%
\newwrite\ID@aux
\def\read@issue{%
 \openin\@inputcheck _iss.tex
 \@ifeof\@inputcheck{}
   {\ifx\@AJTissue\@empty\else
      \typeout{---------^^J
               ajt: \protect\AJTissue\space info overwritten due to _iss.tex file^^J
               ---------}
    \fi
    \read\@inputcheck to\@AJTissue
    \closein\@inputcheck
    \expandafter\parse@iss\@AJTissue\@nil}}
\def\parse@iss AJT #1 No #2, #3-#4-#5\@nil{%
  \@tempcnta#2\relax
  \protected@xdef\@AJTissue{\AJT, #1, No.\thinspace\the\@tempcnta}}
\def\set@pdfpage{%
  \ifx\@dvi@driver\tpd@driver
    \@ifx@undefined\pdfoutput{}{%
      \pdfpagewidth =\paperwidth
      \pdfpageheight=\paperheight
    \relax}%
  \else
    \special{papersize=\the\paperwidth,\the\paperheight}%
  \fi}
\AtBeginDocument{\if@print\else\set@pdfpage\fi}
\let\thebibliography@ltx\thebibliography
\let\endthebibliography@ltx\endthebibliography
\renewenvironment{thebibliography}[1]
  {\if@korean\normalbodyspread\renewcommand{\refname}{참고 문헌}\fi%
   \if@ptexjs\ptexjsinfospread\renewcommand{\refname}{参考文献}\fi%
   \thebibliography@ltx{#1}\setlength{\itemsep}{0pt}\small}
  {\endthebibliography@ltx}
\renewcommand\@biblabel[1]{#1.}
\def\head@setup#1{%
  \IfFileExists{#1}
    {\def\@AJThead{\includegraphics[width=.25\textwidth]{#1}}}
    {\let\@AJThead\@empty}}%
\ifx\@dvi@driver\dps@driver
  \head@setup{AJT-head.eps}
\else
  \head@setup{AJT-head.pdf}
\fi
\newcommand*\putAJThead[1]{%
  \raisebox{-\textheight-3em}[0pt][0pt]{%
    \makebox[0pt][l]{\hspace*{-3em}\@AJThead}%
  }%
}
\if@reprint
  \let\cleardoublepage\relax
\else
  \renewcommand\cleardoublepage{\clearpage\if@twoside\ifodd\c@page\else
    \pagestyle{empty}\noindent\putAJThead\newpage\if@twocolumn\hbox{}\newpage\fi\fi\fi}
\fi
\pagestyle{headings}
\endinput
%%
%% End of file `ajt.cls'.
