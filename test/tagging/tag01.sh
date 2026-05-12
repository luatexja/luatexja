lualatex-dev --jobname=tag01-ljs '\def\LTJ{ltjs}\input tag01' \
&& lualatex-dev --jobname=tag01-ljs '\def\LTJ{ltjs}\input tag01' \
&& lualatex-dev --jobname=tag01-ori '\def\LTJ{}\input tag01' \
&& lualatex-dev --jobname=tag01-ori '\def\LTJ{}\input tag01' \
&& lualatex-dev --jobname=tag01-ltj '\def\LTJ{ltj}\input tag01' \
&& lualatex-dev --jobname=tag01-ltj '\def\LTJ{ltj}\input tag01' \
&& show-pdf-tags tag01-ori.pdf > tag01-ori-tags.txt \
&& show-pdf-tags tag01-ltj.pdf > tag01-ltj-tags.txt \
&& show-pdf-tags tag01-ljs.pdf > tag01-ljs-tags.txt

