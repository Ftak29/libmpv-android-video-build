#!/bin/bash -e

. ../../include/depinfo.sh
. ../../include/path.sh

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf _build$ndk_suffix
	exit 0
else
	exit 255
fi

if [ ! -f configure ]; then
	command -v autopoint >/dev/null 2>&1 || { echo "autopoint not found; install gettext/autopoint"; exit 1; }
	./autogen.sh
fi

mkdir -p _build$ndk_suffix
cd _build$ndk_suffix

../configure \
	CC="$CC" \
	CXX="$CXX" \
	AR="$AR" \
	RANLIB="$RANLIB" \
	CFLAGS="$CFLAGS -fPIC" \
	CXXFLAGS="$CXXFLAGS -fPIC" \
	LDFLAGS="$LDFLAGS" \
	--host="$ndk_triple" \
	--prefix=/ \
	--with-pic \
	--enable-static \
	--disable-shared \
	--without-doxygen \
	--without-x \
	--disable-dvb \
	--disable-bktr \
	--disable-nls \
	--disable-proxy \
	--disable-examples \
	--disable-tests

make -j$cores
make DESTDIR="$prefix_dir" install
