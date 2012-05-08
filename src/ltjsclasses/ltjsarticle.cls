%%
%% This is file `ltjsarticle.cls',
%% generated with the docstrip utility.
%%
%% The original source files were:
%%
%% ltjsclasses.dtx  (with options: `article')
%% 
%% IMPORTANT NOTICE:
%% 
%% For the copyright see the source file.
%% 
%% Any modified versions of this file must be renamed
%% with new filenames distinct from ltjsarticle.cls.
%% 
%% For distribution of the original source see the terms
%% for copying and modification in the file ltjsclasses.dtx.
%% 
%% This generated file may be distributed as long as the
%% original source files, as listed above, are part of the
%% same distribution. (The sources need not necessarily be
%% in the same archive or directory.)
%% File: ltjsclasses.dtx
%% \CharacterTable
%%  {Upper-case    \A\B\C\D\E\F\G\H\I\J\K\L\M\N\O\P\Q\R\S\T\U\V\W\X\Y\Z
%%   Lower-case    \a\b\c\d\e\f\g\h\i\j\k\l\m\n\o\p\q\r\s\t\u\v\w\x\y\z
%%   Digits        \0\1\2\3\4\5\6\7\8\9
%%   Exclamation   \!     Double quote  \"     Hash (number) \#
%%   Dollar        \$     Percent       \%     Ampersand     \&
%%   Acute accent  \'     Left paren    \(     Right paren   \)
%%   Asterisk      \*     Plus          \+     Comma         \,
%%   Minus         \-     Point         \.     Solidus       \/
%%   Colon         \:     Semicolon     \;     Less than     \<
%%   Equals        \=     Greater than  \>     Question mark \?
%%   Commercial at \@     Left bracket  \[     Backslash     \\
%%   Right bracket \]     Circumflex    \^     Underscore    \_
%%   Grave accent  \`     Left brace    \{     Vertical bar  \|
%%   Right brace   \}     Tilde         \~}
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ltjsarticle}
  [2012/05/08 ]
\RequirePackage{luatexja}
\newif\if@restonecol
\newif\if@titlepage
\newif\if@enablejfam \@enablejfamtrue
\DeclareOption{a3paper}{%
  \setlength\paperheight {420mm}%
  \setlength\paperwidth  {297mm}}
\DeclareOption{a4paper}{%
  \setlength\paperheight {297mm}%
  \setlength\paperwidth  {210mm}}
\DeclareOption{a5paper}{%
  \setlength\paperheight {210mm}%
  \setlength\paperwidth  {148mm}}
\DeclareOption{a6paper}{%
  \setlength\paperheight {148mm}%
  \setlength\paperwidth  {105mm}}
\DeclareOption{b4paper}{%
  \setlength\paperheight {364mm}%
  \setlength\paperwidth  {257mm}}
\DeclareOption{b5paper}{%
  \setlength\paperheight {257mm}%
  \setlength\paperwidth  {182mm}}
\DeclareOption{b6paper}{%
  \setlength\paperheight {182mm}%
  \setlength\paperwidth  {128mm}}
\DeclareOption{a4j}{%
  \setlength\paperheight {297mm}%
  \setlength\paperwidth  {210mm}}
\DeclareOption{a5j}{%
  \setlength\paperheight {210mm}%
  \setlength\paperwidth  {148mm}}
\DeclareOption{b4j}{%
  \setlength\paperheight {364mm}%
  \setlength\paperwidth  {257mm}}
\DeclareOption{b5j}{%
  \setlength\paperheight {257mm}%
  \setlength\paperwidth  {182mm}}
\DeclareOption{a4var}{%
  \setlength\paperheight {283mm}%
  \setlength\paperwidth  {210mm}}
\DeclareOption{b5var}{%
  \setlength\paperheight {230mm}%
  \setlength\paperwidth  {182mm}}
\DeclareOption{letterpaper}{%
  \setlength\paperheight {11in}%
  \setlength\paperwidth  {8.5in}}
\DeclareOption{legalpaper}{%
  \setlength\paperheight {14in}%
  \setlength\paperwidth  {8.5in}}
\DeclareOption{executivepaper}{%
  \setlength\paperheight {10.5in}%
  \setlength\paperwidth  {7.25in}}
\newif\if@landscape
\@landscapefalse
\DeclareOption{landscape}{\@landscapetrue}
\newif\if@slide
\@slidefalse
\newcommand{\@ptsize}{0}
\DeclareOption{slide}{\@slidetrue\renewcommand{\@ptsize}{26}\@landscapetrue\@titlepagetrue}
\DeclareOption{8pt}{\renewcommand{\@ptsize}{-2}}
\DeclareOption{9pt}{\renewcommand{\@ptsize}{-1}}
\DeclareOption{10pt}{\renewcommand{\@ptsize}{0}}
\DeclareOption{11pt}{\renewcommand{\@ptsize}{1}}
\DeclareOption{12pt}{\renewcommand{\@ptsize}{2}}
\DeclareOption{14pt}{\renewcommand{\@ptsize}{4}}
\DeclareOption{17pt}{\renewcommand{\@ptsize}{7}}
\DeclareOption{20pt}{\renewcommand{\@ptsize}{10}}
\DeclareOption{21pt}{\renewcommand{\@ptsize}{11}}
\DeclareOption{25pt}{\renewcommand{\@ptsize}{15}}
\DeclareOption{30pt}{\renewcommand{\@ptsize}{20}}
\DeclareOption{36pt}{\renewcommand{\@ptsize}{26}}
\DeclareOption{43pt}{\renewcommand{\@ptsize}{33}}
\DeclareOption{12Q}{\renewcommand{\@ptsize}{1200}}
\DeclareOption{14Q}{\renewcommand{\@ptsize}{1400}}
\hour\time \divide\hour by 60\relax
\@tempcnta\hour \multiply\@tempcnta 60\relax
\minute\time \advance\minute-\@tempcnta
\DeclareOption{tombow}{%
  \tombowtrue \tombowdatetrue
  \setlength{\@tombowwidth}{.1\p@}%
  \@bannertoken{%
     \jobname\space(\number\year-\two@digits\month-\two@digits\day
     \space\two@digits\hour:\two@digits\minute)}%
  \maketombowbox}
\DeclareOption{tombo}{%
  \tombowtrue \tombowdatefalse
  \setlength{\@tombowwidth}{.1\p@}%
  \maketombowbox}
\DeclareOption{mentuke}{%
  \tombowtrue \tombowdatefalse
  \setlength{\@tombowwidth}{\z@}%
  \maketombowbox}
\DeclareOption{oneside}{\@twosidefalse \@mparswitchfalse}
\DeclareOption{twoside}{\@twosidetrue \@mparswitchtrue}
\DeclareOption{vartwoside}{\@twosidetrue \@mparswitchfalse}
\DeclareOption{onecolumn}{\@twocolumnfalse}
\DeclareOption{twocolumn}{\@twocolumntrue}
\DeclareOption{titlepage}{\@titlepagetrue}
\DeclareOption{notitlepage}{\@titlepagefalse}
\def\eqnarray{%
   \stepcounter{equation}%
   \def\@currentlabel{\p@equation\theequation}%
   \global\@eqnswtrue
   \m@th
   \global\@eqcnt\z@
   \tabskip\@centering
   \let\\\@eqncr
   $$\everycr{}\halign to\displaywidth\bgroup
       \hskip\@centering$\displaystyle\tabskip\z@skip{##}$\@eqnsel
      &\global\@eqcnt\@ne \hfil$\displaystyle{{}##{}}$\hfil
      &\global\@eqcnt\tw@ $\displaystyle{##}$\hfil\tabskip\@centering
      &\global\@eqcnt\thr@@ \hb@xt@\z@\bgroup\hss##\egroup
         \tabskip\z@skip
      \cr}
\DeclareOption{leqno}{\input{leqno.clo}}
\DeclareOption{fleqn}{\input{fleqn.clo}%
  \def\eqnarray{%
    \stepcounter{equation}%
    \def\@currentlabel{\p@equation\theequation}%
    \global\@eqnswtrue\m@th
    \global\@eqcnt\z@
    \tabskip\mathindent
    \let\\=\@eqncr
    \setlength\abovedisplayskip{\topsep}%
    \ifvmode
      \addtolength\abovedisplayskip{\partopsep}%
    \fi
    \addtolength\abovedisplayskip{\parskip}%
    \setlength\belowdisplayskip{\abovedisplayskip}%
    \setlength\belowdisplayshortskip{\abovedisplayskip}%
    \setlength\abovedisplayshortskip{\abovedisplayskip}%
    $$\everycr{}\halign to\linewidth% $$
    \bgroup
      \hskip\@centering$\displaystyle\tabskip\z@skip{##}$\@eqnsel
      &\global\@eqcnt\@ne \hfil$\displaystyle{{}##{}}$\hfil
      &\global\@eqcnt\tw@
        $\displaystyle{##}$\hfil \tabskip\@centering
      &\global\@eqcnt\thr@@ \hb@xt@\z@\bgroup\hss##\egroup
    \tabskip\z@skip\cr
    }}
\DeclareOption{disablejfam}{%
  \ClassWarningNoLine{\@currname}{The class option 'disablejfam' is obsolete}}
\newif\ifdraft
\DeclareOption{draft}{\drafttrue \setlength\overfullrule{5pt}}
\DeclareOption{final}{\draftfalse \setlength\overfullrule{0pt}}
\newif\ifmingoth
\mingothfalse
\newif\ifjisfont
\jisfontfalse
\newif\ifptexjis
\ptexjisfalse
\DeclareOption{winjis}{%
  \ClassWarningNoLine{\@currname}{The class option 'winjis' is obsolete}}
\DeclareOption{uplatex}{%
  \ClassWarningNoLine{\@currname}{The class option 'uplatex' is obsolete}}
\DeclareOption{mingoth}{\mingothtrue}
\DeclareOption{ptexjis}{\ptexjistrue}
\DeclareOption{jis}{\jisfonttrue}
\newif\ifpapersize
\papersizefalse
\DeclareOption{papersize}{\papersizetrue}
\newif\if@english
\@englishfalse
\DeclareOption{english}{\@englishtrue}
\ExecuteOptions{a4paper,oneside,onecolumn,notitlepage,final}
\ProcessOptions
\if@slide
  \def\maybeblue{\@ifundefined{ver@color.sty}{}{\color{blue}}}
\fi
\if@landscape
  \setlength\@tempdima  {\paperheight}
  \setlength\paperheight{\paperwidth}
  \setlength\paperwidth {\@tempdima}
\fi
\if@slide\def\n@baseline{13}\else\def\n@baseline{16}\fi
\def\inv@mag{1}
\ifnum\@ptsize=-2
  \mag 833
  \def\inv@mag{1.20048}
  \def\n@baseline{15}%
\fi
\ifnum\@ptsize=-1
  \mag 913 % formerly 900
  \def\inv@mag{1.09529}
  \def\n@baseline{15}%
\fi
\ifnum\@ptsize=1
  \mag 1095 % formerly 1100
  \def\inv@mag{0.913242}
\fi
\ifnum\@ptsize=2
  \mag 1200
  \def\inv@mag{0.833333}
\fi
\ifnum\@ptsize=4
  \mag 1440
  \def\inv@mag{0.694444}
\fi
\ifnum\@ptsize=7
  \mag 1728
  \def\inv@mag{0.578704}
\fi
\ifnum\@ptsize=10
  \mag 2000
  \def\inv@mag{0.5}
\fi
\ifnum\@ptsize=11
  \mag 2074
  \def\inv@mag{0.48216}
\fi
\ifnum\@ptsize=15
  \mag 2488
  \def\inv@mag{0.401929}
\fi
\ifnum\@ptsize=20
  \mag 2986
  \def\inv@mag{0.334896}
\fi
\ifnum\@ptsize=26
  \mag 3583
  \def\inv@mag{0.279096}
\fi
\ifnum\@ptsize=33
  \mag 4300
  \def\inv@mag{0.232558}
\fi
\ifnum\@ptsize=1200
  \mag 923
  \def\inv@mag{1.0834236}
\fi
\ifnum\@ptsize=1400
  \mag 1077
  \def\inv@mag{0.928505}
\fi
\setlength\paperwidth{\inv@mag\paperwidth}%
\setlength\paperheight{\inv@mag\paperheight}%
\setlength{\@tempdima}{\paperwidth}
\setlength{\@tempdimb}{\paperheight}
\iftombow
  \advance \@tempdima 2in
  \advance \@tempdimb 2in
\fi
\setlength{\pdfpagewidth}{\@tempdima}
\setlength{\pdfpageheight}{\@tempdimb}
\expandafter\let\csname JY3/mc/m/n/10\endcsname\relax
\ifmingoth
  \DeclareFontShape{JY3}{mc}{m}{n}{<-> s * [0.924872] psft:Ryumin-Light:jfm=min}{}
  \DeclareFontShape{JY3}{gt}{m}{n}{<-> s * [0.924872] psft:GothicBBB-Medium:jfm=min}{}
\else
  \ifptexjis
    \DeclareFontShape{JY3}{mc}{m}{n}{<-> s * [0.924872] psft:Ryumin-Light:jfm=jis}{}
    \DeclareFontShape{JY3}{gt}{m}{n}{<-> s * [0.924872] psft:GothicBBB-Medium:jfm=jis}{}
  \else
    \DeclareFontShape{JY3}{mc}{m}{n}{<-> s * [0.924872] psft:Ryumin-Light:jfm=ujis}{}
    \DeclareFontShape{JY3}{gt}{m}{n}{<-> s * [0.924872] psft:GothicBBB-Medium:jfm=ujis}{}
  \fi
\fi
\DeclareFontShape{JY3}{mc}{bx}{n}{<->ssub*gt/m/n}{}
\DeclareFontShape{JY3}{gt}{bx}{n}{<->ssub*gt/m/n}{}
\DeclareFontShape{JY3}{mc}{m}{it}{<->ssub*mc/m/n}{}
\DeclareFontShape{JY3}{mc}{m}{sl}{<->ssub*mc/m/n}{}
\DeclareFontShape{JY3}{mc}{m}{sc}{<->ssub*mc/m/n}{}
\DeclareFontShape{JY3}{gt}{m}{it}{<->ssub*gt/m/n}{}
\DeclareFontShape{JY3}{gt}{m}{sl}{<->ssub*gt/m/n}{}
\DeclareFontShape{JY3}{mc}{bx}{it}{<->ssub*gt/m/n}{}
\DeclareFontShape{JY3}{mc}{bx}{sl}{<->ssub*gt/m/n}{}
%% \DeclareFontShape{JT3}{mc}{m}{it}{<->ssub*mc/m/n}{}
%% \DeclareFontShape{JT3}{mc}{m}{sl}{<->ssub*mc/m/n}{}
%% \DeclareFontShape{JT3}{mc}{m}{sc}{<->ssub*mc/m/n}{}
%% \DeclareFontShape{JT3}{gt}{m}{it}{<->ssub*gt/m/n}{}
%% \DeclareFontShape{JT3}{gt}{m}{sl}{<->ssub*gt/m/n}{}
%% \DeclareFontShape{JT3}{mc}{bx}{it}{<->ssub*gt/m/n}{}
%% \DeclareFontShape{JT3}{mc}{bx}{sl}{<->ssub*gt/m/n}{}
\DeclareRobustCommand\rmfamily
        {\not@math@alphabet\rmfamily\mathrm
         \romanfamily\rmdefault\kanjifamily\mcdefault\selectfont}
\DeclareRobustCommand\sffamily
        {\not@math@alphabet\sffamily\mathsf
         \romanfamily\sfdefault\kanjifamily\gtdefault\selectfont}
\DeclareRobustCommand\ttfamily
        {\not@math@alphabet\ttfamily\mathtt
         \romanfamily\ttdefault\kanjifamily\gtdefault\selectfont}
%%
\AtBeginDocument{%
  \reDeclareMathAlphabet{\mathrm}{\mathrm}{\mathmc}
  \reDeclareMathAlphabet{\mathbf}{\mathbf}{\mathgt}}%
\ltjsetparameter{jaxspmode={`〒,2}}
\ltjsetparameter{alxspmode={`+,3}}
\ltjsetparameter{alxspmode={`\%,3}}
\def\@{\spacefactor3000\space}
\def\@setfontsize#1#2#3{%
  \ifx\protect\@typeset@protect
    \let\@currsize#1%
  \fi
  \fontsize{#2}{#3}\selectfont
  \ifdim\parindent>\z@
    \if@english
      \parindent=1em
    \else
      \parindent=1\zw
    \fi
  \fi
  \ltjsetparameter{kanjiskip={0\zw plus .1\zw minus .01\zw}}
  \if@slide \ltjsetparameter{xkanjiskip={0.1em}} \else
    \ltjsetparameter{xkanjiskip={0.25em plus 0.15em minus 0.06em}}
  \fi}
\emergencystretch 3\zw
\newif\ifnarrowbaselines
\if@english
  \narrowbaselinestrue
\fi
\def\narrowbaselines{%
  \narrowbaselinestrue
  \skip0=\abovedisplayskip
  \skip2=\abovedisplayshortskip
  \skip4=\belowdisplayskip
  \skip6=\belowdisplayshortskip
  \@currsize\selectfont
  \abovedisplayskip=\skip0
  \abovedisplayshortskip=\skip2
  \belowdisplayskip=\skip4
  \belowdisplayshortskip=\skip6\relax}
\def\widebaselines{\narrowbaselinesfalse\@currsize\selectfont}
\renewcommand{\normalsize}{%
  \ifnarrowbaselines
    \@setfontsize\normalsize\@xpt\@xiipt
  \else
    \@setfontsize\normalsize\@xpt{\n@baseline}%
  \fi
  \abovedisplayskip 11\p@ \@plus3\p@ \@minus4\p@
  \abovedisplayshortskip \z@ \@plus3\p@
  \belowdisplayskip 9\p@ \@plus3\p@ \@minus4\p@
  \belowdisplayshortskip \belowdisplayskip
  \let\@listi\@listI}
\normalsize
\setbox0\hbox{\char"3000}% 全角スペース
\setlength\Cht{\ht0}
\setlength\Cdp{\dp0}
\setlength\Cwd{\wd0}
\setlength\Cvs{\baselineskip}
\setlength\Chs{\wd0}
\newcommand{\small}{%
  \ifnarrowbaselines
    \@setfontsize\small\@ixpt{11}%
  \else
    \@setfontsize\small\@ixpt{13}%
  \fi
  \abovedisplayskip 9\p@ \@plus3\p@ \@minus4\p@
  \abovedisplayshortskip  \z@ \@plus3\p@
  \belowdisplayskip \abovedisplayskip
  \belowdisplayshortskip \belowdisplayskip
  \def\@listi{\leftmargin\leftmargini
              \topsep \z@
              \parsep \z@
              \itemsep \parsep}}
\newcommand{\footnotesize}{%
  \ifnarrowbaselines
    \@setfontsize\footnotesize\@viiipt{9.5}%
  \else
    \@setfontsize\footnotesize\@viiipt{11}%
  \fi
  \abovedisplayskip 6\p@ \@plus2\p@ \@minus3\p@
  \abovedisplayshortskip  \z@ \@plus2\p@
  \belowdisplayskip \abovedisplayskip
  \belowdisplayshortskip \belowdisplayskip
  \def\@listi{\leftmargin\leftmargini
              \topsep \z@
              \parsep \z@
              \itemsep \parsep}}
\newcommand{\scriptsize}{\@setfontsize\scriptsize\@viipt\@viiipt}
\newcommand{\tiny}{\@setfontsize\tiny\@vpt\@vipt}
\if@twocolumn
  \newcommand{\large}{\@setfontsize\large\@xiipt{\n@baseline}}
\else
  \newcommand{\large}{\@setfontsize\large\@xiipt{17}}
\fi
\newcommand{\Large}{\@setfontsize\Large\@xivpt{21}}
\newcommand{\LARGE}{\@setfontsize\LARGE\@xviipt{25}}
\newcommand{\huge}{\@setfontsize\huge\@xxpt{28}}
\newcommand{\Huge}{\@setfontsize\Huge\@xxvpt{33}}
\newcommand{\HUGE}{\@setfontsize\HUGE{30}{40}}
\everydisplay=\expandafter{\the\everydisplay \narrowbaselines}
\newcommand{\headfont}{\gtfamily\sffamily}
\setlength\columnsep{2\zw}
\setlength\columnseprule{0\p@}
\setlength\lineskip{1\p@}
\setlength\normallineskip{1\p@}
\setlength\lineskiplimit{1\p@}
\setlength\normallineskiplimit{1\p@}
\renewcommand{\baselinestretch}{}
\setlength\parskip{0\p@}
\if@slide
  \setlength\parindent{0\zw}
\else
  \setlength\parindent{1\zw}
\fi
\@lowpenalty   51
\@medpenalty  151
\@highpenalty 301
\setlength\topskip{10\p@}
\if@slide
  \setlength\headheight{0\p@}
\else
  \setlength\headheight{2\topskip}
\fi
\if@slide
  \setlength\footskip{0pt}
\else
  \setlength\footskip{0.03367\paperheight}
  \ifdim\footskip<\baselineskip
    \setlength\footskip{\baselineskip}
  \fi
\fi
\if@slide
  \setlength\headsep{0\p@}
\else
  \setlength\headsep{\footskip}
  \addtolength\headsep{-\topskip}
\fi
\setlength\maxdepth{.5\topskip}
\newdimen\fullwidth
\if@slide
  \setlength\fullwidth{0.9\paperwidth}
\else
  \setlength\fullwidth{0.76\paperwidth}
\fi
\if@twocolumn \@tempdima=2\zw \else \@tempdima=1\zw \fi
\divide\fullwidth\@tempdima \multiply\fullwidth\@tempdima
\setlength\textwidth{\fullwidth}
\if@slide
  \setlength{\textheight}{0.95\paperheight}
\else
  \setlength{\textheight}{0.83\paperheight}
\fi
\addtolength{\textheight}{-\topskip}
\addtolength{\textheight}{-\headsep}
\addtolength{\textheight}{-\footskip}
\addtolength{\textheight}{-\topskip}
\divide\textheight\baselineskip
\multiply\textheight\baselineskip
\addtolength{\textheight}{\topskip}
\addtolength{\textheight}{0.1\p@}
\setlength\marginparsep{\columnsep}
\setlength\marginparpush{\baselineskip}
\setlength{\oddsidemargin}{\paperwidth}
\addtolength{\oddsidemargin}{-\fullwidth}
\setlength{\oddsidemargin}{.5\oddsidemargin}
\addtolength{\oddsidemargin}{-1in}
\setlength{\evensidemargin}{\oddsidemargin}
\if@mparswitch
  \addtolength{\evensidemargin}{\fullwidth}
  \addtolength{\evensidemargin}{-\textwidth}
\fi
\setlength\marginparwidth{\paperwidth}
\addtolength\marginparwidth{-\oddsidemargin}
\addtolength\marginparwidth{-1in}
\addtolength\marginparwidth{-\textwidth}
\addtolength\marginparwidth{-1cm}
\addtolength\marginparwidth{-\marginparsep}
\@tempdima=1\zw
\divide\marginparwidth\@tempdima
\multiply\marginparwidth\@tempdima
\setlength\topmargin{\paperheight}
\addtolength\topmargin{-\textheight}
\if@slide
  \addtolength\topmargin{-\headheight}
\else
  \addtolength\topmargin{-\topskip}
\fi
\addtolength\topmargin{-\headsep}
\addtolength\topmargin{-\footskip}
\setlength\topmargin{0.5\topmargin}
\addtolength\topmargin{-1in}
{\footnotesize\global\setlength\footnotesep{\baselineskip}}
\setlength\footnotesep{0.7\footnotesep}
\setlength{\skip\footins}{16\p@ \@plus 5\p@ \@minus 2\p@}
\setcounter{topnumber}{9}
\renewcommand{\topfraction}{.85}
\setcounter{bottomnumber}{9}
\renewcommand{\bottomfraction}{.8}
\setcounter{totalnumber}{20}
\renewcommand{\textfraction}{.1}
\renewcommand{\floatpagefraction}{.8}
\setcounter{dbltopnumber}{9}
\renewcommand{\dbltopfraction}{.8}
\renewcommand{\dblfloatpagefraction}{.8}
\setlength\floatsep    {12\p@ \@plus 2\p@ \@minus 2\p@}
\setlength\textfloatsep{20\p@ \@plus 2\p@ \@minus 4\p@}
\setlength\intextsep   {12\p@ \@plus 2\p@ \@minus 2\p@}
\setlength\dblfloatsep    {12\p@ \@plus 2\p@ \@minus 2\p@}
\setlength\dbltextfloatsep{20\p@ \@plus 2\p@ \@minus 4\p@}
\setlength\@fptop{0\p@ \@plus 1fil}
\setlength\@fpsep{8\p@ \@plus 2fil}
\setlength\@fpbot{0\p@ \@plus 1fil}
\setlength\@dblfptop{0\p@ \@plus 1fil}
\setlength\@dblfpsep{8\p@ \@plus 2fil}
\setlength\@dblfpbot{0\p@ \@plus 1fil}
\def\ps@plainfoot{%
  \let\@mkboth\@gobbletwo
  \let\@oddhead\@empty
  \def\@oddfoot{\normalfont\hfil\thepage\hfil}%
  \let\@evenhead\@empty
  \let\@evenfoot\@oddfoot}
\def\ps@plainhead{%
  \let\@mkboth\@gobbletwo
  \let\@oddfoot\@empty
  \let\@evenfoot\@empty
  \def\@evenhead{%
    \if@mparswitch \hss \fi
    \hbox to \fullwidth{\textbf{\thepage}\hfil}%
    \if@mparswitch\else \hss \fi}%
  \def\@oddhead{%
    \hbox to \fullwidth{\hfil\textbf{\thepage}}\hss}}
\let\ps@plain\ps@plainfoot
\if@twoside
  \def\ps@headings{%
    \let\@oddfoot\@empty
    \let\@evenfoot\@empty
    \def\@evenhead{\if@mparswitch \hss \fi
      \underline{\hbox to \fullwidth{\textbf{\thepage}\hfil\leftmark}}%
      \if@mparswitch\else \hss \fi}%
    \def\@oddhead{%
      \underline{%
        \hbox to \fullwidth{{\rightmark}\hfil\textbf{\thepage}}}\hss}%
    \let\@mkboth\markboth
    \def\sectionmark##1{\markboth{%
       \ifnum \c@secnumdepth >\z@ \thesection \hskip1\zw\fi
       ##1}{}}%
    \def\subsectionmark##1{\markright{%
       \ifnum \c@secnumdepth >\@ne \thesubsection \hskip1\zw\fi
       ##1}}%
  }
\else % if not twoside
  \def\ps@headings{%
    \let\@oddfoot\@empty
    \def\@oddhead{%
      \underline{%
        \hbox to \fullwidth{{\rightmark}\hfil\textbf{\thepage}}}\hss}%
    \let\@mkboth\markboth
    \def\sectionmark##1{\markright{%
        \ifnum \c@secnumdepth >\z@ \thesection \hskip1\zw\fi
        ##1}}}
\fi
\def\ps@myheadings{%
  \let\@oddfoot\@empty\let\@evenfoot\@empty
  \def\@evenhead{%
    \if@mparswitch \hss \fi%
    \hbox to \fullwidth{\thepage\hfil\leftmark}%
    \if@mparswitch\else \hss \fi}%
  \def\@oddhead{%
    \hbox to \fullwidth{\rightmark\hfil\thepage}\hss}%
  \let\@mkboth\@gobbletwo
  \let\sectionmark\@gobble
  \let\subsectionmark\@gobble
}
\def\plainifnotempty{%
  \ifx \@oddhead \@empty
    \ifx \@oddfoot \@empty
    \else
      \thispagestyle{plainfoot}%
    \fi
  \else
    \thispagestyle{plainhead}%
  \fi}
\if@titlepage
  \newcommand{\maketitle}{%
    \begin{titlepage}%
      \let\footnotesize\small
      \let\footnoterule\relax
      \let\footnote\thanks
      \null\vfil
      \if@slide
        {\footnotesize \@date}%
        \begin{center}
          \mbox{} \\[1\zw]
          \large
          {\maybeblue\hrule height0pt depth2pt\relax}\par
          \smallskip
          \@title
          \smallskip
          {\maybeblue\hrule height0pt depth2pt\relax}\par
          \vfill
          {\small \@author}%
        \end{center}
      \else
      \vskip 60\p@
      \begin{center}%
        {\LARGE \@title \par}%
        \vskip 3em%
        {\large
          \lineskip .75em
          \begin{tabular}[t]{c}%
            \@author
          \end{tabular}\par}%
        \vskip 1.5em
        {\large \@date \par}%
      \end{center}%
      \fi
      \par
      \@thanks\vfil\null
    \end{titlepage}%
    \setcounter{footnote}{0}%
    \global\let\thanks\relax
    \global\let\maketitle\relax
    \global\let\@thanks\@empty
    \global\let\@author\@empty
    \global\let\@date\@empty
    \global\let\@title\@empty
    \global\let\title\relax
    \global\let\author\relax
    \global\let\date\relax
    \global\let\and\relax
  }%
\else
  \newcommand{\maketitle}{\par
    \begingroup
      \renewcommand\thefootnote{\@fnsymbol\c@footnote}%
      \def\@makefnmark{\rlap{\@textsuperscript{\normalfont\@thefnmark}}}%
      \long\def\@makefntext##1{\advance\leftskip 3\zw
        \parindent 1\zw\noindent
        \llap{\@textsuperscript{\normalfont\@thefnmark}\hskip0.3\zw}##1}%
      \if@twocolumn
        \ifnum \col@number=\@ne
          \@maketitle
        \else
          \twocolumn[\@maketitle]%
        \fi
      \else
        \newpage
        \global\@topnum\z@  % Prevents figures from going at top of page.
        \@maketitle
      \fi
      \plainifnotempty
      \@thanks
    \endgroup
    \setcounter{footnote}{0}%
    \global\let\thanks\relax
    \global\let\maketitle\relax
    \global\let\@thanks\@empty
    \global\let\@author\@empty
    \global\let\@date\@empty
    \global\let\@title\@empty
    \global\let\title\relax
    \global\let\author\relax
    \global\let\date\relax
    \global\let\and\relax
  }
  \def\@maketitle{%
    \newpage\null
    \vskip 2em
    \begin{center}%
      \let\footnote\thanks
      {\LARGE \@title \par}%
      \vskip 1.5em
      {\large
        \lineskip .5em
        \begin{tabular}[t]{c}%
          \@author
        \end{tabular}\par}%
      \vskip 1em
      {\large \@date}%
    \end{center}%
    \par\vskip 1.5em
    \ifvoid\@abstractbox\else\centerline{\box\@abstractbox}\vskip1.5em\fi
  }
\fi
\def\@startsection#1#2#3#4#5#6{%
  \if@noskipsec \leavevmode \fi
  \par
  \@tempskipa #4\relax
  \if@english \@afterindentfalse \else \@afterindenttrue \fi
  \ifdim \@tempskipa <\z@
    \@tempskipa -\@tempskipa \@afterindentfalse
  \fi
  \if@nobreak
    \everypar{}%
  \else
    \addpenalty\@secpenalty
    \ifdim \@tempskipa >\z@
      \if@slide\else
        \null
        \vspace*{-\baselineskip}%
      \fi
      \vskip\@tempskipa
    \fi
  \fi
  \noindent
  \@ifstar
    {\@ssect{#3}{#4}{#5}{#6}}%
    {\@dblarg{\@sect{#1}{#2}{#3}{#4}{#5}{#6}}}}
\def\@sect#1#2#3#4#5#6[#7]#8{%
  \ifnum #2>\c@secnumdepth
    \let\@svsec\@empty
  \else
    \refstepcounter{#1}%
    \protected@edef\@svsec{\@seccntformat{#1}\relax}%
  \fi
  \@tempskipa #5\relax
  \ifdim \@tempskipa<\z@
    \def\@svsechd{%
      #6{\hskip #3\relax
      \@svsec #8}%
      \csname #1mark\endcsname{#7}%
      \addcontentsline{toc}{#1}{%
        \ifnum #2>\c@secnumdepth \else
          \protect\numberline{\csname the#1\endcsname}%
        \fi
        #7}}% 目次にフルネームを載せるなら #8
  \else
    \begingroup
      \interlinepenalty \@M % 下から移動
      #6{%
        \@hangfrom{\hskip #3\relax\@svsec}%
        #8\@@par}%
    \endgroup
    \csname #1mark\endcsname{#7}%
    \addcontentsline{toc}{#1}{%
      \ifnum #2>\c@secnumdepth \else
        \protect\numberline{\csname the#1\endcsname}%
      \fi
      #7}% 目次にフルネームを載せるならここは #8
  \fi
  \@xsect{#5}}
\def\@xsect#1{%
  \@tempskipa #1\relax
  \ifdim \@tempskipa<\z@
    \@nobreakfalse
    \global\@noskipsectrue
    \everypar{%
      \if@noskipsec
        \global\@noskipsecfalse
       {\setbox\z@\lastbox}%
        \clubpenalty\@M
        \begingroup \@svsechd \endgroup
        \unskip
        \@tempskipa #1\relax
        \hskip -\@tempskipa\@inhibitglue
      \else
        \clubpenalty \@clubpenalty
        \everypar{}%
      \fi}%
  \else
    \par \nobreak
    \vskip \@tempskipa
    \@afterheading
  \fi
  \if@slide
    {\vskip-6pt\maybeblue\hrule height0pt depth1pt\vskip7pt\relax}%
  \fi
  \par  % 2000-12-18
  \ignorespaces}
\def\@ssect#1#2#3#4#5{%
  \@tempskipa #3\relax
  \ifdim \@tempskipa<\z@
    \def\@svsechd{#4{\hskip #1\relax #5}}%
  \else
    \begingroup
      #4{%
        \@hangfrom{\hskip #1}%
          \interlinepenalty \@M #5\@@par}%
    \endgroup
  \fi
  \@xsect{#3}}
\newcommand*\chaptermark[1]{}
\setcounter{secnumdepth}{3}
\newcounter{part}
\newcounter{section}
\newcounter{subsection}[section]
\newcounter{subsubsection}[subsection]
\newcounter{paragraph}[subsubsection]
\newcounter{subparagraph}[paragraph]
\renewcommand{\thepart}{\@Roman\c@part}
% \renewcommand{\thesection}{\@arabic\c@section}
\renewcommand{\thesection}{\presectionname\@arabic\c@section\postsectionname}
\renewcommand{\thesubsection}{\@arabic\c@section.\@arabic\c@subsection}
\renewcommand{\thesubsubsection}{%
   \thesubsection.\@arabic\c@subsubsection}
\renewcommand{\theparagraph}{%
   \thesubsubsection.\@arabic\c@paragraph}
\renewcommand{\thesubparagraph}{%
   \theparagraph.\@arabic\c@subparagraph}
\newcommand\part{%
  \if@noskipsec \leavevmode \fi
  \par
  \addvspace{4ex}%
  \if@english \@afterindentfalse \else \@afterindenttrue \fi
  \secdef\@part\@spart}
\def\@part[#1]#2{%
  \ifnum \c@secnumdepth >\m@ne
    \refstepcounter{part}%
    \addcontentsline{toc}{part}{%
      \prepartname\thepart\postpartname\hspace{1\zw}#1}%
  \else
    \addcontentsline{toc}{part}{#1}%
  \fi
  \markboth{}{}%
  {\parindent\z@
    \raggedright
    \interlinepenalty \@M
    \normalfont
    \ifnum \c@secnumdepth >\m@ne
      \Large\headfont\prepartname\thepart\postpartname
      \par\nobreak
    \fi
    \huge \headfont #2%
    \markboth{}{}\par}%
  \nobreak
  \vskip 3ex
  \@afterheading}
\def\@spart#1{{%
    \parindent \z@ \raggedright
    \interlinepenalty \@M
    \normalfont
    \huge \headfont #1\par}%
  \nobreak
  \vskip 3ex
  \@afterheading}
\if@twocolumn
  \newcommand{\section}{%
    \@startsection{section}{1}{\z@}%
    {0.6\Cvs}{0.4\Cvs}%
    {\normalfont\large\headfont\raggedright}}
\else
  \newcommand{\section}{%
    \if@slide\clearpage\fi
    \@startsection{section}{1}{\z@}%
    {\Cvs \@plus.5\Cdp \@minus.2\Cdp}% 前アキ
    {.5\Cvs \@plus.3\Cdp}% 後アキ
    {\normalfont\Large\headfont\raggedright}}
\fi
\if@twocolumn
  \newcommand{\subsection}{\@startsection{subsection}{2}{\z@}%
    {\z@}{\z@}%
    {\normalfont\normalsize\headfont}}
\else
  \newcommand{\subsection}{\@startsection{subsection}{2}{\z@}%
    {\Cvs \@plus.5\Cdp \@minus.2\Cdp}% 前アキ
    {.5\Cvs \@plus.3\Cdp}% 後アキ
    {\normalfont\large\headfont}}
\fi
\if@twocolumn
  \newcommand{\subsubsection}{\@startsection{subsubsection}{3}{\z@}%
    {\z@}{\z@}%
    {\normalfont\normalsize\headfont}}
\else
  \newcommand{\subsubsection}{\@startsection{subsubsection}{3}{\z@}%
    {\Cvs \@plus.5\Cdp \@minus.2\Cdp}%
    {\z@}%
    {\normalfont\normalsize\headfont}}
\fi
\if@twocolumn
  \newcommand{\paragraph}{\@startsection{paragraph}{4}{\z@}%
    {\z@}{-1\zw}% 改行せず 1\zw のアキ
    {\normalfont\normalsize\headfont ■}}
\else
  \newcommand{\paragraph}{\@startsection{paragraph}{4}{\z@}%
    {0.5\Cvs \@plus.5\Cdp \@minus.2\Cdp}%
    {-1\zw}% 改行せず 1\zw のアキ
    {\normalfont\normalsize\headfont ■}}
\fi
\newcommand{\subparagraph}{\@startsection{subparagraph}{5}{\z@}%
   {\z@}{-1\zw}%
   {\normalfont\normalsize\headfont}}
\if@slide
  \setlength\leftmargini{1\zw}
\else
  \if@twocolumn
    \setlength\leftmargini{2\zw}
  \else
    \setlength\leftmargini{3\zw}
  \fi
\fi
\if@slide
  \setlength\leftmarginii {1\zw}
  \setlength\leftmarginiii{1\zw}
  \setlength\leftmarginiv {1\zw}
  \setlength\leftmarginv  {1\zw}
  \setlength\leftmarginvi {1\zw}
\else
  \setlength\leftmarginii {2\zw}
  \setlength\leftmarginiii{2\zw}
  \setlength\leftmarginiv {2\zw}
  \setlength\leftmarginv  {1\zw}
  \setlength\leftmarginvi {1\zw}
\fi
\setlength  \labelsep  {0.5\zw} % .5em
\setlength  \labelwidth{\leftmargini}
\addtolength\labelwidth{-\labelsep}
\setlength\partopsep{\z@} % {2\p@ \@plus 1\p@ \@minus 1\p@}
\@beginparpenalty -\@lowpenalty
\@endparpenalty   -\@lowpenalty
\@itempenalty     -\@lowpenalty
\def\@listi{\leftmargin\leftmargini
  \parsep \z@
  \topsep 0.5\baselineskip
  \itemsep \z@ \relax}
\let\@listI\@listi
\@listi
\def\@listii{\leftmargin\leftmarginii
  \labelwidth\leftmarginii \advance\labelwidth-\labelsep
  \topsep \z@
  \parsep \z@
  \itemsep\parsep}
\def\@listiii{\leftmargin\leftmarginiii
  \labelwidth\leftmarginiii \advance\labelwidth-\labelsep
  \topsep \z@
  \parsep \z@
  \itemsep\parsep}
\def\@listiv {\leftmargin\leftmarginiv
              \labelwidth\leftmarginiv
              \advance\labelwidth-\labelsep}
\def\@listv  {\leftmargin\leftmarginv
              \labelwidth\leftmarginv
              \advance\labelwidth-\labelsep}
\def\@listvi {\leftmargin\leftmarginvi
              \labelwidth\leftmarginvi
              \advance\labelwidth-\labelsep}
\renewcommand{\theenumi}{\@arabic\c@enumi}
\renewcommand{\theenumii}{\@alph\c@enumii}
\renewcommand{\theenumiii}{\@roman\c@enumiii}
\renewcommand{\theenumiv}{\@Alph\c@enumiv}
\newcommand{\labelenumi}{\theenumi.}
\newcommand{\labelenumii}{\inhibitglue（\theenumii）\inhibitglue}
\newcommand{\labelenumiii}{\theenumiii.}
\newcommand{\labelenumiv}{\theenumiv.}
\renewcommand{\p@enumii}{\theenumi}
\renewcommand{\p@enumiii}{\theenumi\inhibitglue（\theenumii）}
\renewcommand{\p@enumiv}{\p@enumiii\theenumiii}
\newcommand\labelitemi{\textbullet}
\newcommand\labelitemii{\normalfont\bfseries \textendash}
\newcommand\labelitemiii{\textasteriskcentered}
\newcommand\labelitemiv{\textperiodcentered}
\newenvironment{description}{%
  \list{}{%
    \labelwidth=\leftmargin
    \labelsep=1\zw
    \advance \labelwidth by -\labelsep
    \let \makelabel=\descriptionlabel}}{\endlist}
\newcommand*\descriptionlabel[1]{\normalfont\headfont #1\hfil}
\newbox\@abstractbox
\if@titlepage
  \newenvironment{abstract}{%
    \titlepage
    \null\vfil
    \@beginparpenalty\@lowpenalty
    \begin{center}%
      \headfont \abstractname
      \@endparpenalty\@M
    \end{center}}%
  {\par\vfil\null\endtitlepage}
\else
  \newenvironment{abstract}{%
    \if@twocolumn
      \ifx\maketitle\relax
        \section*{\abstractname}%
      \else
        \global\setbox\@abstractbox\hbox\bgroup
        \begin{minipage}[b]{\textwidth}
          \small\parindent1\zw
          \begin{center}%
            {\headfont \abstractname\vspace{-.5em}\vspace{\z@}}%
          \end{center}%
          \list{}{%
            \listparindent\parindent
            \itemindent \listparindent
            \rightmargin \leftmargin}%
          \item\relax
      \fi
    \else
      \small
      \begin{center}%
        {\headfont \abstractname\vspace{-.5em}\vspace{\z@}}%
      \end{center}%
      \list{}{%
        \listparindent\parindent
        \itemindent \listparindent
        \rightmargin \leftmargin}%
      \item\relax
    \fi}{\if@twocolumn
      \ifx\maketitle\relax
      \else
        \endlist\end{minipage}\egroup
      \fi
    \else
      \endlist
    \fi}
\fi
\newenvironment{verse}{%
  \let \\=\@centercr
  \list{}{%
    \itemsep \z@
    \itemindent -2\zw % 元: -1.5em
    \listparindent\itemindent
    \rightmargin \z@
    \advance\leftmargin 2\zw}% 元: 1.5em
  \item\relax}{\endlist}
\newenvironment{quotation}{%
  \list{}{%
    \listparindent\parindent
    \itemindent\listparindent
    \rightmargin \z@}%
  \item\relax}{\endlist}
\newenvironment{quote}%
  {\list{}{\rightmargin\z@}\item\relax}{\endlist}
\def\@begintheorem#1#2{\trivlist\labelsep=1\zw
   \item[\hskip \labelsep{\headfont #1\ #2}]}
\def\@opargbegintheorem#1#2#3{\trivlist\labelsep=1\zw
      \item[\hskip \labelsep{\headfont #1\ #2（#3）}]}
\newenvironment{titlepage}{%
    \if@twocolumn
      \@restonecoltrue\onecolumn
    \else
      \@restonecolfalse\newpage
    \fi
    \thispagestyle{empty}%
    \setcounter{page}\@ne
  }%
  {\if@restonecol\twocolumn \else \newpage \fi
    \if@twoside\else
      \setcounter{page}\@ne
    \fi}
\newcommand{\appendix}{\par
  \setcounter{section}{0}%
  \setcounter{subsection}{0}%
  \gdef\presectionname{\appendixname}%
  \gdef\postsectionname{}%
  \gdef\thesection{\presectionname\@Alph\c@section\postsectionname}%
  \gdef\thesubsection{\@Alph\c@section.\@arabic\c@subsection}}
\setlength\arraycolsep{5\p@}
\setlength\tabcolsep{6\p@}
\setlength\arrayrulewidth{.4\p@}
\setlength\doublerulesep{2\p@}
\setlength\tabbingsep{\labelsep}
\skip\@mpfootins = \skip\footins
\setlength\fboxsep{3\p@}
\setlength\fboxrule{.4\p@}
\renewcommand \theequation {\@arabic\c@equation}
\newcounter{figure}
\renewcommand \thefigure {\@arabic\c@figure}
\def\fps@figure{tbp}
\def\ftype@figure{1}
\def\ext@figure{lof}
\def\fnum@figure{\figurename\nobreak\thefigure}
\newenvironment{figure}%
               {\@float{figure}}%
               {\end@float}
\newenvironment{figure*}%
               {\@dblfloat{figure}}%
               {\end@dblfloat}
\newcounter{table}
\renewcommand\thetable{\@arabic\c@table}
\def\fps@table{tbp}
\def\ftype@table{2}
\def\ext@table{lot}
\def\fnum@table{\tablename\nobreak\thetable}
\newenvironment{table}%
               {\@float{table}}%
               {\end@float}
\newenvironment{table*}%
               {\@dblfloat{table}}%
               {\end@dblfloat}
\newlength\abovecaptionskip
\newlength\belowcaptionskip
\setlength\abovecaptionskip{5\p@} % 元: 10\p@
\setlength\belowcaptionskip{5\p@} % 元: 0\p@
\long\def\@makecaption#1#2{{\small
  \advance\leftskip .0628\linewidth
  \advance\rightskip .0628\linewidth
  \vskip\abovecaptionskip
  \sbox\@tempboxa{#1\hskip1\zw\relax #2}%
  \ifdim \wd\@tempboxa <\hsize \centering \fi
  #1\hskip1\zw\relax #2\par
  \vskip\belowcaptionskip}}
\DeclareOldFontCommand{\mc}{\normalfont\mcfamily}{\mathmc}
\DeclareOldFontCommand{\gt}{\normalfont\gtfamily}{\mathgt}
\DeclareOldFontCommand{\rm}{\normalfont\rmfamily}{\mathrm}
\DeclareOldFontCommand{\sf}{\normalfont\sffamily}{\mathsf}
\DeclareOldFontCommand{\tt}{\normalfont\ttfamily}{\mathtt}
\DeclareOldFontCommand{\bf}{\normalfont\bfseries}{\mathbf}
\DeclareOldFontCommand{\it}{\normalfont\itshape}{\mathit}
\DeclareOldFontCommand{\sl}{\normalfont\slshape}{\@nomath\sl}
\DeclareOldFontCommand{\sc}{\normalfont\scshape}{\@nomath\sc}
\DeclareRobustCommand*{\cal}{\@fontswitch\relax\mathcal}
\DeclareRobustCommand*{\mit}{\@fontswitch\relax\mathnormal}
\newcommand\@pnumwidth{1.55em}
\newcommand\@tocrmarg{2.55em}
\newcommand\@dotsep{4.5}
\setcounter{tocdepth}{2}
\newcommand{\tableofcontents}{%
  \section*{\contentsname}%
  \@mkboth{\contentsname}{\contentsname}%
  \@starttoc{toc}%
}
\newcommand*{\l@part}[2]{%
  \ifnum \c@tocdepth >-2\relax
    \addpenalty\@secpenalty
    \addvspace{2.25em \@plus\p@}%
    \begingroup
      \parindent \z@
      \rightskip \@tocrmarg
      \parfillskip -\rightskip
      {\leavevmode
        \large \headfont
        \setlength\@lnumwidth{4\zw}%
        #1\hfil \hb@xt@\@pnumwidth{\hss #2}}\par
      \nobreak
    \endgroup
  \fi}
\newcommand*{\l@section}[2]{%
  \ifnum \c@tocdepth >\z@
    \addpenalty{\@secpenalty}%
    \addvspace{1.0em \@plus\p@}%
    \begingroup
      \parindent\z@
      \rightskip\@tocrmarg
      \parfillskip-\rightskip
      \leavevmode\headfont
      \setlength\@lnumwidth{4\zw}% 元1.5em [2003-03-02]
      \advance\leftskip\@lnumwidth \hskip-\leftskip
      #1\nobreak\hfil\nobreak\hbox to\@pnumwidth{\hss#2}\par
    \endgroup
  \fi}
\newcommand*{\l@subsection}   {\@dottedtocline{2}{1\zw}{3\zw}}
\newcommand*{\l@subsubsection}{\@dottedtocline{3}{2\zw}{3\zw}}
\newcommand*{\l@paragraph}    {\@dottedtocline{4}{3\zw}{3\zw}}
\newcommand*{\l@subparagraph} {\@dottedtocline{5}{4\zw}{3\zw}}
\newdimen\@lnumwidth
\def\numberline#1{\hb@xt@\@lnumwidth{#1\hfil}\hspace{0pt}}
\def\@dottedtocline#1#2#3#4#5{\ifnum #1>\c@tocdepth \else
  \vskip \z@ \@plus.2\p@
  {\leftskip #2\relax \rightskip \@tocrmarg \parfillskip -\rightskip
    \parindent #2\relax\@afterindenttrue
   \interlinepenalty\@M
   \leavevmode
   \@lnumwidth #3\relax
   \advance\leftskip \@lnumwidth \null\nobreak\hskip -\leftskip
    {#4}\nobreak
    \leaders\hbox{$\m@th \mkern \@dotsep mu\hbox{.}\mkern \@dotsep
       mu$}\hfill \nobreak\hb@xt@\@pnumwidth{%
         \hfil\normalfont \normalcolor #5}\par}\fi}
\newcommand{\listoffigures}{%
  \section*{\listfigurename}%
  \@mkboth{\listfigurename}{\listfigurename}%
  \@starttoc{lof}%
}
\newcommand*{\l@figure}{\@dottedtocline{1}{1\zw}{3.683\zw}}
\newcommand{\listoftables}{%
  \section*{\listtablename}%
  \@mkboth{\listtablename}{\listtablename}%
  \@starttoc{lot}%
}
\let\l@table\l@figure
\newdimen\bibindent
\setlength\bibindent{2\zw}
\newenvironment{thebibliography}[1]{%
  \global\let\presectionname\relax
  \global\let\postsectionname\relax
  \section*{\refname}\@mkboth{\refname}{\refname}%
   \list{\@biblabel{\@arabic\c@enumiv}}%
        {\settowidth\labelwidth{\@biblabel{#1}}%
         \leftmargin\labelwidth
         \advance\leftmargin\labelsep
         \@openbib@code
         \usecounter{enumiv}%
         \let\p@enumiv\@empty
         \renewcommand\theenumiv{\@arabic\c@enumiv}}%
   \sloppy
   \clubpenalty4000
   \@clubpenalty\clubpenalty
   \widowpenalty4000%
   \sfcode`\.\@m}
  {\def\@noitemerr
    {\@latex@warning{Empty `thebibliography' environment}}%
   \endlist}
\newcommand{\newblock}{\hskip .11em\@plus.33em\@minus.07em}
\let\@openbib@code\@empty
\newenvironment{theindex}{% 索引を3段組で出力する環境
    \if@twocolumn
      \onecolumn\@restonecolfalse
    \else
      \clearpage\@restonecoltrue
    \fi
    \columnseprule.4pt \columnsep 2\zw
    \ifx\multicols\@undefined
      \def\presectionname{}\def\postsectionname{}%
      \twocolumn[\section*{\indexname}]%
    \else
      \ifdim\textwidth<\fullwidth
        \setlength{\evensidemargin}{\oddsidemargin}
        \setlength{\textwidth}{\fullwidth}
        \setlength{\linewidth}{\fullwidth}
        \def\presectionname{}\def\postsectionname{}%
        \begin{multicols}{3}[\section*{\indexname}]%
      \else
        \def\presectionname{}\def\postsectionname{}%
        \begin{multicols}{2}[\section*{\indexname}]%
      \fi
    \fi
    \@mkboth{\indexname}{\indexname}%
    \plainifnotempty % \thispagestyle{plain}
    \parindent\z@
    \parskip\z@ \@plus .3\p@\relax
    \let\item\@idxitem
    \raggedright
    \footnotesize\narrowbaselines
  }{
    \ifx\multicols\@undefined
      \if@restonecol\onecolumn\fi
    \else
      \end{multicols}
    \fi
    \clearpage
  }
\newcommand{\@idxitem}{\par\hangindent 4\zw} % 元 40pt
\newcommand{\subitem}{\@idxitem \hspace*{2\zw}} % 元 20pt
\newcommand{\subsubitem}{\@idxitem \hspace*{3\zw}} % 元 30pt
\newcommand{\indexspace}{\par \vskip 10\p@ \@plus5\p@ \@minus3\p@\relax}
\newcommand\seename{\if@english see\else →\fi}
\newcommand\alsoname{\if@english see also\else →\fi}
\let\footnotes@ve=\footnote
\def\footnote{\inhibitglue\footnotes@ve}
\let\footnotemarks@ve=\footnotemark
\def\footnotemark{\inhibitglue\footnotemarks@ve}
\def\thefootnote{\ifnum\c@footnote>\z@\leavevmode\lower.5ex\hbox{*}\@arabic\c@footnote\fi}
\renewcommand{\footnoterule}{%
  \kern-3\p@
  \hrule width .4\columnwidth
  \kern 2.6\p@}
\long\def\@footnotetext{%
  \insert\footins\bgroup
    \normalfont\footnotesize
    \interlinepenalty\interfootnotelinepenalty
    \splittopskip\footnotesep
    \splitmaxdepth \dp\strutbox \floatingpenalty \@MM
    \hsize\columnwidth \@parboxrestore
    \protected@edef\@currentlabel{%
       \csname p@footnote\endcsname\@thefnmark
    }%
    \color@begingroup
      \@makefntext{%
        \rule\z@\footnotesep\ignorespaces}%
      \futurelet\next\fo@t}
\def\fo@t{\ifcat\bgroup\noexpand\next \let\next\f@@t
                                \else \let\next\f@t\fi \next}
\def\f@@t{\bgroup\aftergroup\@foot\let\next}
\def\f@t#1{#1\@foot}
\def\@foot{\@finalstrut\strutbox\color@endgroup\egroup}
\newcommand\@makefntext[1]{%
  \advance\leftskip 3\zw
  \parindent 1\zw
  \noindent
  \llap{\@makefnmark\hskip0.3\zw}#1}
\protected\def\@inhibitglue{\directlua{luatexja.jfmglue.create_beginpar_node()}}
\def\@item[#1]{%
  \if@noparitem
    \@donoparitem
  \else
    \if@inlabel
      \indent \par
    \fi
    \ifhmode
      \unskip\unskip \par
    \fi
    \if@newlist
      \if@nobreak
        \@nbitem
      \else
        \addpenalty\@beginparpenalty
        \addvspace\@topsep
        \addvspace{-\parskip}%
      \fi
    \else
      \addpenalty\@itempenalty
      \addvspace\itemsep
    \fi
    \global\@inlabeltrue
  \fi
  \everypar{%
    \@minipagefalse
    \global\@newlistfalse
    \if@inlabel
      \global\@inlabelfalse
      {\setbox\z@\lastbox
       \ifvoid\z@
         \kern-\itemindent
       \fi}%
      \box\@labels
      \penalty\z@
    \fi
    \if@nobreak
      \@nobreakfalse
      \clubpenalty \@M
    \else
      \clubpenalty \@clubpenalty
      \everypar{}%
    \fi\@inhibitglue}%
  \if@noitemarg
    \@noitemargfalse
    \if@nmbrlist
      \refstepcounter\@listctr
    \fi
  \fi
  \sbox\@tempboxa{\makelabel{#1}}%
  \global\setbox\@labels\hbox{%
    \unhbox\@labels
    \hskip \itemindent
    \hskip -\labelwidth
    \hskip -\labelsep
    \ifdim \wd\@tempboxa >\labelwidth
      \box\@tempboxa
    \else
      \hbox to\labelwidth {\unhbox\@tempboxa}%
    \fi
    \hskip \labelsep}%
  \ignorespaces}
\def\@gnewline #1{%
  \ifvmode
    \@nolnerr
  \else
    \unskip \reserved@e {\reserved@f#1}\nobreak \hfil \break \null
    \inhibitglue \ignorespaces
  \fi}
\def\小#1{\hbox{$\m@th$%
  \csname S@\f@size\endcsname
  \fontsize\sf@size\z@
  \math@fontsfalse\selectfont
  #1}}
\def\上小#1{{\sbox\z@ T\vbox to\ht0{\小{#1}\vss}}}
\def\cmrTeX{%
  \ifdim \fontdimen\@ne\font >\z@
    T\kern-.25em\lower.5ex\hbox{E}\kern-.125emX\@
  \else
    T\kern-.1667em\lower.5ex\hbox{E}\kern-.125emX\@
  \fi}
\def\cmrLaTeX{%
  \ifdim \fontdimen\@ne\font >\z@
    L\kern-.32em\上小{A}\kern-.22em\cmrTeX
  \else
    L\kern-.36em\上小{A}\kern-.15em\cmrTeX
  \fi}
\def\sfTeX{T\kern-.1em\lower.4ex\hbox{E}\kern-.07emX\@}
\def\sfLaTeX{L\kern-.25em\上小{A}\kern-.08em\sfTeX}
\def\ptmTeX{%
  \ifdim \fontdimen\@ne\font >\z@
    T\kern-.12em\lower.37ex\hbox{E}\kern-.02emX\@
  \else
    T\kern-.07em\lower.37ex\hbox{E}\kern-.05emX\@
  \fi}
\def\ptmLaTeX{%
  \ifdim \fontdimen\@ne\font >\z@
    L\kern-.2em\上小{A}\kern-.1em\ptmTeX
  \else
    L\kern-.3em\上小{A}\kern-.1em\ptmTeX
  \fi}
\def\pncTeX{%
  \ifdim \fontdimen\@ne\font >\z@
    T\kern-.2em\lower.5ex\hbox{E}\kern-.08emX\@
  \else
    T\kern-.13em\lower.5ex\hbox{E}\kern-.13emX\@
  \fi}
\def\pncLaTeX{%
  \ifdim \fontdimen\@ne\font >\z@
    L\kern-.3em\上小{A}\kern-.1em\pncTeX
  \else
    L\kern-.3em\上小{A}\kern-.1em\pncTeX
  \fi}
\def\pplTeX{%
  \ifdim \fontdimen\@ne\font >\z@
    T\kern-.17em\lower.32ex\hbox{E}\kern-.15emX\@
  \else
    T\kern-.12em\lower.34ex\hbox{E}\kern-.1emX\@
  \fi}
\def\pplLaTeX{%
  \ifdim \fontdimen\@ne\font >\z@
    L\kern-.27em\上小{A}\kern-.12em\pplTeX
  \else
    L\kern-.3em\上小{A}\kern-.15em\pplTeX
  \fi}
\def\ugmTeX{%
  \ifdim \fontdimen\@ne\font >\z@
    T\kern-.1em\lower.32ex\hbox{E}\kern-.06emX\@
  \else
    T\kern-.12em\lower.34ex\hbox{E}\kern-.1emX\@
  \fi}
\def\ugmLaTeX{%
  \ifdim \fontdimen\@ne\font >\z@
    L\kern-.2em\上小{A}\kern-.13em\ugmTeX
  \else
    L\kern-.3em\上小{A}\kern-.13em\ugmTeX
  \fi}
\DeclareRobustCommand{\TeX}{%
  \def\@tempa{cmr}%
  \ifx\f@family\@tempa\cmrTeX
  \else
    \def\@tempa{ptm}%
    \ifx\f@family\@tempa\ptmTeX
    \else
      \def\@tempa{txr}%
      \ifx\f@family\@tempa\ptmTeX
      \else
        \def\@tempa{pnc}%
        \ifx\f@family\@tempa\pncTeX
        \else
          \def\@tempa{ppl}%
          \ifx\f@family\@tempa\pplTeX
          \else
            \def\@tempa{ugm}%
            \ifx\f@family\@tempa\ugmTeX
            \else\sfTeX
            \fi
          \fi
        \fi
      \fi
    \fi
  \fi}

\DeclareRobustCommand{\LaTeX}{%
  \def\@tempa{cmr}%
  \ifx\f@family\@tempa\cmrLaTeX
  \else
    \def\@tempa{ptm}%
    \ifx\f@family\@tempa\ptmLaTeX
    \else
      \def\@tempa{txr}%
      \ifx\f@family\@tempa\ptmLaTeX
      \else
        \def\@tempa{pnc}%
        \ifx\f@family\@tempa\pncLaTeX
        \else
          \def\@tempa{ppl}%
          \ifx\f@family\@tempa\pplLaTeX
          \else
            \def\@tempa{ugm}%
            \ifx\f@family\@tempa\ugmLaTeX
            \else\sfLaTeX
            \fi
          \fi
        \fi
      \fi
    \fi
  \fi}
\DeclareRobustCommand{\LaTeXe}{$\mbox{%
  \if b\expandafter\@car\f@series\@nil\boldmath\fi
  \LaTeX\kern.15em2\raisebox{-.37ex}{$\textstyle\varepsilon$}}$}
\def\pTeX{p\kern-.05em\TeX}
\def\pLaTeX{p\LaTeX}
\def\pLaTeXe{p\LaTeXe}
\def\AmSTeX{\protect\AmS-\protect\TeX{}}
\DeclareRobustCommand{\BibTeX}{B\kern-.05em\小{I\kern-.025em B}%
  \ifx\f@family\cmr\kern-.08em\else\kern-.15em\fi\TeX}
\DeclareRobustCommand{\SliTeX}{%
  S\kern-.06emL\kern-.18em\上小{I}\kern -.03em\TeX}
\newcommand{\prepartname}{\if@english Part~\else 第\fi}
\newcommand{\postpartname}{\if@english\else 部\fi}
\newcommand{\presectionname}{}%  第
\newcommand{\postsectionname}{}% 節
\newcommand{\contentsname}{\if@english Contents\else 目次\fi}
\newcommand{\listfigurename}{\if@english List of Figures\else 図目次\fi}
\newcommand{\listtablename}{\if@english List of Tables\else 表目次\fi}
\newcommand{\refname}{\if@english References\else 参考文献\fi}
\newcommand{\bibname}{\if@english Bibliography\else 参考文献\fi}
\newcommand{\indexname}{\if@english Index\else 索引\fi}
\newcommand{\figurename}{\if@english Fig.~\else 図\fi}
\newcommand{\tablename}{\if@english Table.~\else 表\fi}
\newcommand{\appendixname}{\if@english Appendix~\else 付録\fi}
\newcommand{\abstractname}{\if@english Abstract\else 概要\fi}
\newif\if西暦 \西暦true
\def\西暦{\西暦true}
\def\和暦{\西暦false}
\newcount\heisei \heisei\year \advance\heisei-1988\relax
\def\today{%
  \if@english
    \ifcase\month\or
      January\or February\or March\or April\or May\or June\or
      July\or August\or September\or October\or November\or December\fi
      \space\number\day, \number\year
  \else
    \if西暦
      \number\year 年
      \number\month 月
      \number\day 日
    \else
      平成\number\heisei 年
      \number\month 月
      \number\day 日
    \fi
  \fi}
\hyphenation{ado-be post-script ghost-script phe-nom-e-no-log-i-cal man-u-script}
\if@slide \pagestyle{empty} \else \pagestyle{plain} \fi
\pagenumbering{arabic}
\if@twocolumn
  \twocolumn
  \sloppy
  \flushbottom
\else
  \onecolumn
  \raggedbottom
\fi
\if@slide
  \renewcommand\kanjifamilydefault{\gtdefault}
  \renewcommand\familydefault{\sfdefault}
  \raggedright
  \ltjsetparameter{xkanjiskip={0.1em}}\relax
\fi
\endinput
%%
%% End of file `ltjsarticle.cls'.
