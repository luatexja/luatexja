lualatex -jobname=a-5o a \
&& lualatex -jobname=a-5n '\def\LTJ{a}\input a' \
&& lualatex-dev -jobname=a-6o a \
&& lualatex-dev -jobname=a-6n '\def\LTJ{a}\input a' \
&& lualatex a-comp


