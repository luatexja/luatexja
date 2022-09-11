%%
%% This is file `ltjtbook.cls',
%% generated with the docstrip utility.
%%
%% The original source files were:
%%
%% ltjclasses.dtx  (with options: `book,tate')
%% 
%% IMPORTANT NOTICE:
%% 
%% For the copyright see the source file.
%% 
%% Any modified versions of this file must be renamed
%% with new filenames distinct from ltjtbook.cls.
%% 
%% For distribution of the original source see the terms
%% for copying and modification in the file ltjclasses.dtx.
%% 
%% This generated file may be distributed as long as the
%% original source files, as listed above, are part of the
%% same distribution. (The sources need not necessarily be
%% in the same archive or directory.)
%% File: ltjclasses.dtx
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ltjtbook}
  [2022-09-12 v1.8f-ltj-23
 Standard LuaLaTeX-ja class]
\RequirePackage{luatexja}
\newcounter{@paper}
\newif\if@landscape \@landscapefalse
\newcommand{\@ptsize}{}
\newif\if@restonecol
\newif\if@titlepage
\@titlepagetrue
\newif\if@openright
\newif\if@openleft
\newif\if@mainmatter \@mainmattertrue
\hour\time \divide\hour by 60\relax
\@tempcnta\hour \multiply\@tempcnta 60\relax
\minute\time \advance\minute-\@tempcnta
\newif\if@stysize \@stysizefalse
\newif\if@mathrmmc \@mathrmmcfalse
\DeclareOption{a4paper}{\setcounter{@paper}{1}%
  \setlength\paperheight {297mm}%
  \setlength\paperwidth  {210mm}}
\DeclareOption{a5paper}{\setcounter{@paper}{2}%
  \setlength\paperheight {210mm}
  \setlength\paperwidth  {148mm}}
\DeclareOption{b4paper}{\setcounter{@paper}{3}%
  \setlength\paperheight {364mm}
  \setlength\paperwidth  {257mm}}
\DeclareOption{b5paper}{\setcounter{@paper}{4}%
  \setlength\paperheight {257mm}
  \setlength\paperwidth  {182mm}}
\DeclareOption{a4j}{\setcounter{@paper}{1}\@stysizetrue
  \setlength\paperheight {297mm}%
  \setlength\paperwidth  {210mm}}
\DeclareOption{a5j}{\setcounter{@paper}{2}\@stysizetrue
  \setlength\paperheight {210mm}
  \setlength\paperwidth  {148mm}}
\DeclareOption{b4j}{\setcounter{@paper}{3}\@stysizetrue
  \setlength\paperheight {364mm}
  \setlength\paperwidth  {257mm}}
\DeclareOption{b5j}{\setcounter{@paper}{4}\@stysizetrue
  \setlength\paperheight {257mm}
  \setlength\paperwidth  {182mm}}
\DeclareOption{a4p}{\setcounter{@paper}{1}\@stysizetrue
  \setlength\paperheight {297mm}%
  \setlength\paperwidth  {210mm}}
\DeclareOption{a5p}{\setcounter{@paper}{2}\@stysizetrue
  \setlength\paperheight {210mm}
  \setlength\paperwidth  {148mm}}
\DeclareOption{b4p}{\setcounter{@paper}{3}\@stysizetrue
  \setlength\paperheight {364mm}
  \setlength\paperwidth  {257mm}}
\DeclareOption{b5p}{\setcounter{@paper}{4}\@stysizetrue
  \setlength\paperheight {257mm}
  \setlength\paperwidth  {182mm}}
\if@compatibility
  \renewcommand{\@ptsize}{0}
\else
  \DeclareOption{10pt}{\renewcommand{\@ptsize}{0}}
\fi
\DeclareOption{11pt}{\renewcommand{\@ptsize}{1}}
\DeclareOption{12pt}{\renewcommand{\@ptsize}{2}}
\DeclareOption{landscape}{\@landscapetrue
  \setlength\@tempdima{\paperheight}%
  \setlength\paperheight{\paperwidth}%
  \setlength\paperwidth{\@tempdima}}
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
\DeclareOption{tate}{%
  \tate\AtBeginDocument{\message{《縦組モード》}\adjustbaseline}%
}
\DeclareOption{oneside}{\@twosidefalse}
\DeclareOption{twoside}{\@twosidetrue}
\DeclareOption{onecolumn}{\@twocolumnfalse}
\DeclareOption{twocolumn}{\@twocolumntrue}
\DeclareOption{titlepage}{\@titlepagetrue}
\DeclareOption{notitlepage}{\@titlepagefalse}
\if@compatibility
\@openrighttrue
\else
\DeclareOption{openright}{\@openrighttrue\@openleftfalse}
\DeclareOption{openleft}{\@openlefttrue\@openrightfalse}
\DeclareOption{openany}{\@openrightfalse\@openleftfalse}
\fi
\DeclareOption{leqno}{\input{leqno.clo}}
\DeclareOption{fleqn}{\input{fleqn.clo}}
\DeclareOption{openbib}{%
  \AtEndOfPackage{%
   \renewcommand\@openbib@code{%
      \advance\leftmargin\bibindent
      \itemindent -\bibindent
      \listparindent \itemindent
      \parsep \z@
      }%
   \renewcommand\newblock{\par}}}
\if@compatibility
  \@mathrmmctrue
\else
  \DeclareOption{mathrmmc}{\@mathrmmctrue}
\fi
\DeclareOption{draft}{\setlength\overfullrule{5pt}}
\DeclareOption{final}{\setlength\overfullrule{0pt}}
\newif\ifptexmin
\DeclareOption{ptexmin}{\ptexmintrue}%
\DeclareOption{disablejfam}{}
\ExecuteOptions{a4paper,10pt,twoside,onecolumn,final,openright,tate}
\ProcessOptions\relax
\ifptexmin
\directlua{luatexbase.add_to_callback('luatexja.load_jfm',
  function (ji, jn) ji.chars['parbdd'] = 0; return ji end,
  'ltj.jclasses_load_jfm', 1)}
{\jfont\g=\ltj@stdmcfont:jfm=min } % loading jfm-min.lua
\expandafter\let\csname JY3/mc/m/n/10\endcsname\relax
\DeclareFontShape{JY3}{mc}{m}{n}{<-> s * [0.962216] \ltj@stdmcfont:-kern;jfm=min}{}
\DeclareFontShape{JY3}{gt}{m}{n}{<-> s * [0.962216] \ltj@stdgtfont:-kern;jfm=min;jfmvar=goth}{}
\ltjglobalsetparameter{differentjfm=both}
\directlua{luatexbase.remove_from_callback('luatexja.load_jfm', 'ltj.jclasses_load_jfm')}
\fi
\input{ltjtbk1\@ptsize.clo}

\RequirePackage{lltjext}
\def\Cjascale{0.962216}
\if@stysize
  \setlength\columnsep{3\Cwd}
\else
  \setlength\columnsep{10\p@}
\fi
\setlength\columnseprule{0\p@}
\iftombow
  \ifdefined\stockwidth\else\newlength{\stockwidth}\fi
  \ifdefined\stockheight\else\newlength{\stockheight}\fi
  \setlength{\stockwidth}{\paperwidth}
  \setlength{\stockheight}{\paperheight}
  \advance \stockwidth 2in
  \advance \stockheight 2in
  \ifdefined\pdfpagewidth
    \setlength{\pdfpagewidth}{\stockwidth}
    \setlength{\pdfpageheight}{\stockheight}
  \else
    \setlength{\pagewidth}{\stockwidth}
    \setlength{\pageheight}{\stockheight}
  \fi
\else
  \ifdefined\pdfpagewidth
    \setlength{\pdfpagewidth}{\paperwidth}
    \setlength{\pdfpageheight}{\paperheight}
  \else
    \setlength{\pagewidth}{\paperwidth}
    \setlength{\pageheight}{\paperheight}
  \fi
\fi
\setlength\lineskip{1\p@}
\setlength\normallineskip{1\p@}
\renewcommand{\baselinestretch}{}
\setlength\parskip{0\p@ \@plus \p@}
\setlength\parindent{1\Cwd}
\@lowpenalty   51
\@medpenalty  151
\@highpenalty 301
\setcounter{topnumber}{2}
\setcounter{bottomnumber}{1}
\setcounter{totalnumber}{3}
\setcounter{dbltopnumber}{2}
\renewcommand{\topfraction}{.7}
\renewcommand{\bottomfraction}{.3}
\renewcommand{\textfraction}{.2}
\renewcommand{\floatpagefraction}{.5}
\renewcommand{\dbltopfraction}{.7}
\renewcommand{\dblfloatpagefraction}{.5}
\def\pltx@cleartorightpage{\clearpage\if@twoside
  \unless\ifodd\numexpr\c@page+\ltjgetparameter{direction}\relax
    \hbox{}\thispagestyle{empty}\newpage
    \if@twocolumn\hbox{}\newpage\fi
  \fi\fi}
\def\pltx@cleartoleftpage{\clearpage\if@twoside
  \ifodd\numexpr\c@page+\ltjgetparameter{direction}\relax
    \hbox{}\thispagestyle{empty}\newpage
    \if@twocolumn\hbox{}\newpage\fi
  \fi\fi}
\def\pltx@cleartooddpage{\clearpage\if@twoside
  \ifodd\c@page\else
    \hbox{}\thispagestyle{empty}\newpage
    \if@twocolumn\hbox{}\newpage\fi
  \fi\fi}
\def\pltx@cleartoevenpage{\clearpage\if@twoside
  \ifodd\c@page
    \hbox{}\thispagestyle{empty}\newpage
    \if@twocolumn\hbox{}\newpage\fi
  \fi\fi}
\if@openleft
  \let\cleardoublepage\pltx@cleartoleftpage
\else\if@openright
  \let\cleardoublepage\pltx@cleartorightpage
\fi\fi
\def\ps@plain{\let\@mkboth\@gobbletwo
   \let\ps@jpl@in\ps@plain
   \let\@oddhead\@empty
   \def\@oddfoot{\reset@font\hfil\thepage\hfil}%
   \let\@evenhead\@empty
   \let\@evenfoot\@oddfoot}
\let\ps@jpl@in\ps@plain
\def\ps@headnombre{\let\@mkboth\@gobbletwo
    \let\ps@jpl@in\ps@headnombre
  \def\@evenhead{\hfil\thepage}%
  \def\@oddhead{\thepage\hfil}%
  \let\@oddfoot\@empty\let\@evenfoot\@empty}
\def\ps@footnombre{\let\@mkboth\@gobbletwo
    \let\ps@jpl@in\ps@footnombre
  \def\@evenfoot{\hfil\thepage}%
  \def\@oddfoot{\thepage\hfil}%
  \let\@oddhead\@empty\let\@evenhead\@empty}
\if@twoside
  \def\ps@headings{\let\ps@jpl@in\ps@headnombre
    \let\@oddfoot\@empty\let\@evenfoot\@empty
    \def\@evenhead{{\leftmark}\hfil\thepage}%
    \def\@oddhead{\thepage\hfil\rightmark}%
    \let\@mkboth\markboth
  \def\chaptermark##1{\markboth{%
     \ifnum \c@secnumdepth >\m@ne
       \if@mainmatter
         \@chapapp\thechapter\@chappos\hskip1\zw
       \fi
     \fi
     ##1}{}}%
  \def\sectionmark##1{\markright{%
     \ifnum \c@secnumdepth >\z@ \thesection.\hskip1\zw\fi
     ##1}}%
  }
\else % if not twoside
  \def\ps@headings{\let\ps@jpl@in\ps@headnombre
    \let\@oddfoot\@empty
    \def\@oddhead{\thepage\hfil\rightmark}%
    \let\@mkboth\markboth
\def\chaptermark##1{\markright{%
   \ifnum \c@secnumdepth >\m@ne
     \if@mainmatter
       \@chapapp\thechapter\@chappos\hskip1\zw
     \fi
   \fi
   ##1}}%
  }
\fi
\if@twoside
  \def\ps@bothstyle{\let\ps@jpl@in\ps@footnombre
    \def\@evenhead{\hfil\leftmark}% right page
    \def\@evenfoot{\hfil\thepage}% right page
    \def\@oddhead{\rightmark\hfil}% left page
    \def\@oddfoot{\thepage\hfil}% left page
  \let\@mkboth\markboth
\def\chaptermark##1{\markboth{%
     \ifnum \c@secnumdepth >\m@ne
       \if@mainmatter
         \@chapapp\thechapter\@chappos\hskip1\zw
       \fi
     \fi
     ##1}{}}%
  \def\sectionmark##1{\markright{%
     \ifnum \c@secnumdepth >\z@ \thesection.\hskip1\zw\fi
     ##1}}%
  }
\else % if one column
  \def\ps@bothstyle{\let\ps@jpl@in\ps@footnombre
    \def\@oddhead{\rightmark\hfil}%
    \def\@oddfoot{\thepage\hfil}%
    \let\@mkboth\markboth
  \def\chaptermark##1{\markright{%
     \ifnum \c@secnumdepth >\m@ne
       \if@mainmatter
         \@chapapp\thechapter\@chappos\hskip1\zw
       \fi
     \fi
     ##1}}%
  }
\fi
\def\ps@myheadings{\let\ps@jpl@in\ps@plain%
  \let\@oddfoot\@empty\let\@evenfoot\@empty
  \def\@evenhead{{\leftmark}\hfil\thepage}%
  \def\@oddhead{\thepage\hfil\rightmark}%
  \let\@mkboth\@gobbletwo
  \let\chaptermark\@gobble
  \let\sectionmark\@gobble
}
\if@compatibility
\newenvironment{titlepage}
    {%
     \cleardoublepage
     \if@twocolumn\@restonecoltrue\onecolumn
     \else\@restonecolfalse\newpage\fi
     \thispagestyle{empty}%
     \setcounter{page}\z@
    }%
    {\if@restonecol\twocolumn\else\newpage\fi
    }
\else
\newenvironment{titlepage}
    {%
      \pltx@cleartooddpage %% 2017/02/15
      \if@twocolumn
        \@restonecoltrue\onecolumn
      \else
        \@restonecolfalse\newpage
      \fi
      \thispagestyle{empty}%
      \ifodd\c@page\setcounter{page}\@ne\else\setcounter{page}\z@\fi %% 2017/02/15
    }%
    {\if@restonecol\twocolumn \else \newpage \fi
     \if@twoside\else
        \setcounter{page}\@ne
     \fi
    }
\fi
\def\p@thanks#1{\footnotemark
  \protected@xdef\@thanks{\@thanks
    \protect{\noindent\hbox{\yoko$\m@th^\thefootnote$}#1\protect\par}}}
\if@titlepage
  \newcommand{\maketitle}{\begin{titlepage}%
  \let\footnotesize\small
  \let\footnoterule\relax
  \let\thanks\p@thanks
  \let\footnote\thanks
  \vbox to\textheight\bgroup\tate\hsize\textwidth
  \null\vfil
  \vskip 60\p@
  \begin{center}%
    {\LARGE \@title \par}%
    \vskip 3em%
    {\Large
     \lineskip .75em%
      \begin{tabular}[t]{c}%
        \@author
      \end{tabular}\par}%
      \vskip 1.5em%
    {\large \@date \par}%       % Set date in \large size.
  \end{center}\par
  \vfil{\centering\@thanks}\vfil\null
  \egroup
  \end{titlepage}%
  \setcounter{footnote}{0}%
  \global\let\thanks\relax
  \global\let\maketitle\relax
  \global\let\p@thanks\relax
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
    \renewcommand{\thefootnote}{\fnsymbol{footnote}}%
    \def\@makefnmark{\hbox{\unless\ifnum\ltjgetparameter{direction}=3 $\m@th^{\@thefnmark}$
      \else\hbox{\yoko$\m@th^{\@thefnmark}$}\fi}}%
    \long\def\@makefntext##1{\parindent 1\zw\noindent
       \hb@xt@ 2\zw{\hss\@makefnmark}##1}%
    \if@twocolumn
      \ifnum \col@number=\@ne \@maketitle
      \else \twocolumn[\@maketitle]%
      \fi
    \else
      \newpage
      \global\@topnum\z@   % Prevents figures from going at top of page.
      \@maketitle
    \fi
     \thispagestyle{jpl@in}\@thanks
  \endgroup
  \setcounter{footnote}{0}%
  \global\let\thanks\relax
  \global\let\maketitle\relax
  \global\let\@maketitle\relax
  \global\let\p@thanks\relax
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
  \vskip 2em%
  \begin{center}%
  \let\footnote\p@thanks
    {\LARGE \@title \par}%
    \vskip 1.5em%
    {\large
      \lineskip .5em%
      \begin{tabular}[t]{c}%
        \@author
      \end{tabular}\par}%
    \vskip 1em%
    {\large \@date}%
  \end{center}%
  \par\vskip 1.5em}
\fi
\newcommand*{\chaptermark}[1]{}
\setcounter{secnumdepth}{2}
\newcounter{part}
\newcounter{chapter}
\newcounter{section}[chapter]
\newcounter{subsection}[section]
\newcounter{subsubsection}[subsection]
\newcounter{paragraph}[subsubsection]
\newcounter{subparagraph}[paragraph]
\renewcommand{\thepart}{\rensuji{\@Roman\c@part}}
\renewcommand{\thechapter}{\rensuji{\@arabic\c@chapter}}
\renewcommand{\thesection}{\thechapter・\rensuji{\@arabic\c@section}}
\renewcommand{\thesubsection}{\thesection・\rensuji{\@arabic\c@subsection}}
\renewcommand{\thesubsubsection}{%
   \thesubsection・\rensuji{\@arabic\c@subsubsection}}
\renewcommand{\theparagraph}{%
   \thesubsubsection・\rensuji{\@arabic\c@paragraph}}
\renewcommand{\thesubparagraph}{%
   \theparagraph・\rensuji{\@arabic\c@subparagraph}}
\newcommand{\@chapapp}{\prechaptername}
\newcommand{\@chappos}{\postchaptername}
\newcommand{\frontmatter}{%
  \pltx@cleartooddpage
  \@mainmatterfalse\pagenumbering{roman}}
\newcommand{\mainmatter}{%
  \pltx@cleartooddpage
  \@mainmattertrue\pagenumbering{arabic}}
\newcommand{\backmatter}{%
  \if@openleft \cleardoublepage \else
  \if@openright \cleardoublepage \else \clearpage \fi \fi
  \@mainmatterfalse}
\newcommand{\part}{%
  \if@openleft \cleardoublepage \else
  \if@openright \cleardoublepage \else \clearpage \fi \fi
  \thispagestyle{empty}%
  \if@twocolumn\onecolumn\@tempswatrue\else\@tempswafalse\fi
  \null\vfil
  \secdef\@part\@spart}
\def\@part[#1]#2{%
  \ifnum \c@secnumdepth >-2\relax
    \refstepcounter{part}%
    \addcontentsline{toc}{part}{%
       \prepartname\thepart\postpartname\hspace{1em}#1}%
  \else
    \addcontentsline{toc}{part}{#1}%
  \fi
  \markboth{}{}%
  {\centering
   \interlinepenalty\@M\normalfont
   \ifnum \c@secnumdepth >-2\relax
     \huge\bfseries\prepartname\thepart\postpartname
     \par\vskip20\p@
   \fi
   \Huge\bfseries#2\par}%
   \@endpart}
\def\@spart#1{{%
  \centering
  \interlinepenalty\@M\normalfont
  \Huge\bfseries#1\par}%
  \@endpart}
\def\@endpart{\vfil\newpage
   \if@twoside
    \if@openleft %% \if@openleft added (2017/02/15)
     \null\thispagestyle{empty}\newpage
    \else\if@openright %% \if@openright added (2016/12/18)
     \null\thispagestyle{empty}\newpage
    \fi\fi %% added (2016/12/18, 2017/02/15)
   \fi
   \if@tempswa\twocolumn\fi}
\newcommand{\chapter}{%
  \if@openleft \cleardoublepage \else
  \if@openright \cleardoublepage \else \clearpage \fi \fi
  \thispagestyle{jpl@in}%
  \global\@topnum\z@
  \@afterindenttrue
  \secdef\@chapter\@schapter}
\def\@chapter[#1]#2{%
  \ifnum \c@secnumdepth >\m@ne
    \if@mainmatter
    \refstepcounter{chapter}%
    \typeout{\@chapapp\space\thechapter\space\@chappos}%
    \addcontentsline{toc}{chapter}%
      {\protect\numberline{\@chapapp\thechapter\@chappos}#1}%
    \else\addcontentsline{toc}{chapter}{#1}\fi
  \else
    \addcontentsline{toc}{chapter}{#1}%
  \fi
  \chaptermark{#1}%
  \addtocontents{lof}{\protect\addvspace{10\p@}}%
  \addtocontents{lot}{\protect\addvspace{10\p@}}%
  \@makechapterhead{#2}\@afterheading}
\def\@makechapterhead#1{\hbox{}%
  \vskip2\Cvs
  {\parindent\z@
   \raggedright
   \normalfont\huge\bfseries
   \leavevmode
   \ifnum \c@secnumdepth >\m@ne
     \setlength\@tempdima{\linewidth}%
    \if@mainmatter
     \setbox\z@\hbox{\@chapapp\thechapter\@chappos\hskip1\zw}%
     \addtolength\@tempdima{-\wd\z@}%
     \unhbox\z@\nobreak
    \fi
     \vtop{\hsize\@tempdima#1}%
   \else
     #1\relax
   \fi}\nobreak\vskip3\Cvs}
\def\@schapter#1{%
  \@makeschapterhead{#1}\@afterheading
}
\def\@makeschapterhead#1{\hbox{}%
  \vskip2\Cvs
  {\parindent\z@
   \raggedright
   \normalfont\huge\bfseries
   \leavevmode
   \setlength\@tempdima{\linewidth}%
   \vtop{\hsize\@tempdima#1}}\vskip3\Cvs}
\newcommand{\section}{\@startsection{section}{1}{\z@}%
   {1.5\Cvs \@plus.5\Cvs \@minus.2\Cvs}%
   {.5\Cvs \@plus.3\Cvs}%
   {\normalfont\Large\bfseries}}
\newcommand{\subsection}{\@startsection{subsection}{2}{\z@}%
   {1.5\Cvs \@plus.5\Cvs \@minus.2\Cvs}%
   {.5\Cvs \@plus.3\Cvs}%
   {\normalfont\large\bfseries}}
\newcommand{\subsubsection}{\@startsection{subsubsection}{3}{\z@}%
   {1.5\Cvs \@plus.5\Cvs \@minus.2\Cvs}%
   {.5\Cvs \@plus.3\Cvs}%
   {\normalfont\normalsize\bfseries}}
\newcommand{\paragraph}{\@startsection{paragraph}{4}{\z@}%
   {3.25ex \@plus 1ex \@minus .2ex}%
   {-1em}%
   {\normalfont\normalsize\bfseries}}
\newcommand{\subparagraph}{\@startsection{subparagraph}{5}{\z@}%
   {3.25ex \@plus 1ex \@minus .2ex}%
   {-1em}%
   {\normalfont\normalsize\bfseries}}
\newcommand{\appendix}{\par
  \setcounter{chapter}{0}%
  \setcounter{section}{0}%
  \renewcommand{\@chapapp}{\appendixname}%
  \renewcommand{\@chappos}\space%
  \renewcommand{\thechapter}{\rensuji{\@Alph\c@chapter}}}
\if@twocolumn
  \setlength\leftmargini {2em}
\else
  \setlength\leftmargini {2.5em}
\fi
\setlength\leftmarginii  {2.2em}
\setlength\leftmarginiii {1.87em}
\setlength\leftmarginiv  {1.7em}
\if@twocolumn
  \setlength\leftmarginv {.5em}
  \setlength\leftmarginvi{.5em}
\else
  \setlength\leftmarginv {1em}
  \setlength\leftmarginvi{1em}
\fi
\setlength  \labelsep  {.5em}
\setlength  \labelwidth{\leftmargini}
\addtolength\labelwidth{-\labelsep}
\@beginparpenalty -\@lowpenalty
\@endparpenalty   -\@lowpenalty
\@itempenalty     -\@lowpenalty
\renewcommand{\theenumi}{\rensuji{\@arabic\c@enumi}}
\renewcommand{\theenumii}{\rensuji{(\@alph\c@enumii)}}
\renewcommand{\theenumiii}{\rensuji{\@roman\c@enumiii}}
\renewcommand{\theenumiv}{\rensuji{\@Alph\c@enumiv}}
\newcommand{\labelenumi}{\theenumi}
\newcommand{\labelenumii}{\theenumii}
\newcommand{\labelenumiii}{\theenumiii}
\newcommand{\labelenumiv}{\theenumiv}
\renewcommand{\p@enumii}{\theenumi}
\renewcommand{\p@enumiii}{\theenumi(\theenumii)}
\renewcommand{\p@enumiv}{\p@enumiii\theenumiii}
\renewenvironment{enumerate}
  {\ifnum \@enumdepth >\thr@@\@toodeep\else
   \advance\@enumdepth\@ne
   \edef\@enumctr{enum\romannumeral\the\@enumdepth}%
   \expandafter \list \csname label\@enumctr\endcsname{%
      \ifnum\ltjgetparameter{direction}=3
         \ifnum \@listdepth=\@ne \topsep.5\normalbaselineskip
           \else\topsep\z@\fi
         \parskip\z@ \itemsep\z@ \parsep\z@
         \labelwidth1\zw \labelsep.3\zw
         \ifnum \@enumdepth=\@ne \leftmargin1\zw\relax
           \else\leftmargin\leftskip\fi
         \advance\leftmargin 1\zw
      \fi
         \usecounter{\@enumctr}%
         \def\makelabel##1{\hss\llap{##1}}}%
   \fi}{\endlist}
\newcommand{\labelitemi}{\labelitemfont \textbullet}
\newcommand{\labelitemii}{%
  \ifnum\ltjgetparameter{direction}=3
     {\labelitemfont \textcircled{~}}
  \else
     {\labelitemfont \bfseries\textendash}
  \fi
}
\newcommand{\labelitemiii}{\labelitemfont \textasteriskcentered}
\newcommand{\labelitemiv}{\labelitemfont \textperiodcentered}
\newcommand\labelitemfont{\normalfont}
\renewenvironment{itemize}
  {\ifnum \@itemdepth >\thr@@\@toodeep\else
   \advance\@itemdepth\@ne
   \edef\@itemitem{labelitem\romannumeral\the\@itemdepth}%
   \expandafter \list \csname \@itemitem\endcsname{%
      \ifnum\ltjgetparameter{direction}=3
         \ifnum \@listdepth=\@ne \topsep.5\normalbaselineskip
           \else\topsep\z@\fi
         \parskip\z@ \itemsep\z@ \parsep\z@
         \labelwidth1\zw \labelsep.3\zw
         \ifnum \@itemdepth =\@ne \leftmargin1\zw\relax
           \else\leftmargin\leftskip\fi
         \advance\leftmargin 1\zw
      \fi
         \def\makelabel##1{\hss\llap{##1}}}%
   \fi}{\endlist}
\newenvironment{description}
  {\list{}{\labelwidth\z@ \itemindent-\leftmargin
   \ifnum\ltjgetparameter{direction}=3
     \leftmargin\leftskip \advance\leftmargin3\Cwd
     \rightmargin\rightskip
     \labelsep=1\zw \itemsep\z@
     \listparindent\z@ \topskip\z@ \parskip\z@ \partopsep\z@
   \fi
           \let\makelabel\descriptionlabel}}{\endlist}
\newcommand{\descriptionlabel}[1]{%
   \hspace\labelsep\normalfont\bfseries #1}
\newenvironment{verse}
  {\let\\\@centercr
   \list{}{\itemsep\z@ \itemindent -1.5em%
           \listparindent\itemindent
           \rightmargin\leftmargin \advance\leftmargin 1.5em}%
           \item\relax}{\endlist}
\newenvironment{quotation}
  {\list{}{\listparindent 1.5em%
           \itemindent\listparindent
           \rightmargin\leftmargin
           \parsep\z@ \@plus\p@}%
           \item\relax}{\endlist}
\newenvironment{quote}
  {\list{}{\rightmargin\leftmargin}%
           \item\relax}{\endlist}
\newcounter{figure}[chapter]
\renewcommand{\thefigure}{%
  \ifnum\c@chapter>\z@\thechapter{}・\fi\rensuji{\@arabic\c@figure}}
\def\fps@figure{tbp}
\def\ftype@figure{1}
\def\ext@figure{lof}
\def\fnum@figure{\figurename\thefigure}
\newenvironment{figure}
               {\@float{figure}}
               {\end@float}
\newenvironment{figure*}
               {\@dblfloat{figure}}
               {\end@dblfloat}
\newcounter{table}[chapter]
\renewcommand{\thetable}{%
  \ifnum\c@chapter>\z@\thechapter{}・\fi\rensuji{\@arabic\c@table}}
\def\fps@table{tbp}
\def\ftype@table{2}
\def\ext@table{lot}
\def\fnum@table{\tablename\thetable}
\newenvironment{table}
               {\@float{table}}
               {\end@float}
\newenvironment{table*}
               {\@dblfloat{table}}
               {\end@dblfloat}
\newlength\abovecaptionskip
\newlength\belowcaptionskip
\setlength\abovecaptionskip{10\p@}
\setlength\belowcaptionskip{0\p@}
\long\def\@makecaption#1#2{%
  \vskip\abovecaptionskip
  \ifnum\ltjgetparameter{direction}=3 \sbox\@tempboxa{#1\hskip1\zw#2}%
    \else\sbox\@tempboxa{#1: #2}%
  \fi
  \ifdim \wd\@tempboxa >\hsize
    \ifnum\ltjgetparameter{direction}=3  #1\hskip1\zw#2\relax\par
      \else #1: #2\relax\par\fi
  \else
    \global \@minipagefalse
    \hb@xt@\hsize{\hfil\box\@tempboxa\hfil}%
  \fi
  \vskip\belowcaptionskip}
\setlength\arraycolsep{5\p@}
\setlength\tabcolsep{6\p@}
\setlength\arrayrulewidth{.4\p@}
\setlength\doublerulesep{2\p@}
\setlength\tabbingsep{\labelsep}
\skip\@mpfootins = \skip\footins
\setlength\fboxsep{3\p@}
\setlength\fboxrule{.4\p@}
\@addtoreset{equation}{chapter}
\renewcommand{\theequation}{%
  \ifnum\c@chapter>\z@\thechapter.\fi \@arabic\c@equation}
\unless\ifltj@disablejfam
\if@compatibility\else
  \DeclareSymbolFont{mincho}{JY3}{mc}{m}{n}
  \DeclareSymbolFontAlphabet{\mathmc}{mincho}
  \SetSymbolFont{mincho}{bold}{JY3}{gt}{m}{n}
  \jfam\symmincho
  \DeclareMathAlphabet{\mathgt}{JY3}{gt}{m}{n}
\fi
\if@mathrmmc
  \AtBeginDocument{%
  \reDeclareMathAlphabet{\mathrm}{\mathrm}{\mathmc}
  \reDeclareMathAlphabet{\mathbf}{\mathbf}{\mathgt}
}%
\fi
\fi
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
\setcounter{tocdepth}{2}
\newcommand{\@pnumwidth}{1.55em}
\newcommand{\@tocrmarg}{2.55em}
\newcommand{\@dotsep}{4.5}
\newdimen\toclineskip
\setlength\toclineskip{2\p@}
\newdimen\@lnumwidth
\def\numberline#1{\hb@xt@\@lnumwidth{#1\hfil}}
\def\@dottedtocline#1#2#3#4#5{%
  \ifnum #1>\c@tocdepth \else
    \vskip\toclineskip \@plus.2\p@
    {\leftskip #2\relax \rightskip \@tocrmarg \parfillskip -\rightskip
     \parindent #2\relax\@afterindenttrue
     \interlinepenalty\@M
     \leavevmode
     \@lnumwidth #3\relax
     \advance\leftskip \@lnumwidth \null\nobreak\hskip -\leftskip
     {#4}\nobreak
     \leaders\hbox{$\m@th \mkern \@dotsep mu.\mkern \@dotsep mu$}%
     \hfill\nobreak
     \hb@xt@\@pnumwidth{\hss\normalfont \normalcolor #5}%
     \par}%
  \fi}
\providecommand*\protected@file@percent{}
\def\addcontentsline#1#2#3{%
  \protected@write\@auxout
    {\let\label\@gobble \let\index\@gobble \let\glossary\@gobble
     \@temptokena{\rensuji{\thepage}}%
    }{\string\@writefile{#1}%
       {\protect\contentsline{#2}{#3}{\the\@temptokena}{}%
\protected@file@percent}}%
}
\newcommand{\tableofcontents}{%
  \if@twocolumn\@restonecoltrue\onecolumn
  \else\@restonecolfalse\fi
  \chapter*{\contentsname
    \@mkboth{\contentsname}{\contentsname}%
  }\@starttoc{toc}%
  \if@restonecol\twocolumn\fi
}
\newcommand*{\l@part}[2]{%
  \ifnum \c@tocdepth >-2\relax
    \addpenalty{-\@highpenalty}%
    \addvspace{2.25em \@plus\p@}%
    \begingroup
    \parindent\z@\rightskip\@pnumwidth
    \parfillskip-\@pnumwidth
    {\leavevmode\large\bfseries
     \setlength\@lnumwidth{4\zw}%
     #1\hfil\nobreak
     \hb@xt@\@pnumwidth{\hss#2}}\par
    \nobreak
    \global\@nobreaktrue
    \everypar{\global\@nobreakfalse\everypar{}}%
     \endgroup
  \fi}
\newcommand*{\l@chapter}[2]{%
  \ifnum \c@tocdepth >\m@ne
    \addpenalty{-\@highpenalty}%
    \addvspace{1.0em \@plus\p@}%
    \begingroup
      \parindent\z@ \rightskip\@pnumwidth \parfillskip-\rightskip
      \leavevmode\bfseries
      \setlength\@lnumwidth{4\zw}%
      \advance\leftskip\@lnumwidth \hskip-\leftskip
      #1\nobreak\hfil\nobreak\hb@xt@\@pnumwidth{\hss#2}\par
      \penalty\@highpenalty
    \endgroup
  \fi}
\newcommand*{\l@section}{\@dottedtocline{1}{1\zw}{4\zw}}
\newcommand*{\l@subsection}   {\@dottedtocline{2}{2\zw}{6\zw}}
\newcommand*{\l@subsubsection}{\@dottedtocline{3}{3\zw}{8\zw}}
\newcommand*{\l@paragraph}    {\@dottedtocline{4}{4\zw}{9\zw}}
\newcommand*{\l@subparagraph} {\@dottedtocline{5}{5\zw}{10\zw}}
\newcommand{\listoffigures}{%
  \if@twocolumn\@restonecoltrue\onecolumn
  \else\@restonecolfalse\fi
  \chapter*{\listfigurename}%
  \@mkboth{\listfigurename}{\listfigurename}%
  \@starttoc{lof}%
  \if@restonecol\twocolumn\fi
}
\newcommand*{\l@figure}{\@dottedtocline{1}{1\zw}{4\zw}}
\newcommand{\listoftables}{%
  \if@twocolumn\@restonecoltrue\onecolumn
  \else\@restonecolfalse\fi
  \chapter*{\listtablename}%
  \@mkboth{\listtablename}{\listtablename}%
  \@starttoc{lot}%
  \if@restonecol\twocolumn\fi
}
\let\l@table\l@figure
\newdimen\bibindent
\setlength\bibindent{1.5em}
\newcommand{\newblock}{\hskip .11em\@plus.33em\@minus.07em}
\newenvironment{thebibliography}[1]
{\chapter*{\bibname}\@mkboth{\bibname}{\bibname}%
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
\let\@openbib@code\@empty
\newenvironment{theindex}
  {\if@twocolumn\@restonecolfalse\else\@restonecoltrue\fi
   \twocolumn[\@makeschapterhead{\indexname}]%
   \@mkboth{\indexname}{\indexname}%
   \thispagestyle{jpl@in}\parindent\z@
   \parskip\z@ \@plus .3\p@\relax
   \columnseprule\z@ \columnsep 35\p@
   \let\item\@idxitem}
  {\if@restonecol\onecolumn\else\clearpage\fi}
\newcommand{\@idxitem}{\par\hangindent 40\p@}
\newcommand{\subitem}{\@idxitem \hspace*{20\p@}}
\newcommand{\subsubitem}{\@idxitem \hspace*{30\p@}}
\newcommand{\indexspace}{\par \vskip 10\p@ \@plus5\p@ \@minus3\p@\relax}
\renewcommand{\footnoterule}{%
  \kern-3\p@
  \hrule\@width.4\columnwidth
  \kern2.6\p@}
\@addtoreset{footnote}{chapter}
\newcommand\@makefntext[1]{\parindent 1\zw
  \noindent\hb@xt@ 2\zw{\hss\@makefnmark}#1}
\newif\if西暦 \西暦true
\def\西暦{\西暦true}
\def\和暦{\西暦false}
\newcount\heisei \heisei\year \advance\heisei-1988\relax
\def\pltx@today@year@#1{%
  \ifnum\numexpr\year-#1=1 元\else
    \ifnum\ltjgetparameter{direction}=3
      \kansuji\numexpr\year-#1\relax
    \else
      \number\numexpr\year-#1\relax\nobreak
    \fi
  \fi 年
}
\def\pltx@today@year{%
  \ifnum\numexpr\year*10000+\month*100+\day<19890108
    昭和\pltx@today@year@{1925}%
  \else\ifnum\numexpr\year*10000+\month*100+\day<20190501
    平成\pltx@today@year@{1988}%
  \else
    令和\pltx@today@year@{2018}%
  \fi\fi}
\def\today{{%
  \if西暦
    \ifnum\ltjgetparameter{direction}=3 \kansuji\year
    \else\number\year\nobreak\fi 年
  \else
    \pltx@today@year
  \fi
  \ifnum\ltjgetparameter{direction}=3
    \kansuji\month 月
    \kansuji\day 日
  \else
    \number\month\nobreak 月
    \number\day\nobreak 日
  \fi}}
\newcommand{\prepartname}{第}
\newcommand{\postpartname}{部}
\newcommand{\prechaptername}{第}
\newcommand{\postchaptername}{章}
\newcommand{\contentsname}{目 次}
\newcommand{\listfigurename}{図 目 次}
\newcommand{\listtablename}{表 目 次}
\newcommand{\bibname}{関連図書}
\newcommand{\indexname}{索 引}
\newcommand{\figurename}{図}
\newcommand{\tablename}{表}
\newcommand{\appendixname}{付 録}
\pagestyle{headings}
\pagenumbering{arabic}
\raggedbottom
\fnfixbottomtrue % 2017-02-19
\IfFileExists{stfloats.sty}{\RequirePackage{stfloats}\fnbelowfloat}{}
\if@twocolumn
  \twocolumn
  \sloppy
\else
  \onecolumn
\fi
\normalmarginpar
\@mparswitchfalse
\ltj@ExecuteBeforePackage*{ftnright}{\let\ltjt@orig@@makefntext=\@makefntext}
\ltj@ExecuteAfterPackage*{ftnright}{\let\@makefntext=\ltjt@orig@@makefntext}
\endinput
%%
%% End of file `ltjtbook.cls'.
