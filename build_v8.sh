#!/bin/sh
#
# Appcelerator Titanium Mobile
# Copyright (c) 2011 by Appcelerator, Inc. All Rights Reserved.
# Licensed under the terms of the Apache Public License
# Please see the LICENSE included with this distribution for details.
#
# Build and bundling script for v8 / NDK toolchain

usage()
{
cat <<EOF
Usage: $0 options

This script builds v8 against the Android NDK.
Options:
	-h                Show this help message and exit
	-n <ndk_dir>      The path to the Android NDK. Alternatively, you may set the ANDROID_NDK environment variable
	-j <num-cpus>     The number of processors to use in building (passed on to scons)
	-m <mode>         The v8 build mode (release, debug, all. default: release)
	-l <lib-version>  The "armeabi" versions of V8 to build for (armeabi, armeabi-v7a, all. default: armeabi-v7a)
	-t                Package a thirdparty tarball for uploading (don't build)
	-s                Enable V8 snapshot. Improves performance, but takes longer to compile. (default: off)
	-c                Clean the V8 build
EOF
}

NUM_CPUS=1
MODE=release
LIB_VERSION=armeabi-v7a
THIRDPARTY=0
CLEAN=0
USE_V8_SNAPSHOT=0
while getopts "htscn:j:m:l:" OPTION; do
	case $OPTION in
		h)
			usage
			exit
			;;
		n)
			NDK_DIR=$OPTARG
			;;
		m)
			MODE=$OPTARG
			;;
		j)
			NUM_CPUS=$OPTARG
			;;
		t)
			THIRDPARTY=1
			;;
		s)
			USE_V8_SNAPSHOT=1
			;;
		l)
			LIB_VERSION=$OPTARG
			;;
		c)
			CLEAN=1
			;;
		?)
			usage
			exit
			;;
	esac
done

if [ "$NDK_DIR" = "" ]; then
	NDK_DIR=$ANDROID_NDK
fi

if [ "$NDK_DIR" = "" ]; then
	echo "Error: No Android NDK directory was specified, supply '-n </path/to/ndk>' or set ANDROID_NDK"
	usage
	exit 1
fi

echo "Building against Android NDK: $NDK_DIR"

THIS_DIR=$(cd "$(dirname "$0")"; pwd)
BUILD_DIR=$THIS_DIR/build

if [ ! -d "$BUILD_DIR" ]; then
	mkdir "$BUILD_DIR"
fi

V8_DIR=$THIS_DIR/v8
TOOLCHAIN_DIR=$BUILD_DIR/ndk_toolchain
PLATFORM_VERSION=android-8

buildToolchain()
{
	# remove the previous toolchain
	rm -rf "$TOOLCHAIN_DIR"

	# create stand alone toolchain
	"$NDK_DIR/build/tools/make-standalone-toolchain.sh" --platform=$PLATFORM_VERSION --ndk-dir="$NDK_DIR" --install-dir="$TOOLCHAIN_DIR"
}

applyPatch()
{
	# we assume that errors are just an existing applied patch, so we remove rejects..
	patch -p0 -N -i "$THIS_DIR/patches/ndk_v8.patch" || find v8 -name '*.rej' -exec rm \{\} \;
}

buildV8()
{
	BUILD_MODE=$1
	BUILD_LIB_VERSION=$2


	AR=${TOOLCHAIN_DIR}/bin/arm-linux-androideabi-ar
	CXX="${TOOLCHAIN_DIR}/bin/arm-linux-androideabi-g++ -DANDROID=1 -D__STDC_INT64__=1 -DV8_SHARED=1"
	RANLIB=${TOOLCHAIN_DIR}/bin/arm-linux-androideabi-ranlib

	if [ "$BUILD_LIB_VERSION" = "armeabi" ]; then
		# Build with software FPU (armeabi)
		ARMEABI="soft"
	else
		# Build with mixed software / hardware delegating FPU (armeabi-v7a)
		ARMEABI="softfp"
	fi

	echo "Building V8 mode: $BUILD_MODE, lib: $BUILD_LIB_VERSION, armeabi: $ARMEABI"

	cd "$V8_DIR"

	if [ $USE_V8_SNAPSHOT = 1 ]; then
		# Build Host VM to generate the snapshot.
		scons -j $NUM_CPUS mode=$BUILD_MODE snapshot=on armeabi=$ARMEABI || exit 1

		# We need to move the snapshot now into the V8 src folder
		# before we build the target VM.
		mv obj/release/snapshot.cc src/

		# Clean build before moving onto the target VM compile.
		scons -c
	fi

	# Build the Target VM.
	AR=$AR CXX=$CXX RANLIB=$RANLIB \
	scons -j $NUM_CPUS mode=$BUILD_MODE snapshot=nobuild library=static arch=arm os=linux usepthread=off android=on armeabi=$ARMEABI || exit 1

	LIB_SUFFIX=""
	if [ "$BUILD_MODE" = "debug" ]; then
		# Append _g for debug builds
		LIB_SUFFIX="_g"
	fi

	DEST_DIR="$BUILD_DIR/$BUILD_MODE"
	mkdir -p "$DEST_DIR/libs/$BUILD_LIB_VERSION" 2>/dev/null || echo
	cp "$V8_DIR/libv8$LIB_SUFFIX.a" "$DEST_DIR/libs/$BUILD_LIB_VERSION/libv8$LIB_SUFFIX.a"
}

buildThirdparty()
{
	BUILD_MODE=$1

	# Copied from v8/tools/push-to-trunk.sh
	VERSION_FILE=$V8_DIR/src/version.cc
	MAJOR=$(grep "#define MAJOR_VERSION" "$VERSION_FILE" | awk '{print $NF}')
	MINOR=$(grep "#define MINOR_VERSION" "$VERSION_FILE" | awk '{print $NF}')
	BUILD=$(grep "#define BUILD_NUMBER" "$VERSION_FILE" | awk '{print $NF}')

	cd "$V8_DIR"
	V8_VERSION="$MAJOR.$MINOR.$BUILD"
	V8_GIT_REVISION=$(git rev-parse HEAD)
	V8_GIT_BRANCH=$(git status -s -b | grep \#\# | sed 's/\#\# //')
	V8_SVN_REVISION=$(git log -n 1 | grep git-svn-id | perl -ne 's/\s+git-svn-id: [^@]+@([^\s]+) .+/\1/; print')

	DEST_DIR="$BUILD_DIR/$BUILD_MODE"
	DATE=$(date '+%Y-%m-%d %H:%M:%S')

cat <<EOF > "$DEST_DIR/libv8.json"
{
	"version": "$V8_VERSION",
	"git_revision": "$V8_GIT_REVISION",
	"git_branch": "$V8_GIT_BRANCH",
	"svn_revision": "$V8_SVN_REVISION",
	"timestamp": "$DATE"
}
EOF

	mkdir -p "$DEST_DIR/libs" "$DEST_DIR/include" 2>/dev/null
	cp -R "$V8_DIR/include" "$DEST_DIR"

	cd "$DEST_DIR"
	echo "Building libv8-$V8_VERSION-$BUILD_MODE.tar.bz2..."
	tar -cvj -f libv8-$V8_VERSION-$BUILD_MODE.tar.bz2 libv8.json libs include
}

if [ "$CLEAN" = "1" ]; then
	cd v8 && scons -c
	exit;
fi

if [ ! -d "$TOOLCHAIN_DIR" ]; then
	buildToolchain
fi

if [ "$LIB_VERSION" = "all" ]; then
	LIB_VERSION="armeabi armeabi-v7a"
fi

if [ "$MODE" = "all" ]; then
	MODE="release debug"
fi

if [ "$THIRDPARTY" = "0" ]; then
	applyPatch
	for build_lib_version in $LIB_VERSION; do
		for build_mode in $MODE; do
			buildV8 $build_mode $build_lib_version
		done
	done
else
	for build_mode in $MODE; do
		buildThirdparty $build_mode
	done
fi
