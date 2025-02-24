#!/bin/bash -e

. ../../include/path.sh

build=_build$ndk_suffix

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf $build
	exit 0
else
	exit 255
fi

mkdir -p $build
cd $build

echo $CC
which armv7a-linux-androideabi21-clang

cmake .. \
	-DENABLE_SHARED=ON \
	-DENABLE_STATIC=OFF \
	-DENABLE_ENCRYPTION=ON \
	-DCMAKE_PREFIX_PATH="$prefix_dir" \
	-DUSE_ENCLIB=mbedtls \
	-DCMAKE_PLATFORM_NO_VERSIONED_SONAME=ON

make -j$cores
make DESTDIR="$prefix_dir" install
