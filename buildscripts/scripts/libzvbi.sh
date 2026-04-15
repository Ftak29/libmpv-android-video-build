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

# Fix broken pthread test
s = s.replace(
    "AC_LANG_PROGRAM([[]], [[pthread_create();]])",
    """AC_LANG_PROGRAM([[#include <pthread.h>
static void *zvbi_android_pthread_stub(void *arg) { return arg; }]],
[[pthread_t t; pthread_create(&t, 0, zvbi_android_pthread_stub, 0);]])"""
)

# Disable fatal error
s = s.replace(
    "AC_MSG_ERROR([Unable to link pthread functions])",
    "AC_MSG_WARN([Skipping pthread link test for Android])"
)

p.write_text(s)

print("Patched pthread test + disabled failure")
PY

# Patch src/conv.c for Android: avoid nl_langinfo()
python3 - <<'PY'
from pathlib import Path

p = Path("src/conv.c")
s = p.read_text()

old = "dst_format = nl_langinfo (CODESET);"
new = """#ifdef __ANDROID__
\tdst_format = "UTF-8";
#else
\tdst_format = nl_langinfo (CODESET);
#endif"""

if old in s:
    s = s.replace(old, new, 1)
    p.write_text(s)
    print("Patched conv.c dst_format nl_langinfo -> UTF-8 fallback for Android")
else:
    print("dst_format nl_langinfo assignment not found in src/conv.c")
PY

if [ ! -f configure ]; then
	command -v autopoint >/dev/null 2>&1 || { echo "autopoint not found; install gettext/autopoint"; exit 1; }
	./autogen.sh
fi

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
  CPPFLAGS="$CPPFLAGS -I$prefix_dir/include" \
  CC="$CC" \
  CXX="$CXX" \
  AR="$AR" \
  RANLIB="$RANLIB" \
  CFLAGS="$CFLAGS -fPIC -pthread -I$prefix_dir/include" \
  CXXFLAGS="$CXXFLAGS -fPIC -pthread -I$prefix_dir/include" \
  LDFLAGS="$LDFLAGS -pthread -L$prefix_dir/lib" \
  LIBS="-liconv -lc" \
  ../configure \
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
