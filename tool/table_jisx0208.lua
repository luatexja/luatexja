%#! euptex
% cat jisx0208table.log | tr -s '\n' > ../src/luatexja/jisx0208.lua
% の後，少々修正
\catcode`\!=1
\catcode`\?=2

\catcode`@11
\def\@firstoftwo#1#2{#1}
\def\@secondoftwo#1#2{#2}
\def\ifnumcomp#1#2#3{%
        \ifnum\numexpr#1\relax#2\numexpr#3\relax
                \expandafter\@firstoftwo
        \else
                \expandafter\@secondoftwo
        \fi
}
\def\truncdiv#1#2{%
        \ifnumcomp{#1}<{(#1)/(#2)*(#2)}{%
                \numexpr(#1)/(#2)-1%
        }{%
                \numexpr(#1)/(#2)%
        }%
}
\def\hex#1{%
        \ifnumcomp{#1}<0{}{\hn@i{#1}{}}%
}
\def\hn@i#1#2{%
        \ifnumcomp{#1}<{16}
        {%
                \hn@digit{#1}#2%
        }{%
                \expandafter\hn@ii\expandafter{%
                        \the\numexpr\truncdiv{#1}{16}%
                }{#1}{#2}%
        }%
}
\def\hn@ii#1#2#3{%
        \expandafter\hn@i\expandafter{%
                \number\numexpr#1\expandafter\expandafter\expandafter
                \expandafter\expandafter\expandafter\expandafter}%
                \expandafter\expandafter\expandafter\expandafter
                \expandafter\expandafter\expandafter{%
                        \hn@digit{(#2)-16*(#1)}#3}%
}
\begingroup
\catcode`012\catcode`112\catcode`212\catcode`312\catcode`412
\catcode`512\catcode`612\catcode`712\catcode`812\catcode`912
\catcode`A12\catcode`B12\catcode`C12\catcode`D12\catcode`E12
\catcode`F12
\gdef\hn@digit#1{%
        \ifcase\numexpr#1\relax 0%
        \or \expandafter 1%
        \or \expandafter 2%
        \or \expandafter 3%
        \or \expandafter 4%
        \or \expandafter 5%
        \or \expandafter 6%
        \or \expandafter 7%
        \or \expandafter 8%
        \or \expandafter 9%
        \or \expandafter A%
        \or \expandafter B%
        \or \expandafter C%
        \or \expandafter D%
        \or \expandafter E%
        \or \expandafter F%
        \fi
}
\endgroup


\catcode`\{=12
\catcode`\}=12
\def\folio!?

\newcount\ku
\newcount\ten
\newcount\tmp
\newcount\tmpa
\newcount\tmpb
\font\tt=cmtt10 at 10pt\tt\baselineskip=12pt\parindent=0pt\parskip=0pt

\catcode`\_=12
\message!^^Jluatexbase.provides_module({?
\message!^^J  name = 'luatexja.jisx0208'})?
\message!^^Jmodule('luatexja.jisx0208', package.seeall)?
\message!^^Jtable_jisx0208_uptex = {?

\ku=1
\loop 
  \tmp=\ku \multiply\tmp"100 \advance\tmp"2020 %"
  ! \ten=1
    \loop
    \advance\tmp1 
    \tmpa=\jis\tmp \tmpb=\tmp\advance\tmpb-"2020%"
    \ifnum\tmpa=0\else
      \ifnum\tmpa>256
        \kansujichar1=\tmpa
        \message!^^J  [0x\hex\tmpb] = 0x\hex\tmpa, --(\kansuji1)?
      \else
        \message!^^J  [0x\hex\tmpb] = 0x\hex\tmpa, ?
      \fi
    \fi
    \advance\ten 1
    \ifnum\ten<95\relax\repeat
  ?
  \advance\ku 1
\ifnum\ku<95\relax\repeat

\message!^^J}?

\end
