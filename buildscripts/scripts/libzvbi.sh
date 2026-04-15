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

python3 - <<'PY'
from pathlib import Path

p = Path("src/Makefile.am")
s = p.read_text()

remove = [
    "io-v4l.c",
    "io-v4l2.c",
    "io-v4l2k.c",
    "io-bktr.c",
    "io-dvb.c",
    "dvb_mux.c",
    "dvb_demux.c",
]

changed = False
for name in remove:
    if name in s:
        s = s.replace(name, "")
        changed = True

if changed:
    p.write_text(s)
    print("Patched src/Makefile.am to remove Linux capture backends for Android")
else:
    print("No Linux capture backend filenames found in src/Makefile.am")
PY

python3 - <<'PY'
from pathlib import Path

p = Path("Makefile.am")
s = p.read_text()

old = "SUBDIRS = m4 po src test examples contrib"
if old in s:
    s = s.replace(old, "SUBDIRS = m4 po src")
    p.write_text(s)
    print("Patched Makefile.am to build only core libzvbi directories for Android")
else:
    # fallback: remove contrib/examples/test tokens if present
    orig = s
    s = s.replace(" contrib", "")
    s = s.replace(" examples", "")
    s = s.replace(" test", "")
    if s != orig:
        p.write_text(s)
        print("Patched Makefile.am to remove contrib/examples/test for Android")
    else:
        print("Top-level SUBDIRS line not found in Makefile.am")
PY

python3 - <<'PY'
from pathlib import Path

p = Path("Makefile.am")
s = p.read_text()

orig = s

# Remove non-library dirs from SUBDIRS
s = s.replace(" contrib", "")
s = s.replace(" examples", "")
s = s.replace(" test", "")
s = s.replace(" tests", "")

if s != orig:
    p.write_text(s)
    print("Patched top-level Makefile.am to remove contrib/examples/test for Android")
else:
    print("No contrib/examples/test entries changed in top-level Makefile.am")
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
  ac_cv_func_malloc_0_nonnull=yes \
  ac_cv_func_realloc_0_nonnull=yes \
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
	
make -C src -j$cores
make -C src DESTDIR="$prefix_dir" install

make -C src -j$cores
make -C src DESTDIR="$prefix_dir" install

mkdir -p "$prefix_dir/lib/pkgconfig"

# Copy zvbi pkg-config file into the Android prefix if install did not place it there.
find . -name 'zvbi-0.2.pc' -exec cp {} "$prefix_dir/lib/pkgconfig/" \; 2>/dev/null || true

pc="$prefix_dir/lib/pkgconfig/zvbi-0.2.pc"
if [ -f "$pc" ]; then
  sed -i "s|^prefix=.*|prefix=$prefix_dir|" "$pc"
  sed -i "s|^libdir=.*|libdir=$prefix_dir/lib|" "$pc"
  sed -i "s|^includedir=.*|includedir=$prefix_dir/include|" "$pc"
  echo "Prepared $pc for FFmpeg pkg-config lookup"
else
  echo "zvbi-0.2.pc not found after libzvbi install"
  exit 1
fi
