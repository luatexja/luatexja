PROJECT=luatexja
DIR=`pwd`/..
VER=${VER:-`date +%Y%m%d.0`}

TEMP=/tmp

echo "Making Release $VER. Ctrl-C to cancel."
read REPLY
if test -d "$TEMP/$PROJECT-$VER"; then
  echo "Warning: the directory '$TEMP/$PROJECT-$VER' is found:"
  echo
  ls $TEMP/$PROJECT-$VER
  echo
  echo -n "I'm going to remove this directory. Continue? yes/No"
  echo
  read REPLY <&2
  case $REPLY in
    y*|Y*) rm -rf $TEMP/$PROJECT-$VER;;
    *) echo "Aborted."; exit 1;;
  esac
fi
echo
git commit -m "Releases $VER" --allow-empty
git archive --format=tar --prefix=$PROJECT-$VER/ HEAD | (cd $TEMP && tar xf -)
cd $TEMP
rm -rf $PROJECT-$VER/test
rm -rf $PROJECT-$VER/src/*.cl*
rm -rf $PROJECT-$VER/src/ltj-kinsoku.lua
rm -rf $PROJECT-$VER-orig
cp -r $PROJECT-$VER $PROJECT-$VER-orig
cd $PROJECT-$VER
perl -pi.bak -e "s/\\\$VER\\\$/$VER/g" README
rm -f README.bak
cd ..
diff -urN $PROJECT-$VER-orig $PROJECT-$VER
tar zcf $DIR/$PROJECT-$VER.tar.gz $PROJECT-$VER
echo
echo You should execute
echo
echo "  git push && git tag $VER && git push origin $VER"
echo
echo Informations for submitting CTAN: 
echo "  CONTRIBUTION: LuaTeX-ja"
echo "  AUTHOR:       The LuaTeX-ja project"
echo "  SUMMARY:      Typeset Japanese documents with Lua(La)TeX."
echo "  DIRECTORY:    macros/luatex/generic/luatexja"
echo "  LICENSE:      bsd (BSD-like License)"
echo "  FILE:         $DIR/$PROJECT-$VER.tar.gz"

