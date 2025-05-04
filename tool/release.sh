PROJECT=luatexja
DIR=`pwd`/..
VER=${VER:-`date +%Y%m%d.0`}

TEMP=/tmp

echo "Making Release $VER. Ctrl-C to cancel."
read REPLY
if test -d "$TEMP/$PROJECT"; then
  echo "Warning: the directory '$TEMP/$PROJECT' is found:"
  echo
  ls $TEMP/$PROJECT
  echo
  echo -n "I'm going to remove this directory. Continue? yes/No"
  echo
  read REPLY <&2
  case $REPLY in
    y*|Y*) rm -rf $TEMP/$PROJECT;;
    *) echo "Aborted."; exit 1;;
  esac
fi
echo
git commit -m "Releases $VER" --allow-empty
git archive --format=tar --prefix=$PROJECT/ HEAD | (cd $TEMP && tar xpf -)
cd $TEMP
rm -rf $PROJECT/test
rm -rf $PROJECT/src/*.cl*
rm -rf $PROJECT-orig
cp -r $PROJECT $PROJECT-orig
cd $PROJECT
perl -pi.bak -e "s/\\\$VER\\\$/$VER/g" README
rm -f README.bak
cd ..
diff -urN $PROJECT-orig $PROJECT
tar zpcf $DIR/$PROJECT-$VER.tar.gz $PROJECT
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

