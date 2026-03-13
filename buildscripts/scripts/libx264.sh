#!/bin/bash -e

. ../../include/depinfo.sh
. ../../include/path.sh

build=_build$ndk_suffix

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf "$build"
	exit 0
else
	exit 255
fi

mkdir -p "$build"
cd "$build"

case "${CC%%-*}" in
    armv7a)  x264_host=arm-linux ;;
    aarch64) x264_host=aarch64-linux-android ;;
    i686)    x264_host=i686-linux-android ;;
    x86_64)  x264_host=x86_64-linux-android ;;
    *)
        echo "Unsupported x264 host for compiler: $CC" >&2
        exit 1
        ;;
esac

sysroot="$($CC -print-sysroot)"

CC="$CC" \
CXX="$CXX" \
AR="$AR" \
AS="$AS" \
RANLIB="$RANLIB" \
STRIP="${STRIP:-llvm-strip}" \
../configure \
    --prefix="$prefix_dir" \
    --host="$x264_host" \
    --sysroot="$sysroot" \
    --disable-cli \
    --enable-static \
    --enable-pic
	
make -j"$cores"
make install
