#-*- mode: Makefile -*-

PROJECT=luatexja
DIR=..
VER=HEAD

all:
	perl -pi.bak -e 's/\$$VER\$$/$(VER)/g' README
	rm -f README.bak
	git add README
	git commit -m 'Releases $(VER)'
	git tag $(VER)
	git archive --format=tar --prefix=$(PROJECT)-$(VER) $(VER) | gzip > $(DIR)/$(PROJECT)-$(VER).tar.gz
	git push origin $(VER) || echo
	git reset --hard HEAD~
