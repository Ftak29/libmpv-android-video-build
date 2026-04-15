#!/bin/bash -e

. ../../include/depinfo.sh
. ../../include/path.sh

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf _build$ndk_suffix
	rm -f config.cache
	rm -f ../config.cache
	exit 0
else
	exit 255
fi

# Patch configure.ac before autogen.sh regenerates configure.
python3 - <<'PY'
from pathlib import Path

p = Path("configure.ac")
s = p.read_text()

old = "AC_LANG_PROGRAM([[]], [[pthread_create();]])"
new = """AC_LANG_PROGRAM([[#include <pthread.h>
static void *zvbi_android_pthread_stub(void *arg) { return arg; }]], [[pthread_t t; pthread_create(&t, 0, zvbi_android_pthread_stub, 0);]])"""

count = s.count(old)
if count == 0:
    raise SystemExit("pthread test expression not found in configure.ac")

s = s.replace(old, new)
p.write_text(s)

print(f"Patched configure.ac pthread test expression ({count} occurrence(s))")
PY

if [ ! -f configure ]; then
	command -v autopoint >/dev/null 2>&1 || { echo "autopoint not found; install gettext/autopoint"; exit 1; }
	./autogen.sh
fi

mkdir -p _build$ndk_suffix
cd _build$ndk_suffix

rm -f config.cache
rm -f ../config.cache

env \
	ac_cv_func_pthread_create=yes \
	ac_cv_search_pthread_create='none required' \
	ac_cv_lib_pthread_pthread_create=no \
	ac_cv_lib_pthreadGC2_pthread_create=no \
	../configure \
	CC="$CC" \
	CXX="$CXX" \
	AR="$AR" \
	RANLIB="$RANLIB" \
	CFLAGS="$CFLAGS -fPIC -pthread" \
	CXXFLAGS="$CXXFLAGS -fPIC -pthread" \
	LDFLAGS="$LDFLAGS -pthread" \
	LIBS="-lc" \
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
