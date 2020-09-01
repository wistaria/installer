#!/bin/sh

SOURCE="$1"
PREFIX="$2"
SCRIPTDIR=$(cd "$(dirname $0)"; pwd)

if [ -z $PREFIX ]; then
  echo "Usage: $0 source_tarball prefix"
  exit 127
fi

SHAREDIR="$PREFIX/share"
OCTADIR="$SHAREDIR/octa"

if [ -d "$OCTADIR" ]; then
  echo "Error: OCTA directory exists ($OCTADIR)"
  exit 127
fi

# Extract files from the tarball
if [ -f "$SOURCE" ]; then :; else
  echo "Error: source not found ($SOURCE)"
  exit 127
fi
MD5SUM=`md5sum "$SOURCE" | awk '{print $1}'`
if [ "$MD5SUM" = "e2154c6f20778b967554696a3233a357" ]; then
  VERSION="8.3"
else
  echo "Error: unkown version or corrupted archive"
  exit 127
fi
echo "OCTA version = $VERSION"

# required Debian packages
if [ $(lsb_release -c -s) = "stretch" ]; then
  echo "live" | sudo -S apt-get -y install openjdk-8-jdk
fi
if [ $(lsb_release -c -s) = "buster" ]; then
  echo "live" | sudo -S apt-get -y install openjdk-11-jdk
fi
echo "live" | sudo -S apt-get -y install libgl1-mesa-dev libglu1-mesa-dev libz-dev libjpeg-dev libpng-dev

# 展開
VERSION_NODOT=$(echo $VERSION | sed s/\\.//g)
mkdir -p $OCTADIR
tar zxvf $SOURCE -C $OCTADIR
tar zxvf $OCTADIR/INSTALLER$VERSION_NODOT/OCTA8PKG/GOURMET/gourmet_08_linux.tar.gz -C $OCTADIR
mkdir -p $OCTADIR/GOURMET/bin/linux_64
mkdir -p $OCTADIR/GOURMET/lib/linux_64
tar zxvf $OCTADIR/INSTALLER$VERSION_NODOT/OCTA8PKG/PF_ENGINE/engines_08_linux.tar.gz -C $OCTADIR
cp -rp $OCTADIR/INSTALLER$VERSION_NODOT/DOCUMENTS $OCTADIR
tar zxvf $OCTADIR/INSTALLER$VERSION_NODOT/OCTA8PKG/EXTERNAL_SOFTWARE/jogl-v2.2.4-linux-amd64.tar.gz -C $OCTADIR/GOURMET/lib/linux_64
cp -fp $OCTADIR/INSTALLER$VERSION_NODOT/OCTA8PKG/SCRIPTS/octa_configuration.sh $OCTADIR/INSTALLER$VERSION_NODOT/OCTA8PKG/SCRIPTS/gourmet_configuration.txt $OCTADIR/GOURMET/bin/linux_64/
rm -rf $OCTADIR/INSTALLER$VERSION_NODOT

# apply patch
if [ -f $SCRIPTDIR/octa-$VERSION.patch ]; then
  (cd $OCTADIR && patch -p1 < $SCRIPTDIR/octa-$VERSION.patch)
fi

# generate scripts
(cd $OCTADIR/GOURMET && sh $OCTADIR/GOURMET/bin/linux_64/octa_configuration.sh $OCTADIR/ENGINES)

# GOURMET
cd $OCTADIR/GOURMET/src
./configure --with-python=python3 --with-java-home
make
make install

# ENGINES
rm -f $OCTADIR/ENGINES/bin/linux_64/*
export PF_FILES=$OCTADIR/GOURMET
export PF_ENGINE=$OCTADIR/ENGINES
export PF_ENGINEARCH=linux_64
ENGINES="SUSHI10.54 COGNAC923/python/analysis/src COGNAC923/src kapsel3.32 MUFFIN5/src/muffin5 MUFFIN5/src/muffin5/muffin_udf MUFFIN5/src/muffin5ebeta MUFFIN5/src/turban PASTA/FORK/src PASTA/PASTA/src PASTA/tools/src"
for ENGINE in $ENGINES; do
  cd $OCTADIR/ENGINES/$ENGINE
  make
  make install
done

# symbolic links
mkdir -p "$PREFIX/bin"
FILES="gourmet gourmetterm dat_man eng_man transmitter"
for f in $FILES; do
  rm -f "$PREFIX/bin/$f"
  ln -s "$OCTADIR/GOURMET/$f" "$PREFIX/bin/$f"
done
FILES=$(cd $OCTADIR/ENGINES/bin/linux_64; ls)
for f in $FILES; do
  rm -f "$PREFIX/bin/$f"
  ln -s "$OCTADIR/ENGINES/bin/linux_64/$f" "$PREFIX/bin/$f"
done

echo "Compilation Done"
