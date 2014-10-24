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
	-j <num-cpus>     The number of processors to use in building (passed on to make)
	-m <mode>         The v8 build mode (release, debug, all. default: release)
	-l <lib-version>  Architectures to build for (armeabi, armeabi-v7a, x86, all. default: armeabi-v7a)
	-t                Package a thirdparty tarball for uploading (don't build)
	-s                Enable V8 snapshot. Improves performance, but takes longer to compile. (default: off)
	-c                Clean the V8 build
	-p				  The Android SDK version to support (android-8, android-9, etc.)
EOF
}

NUM_CPUS=1
MODE=release
LIB_VERSION=armeabi-v7a
THIRDPARTY=0
CLEAN=0
USE_V8_SNAPSHOT=0
PLATFORM_VERSION=android-8

while getopts "htscn:j:m:l:p:" OPTION; do
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
		p)
			PLATFORM_VERSION=$OPTARG
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


buildToolchain()
{
	# remove the previous toolchain
	rm -rf "$TOOLCHAIN_DIR"

	# create stand alone toolchain
	"$NDK_DIR/build/tools/make-standalone-toolchain.sh" --platform=$PLATFORM_VERSION --ndk-dir="$NDK_DIR" --install-dir="$TOOLCHAIN_DIR" --arch="$ARCH"	
	if [ $? -ne 0 ]; then
		exit 1
	fi

	# Copy the sources from NDK which the V8 build expects
	# to be located in the NDK toolchain directory.
	echo "Copying NDK sources..."
	rm $TOOLCHAIN_DIR/SOURCES
	cp -R $NDK_DIR/sources $TOOLCHAIN_DIR/
}

buildV8()
{
	BUILD_MODE=$1
	BUILD_LIB_VERSION=$2

	# Build for ARM v7 if requested, otherwise target v5.
	ARMV7="false"
	if [ "$BUILD_LIB_VERSION" = "armeabi-v7a" ]; then
		ARMV7="true"
	fi

	echo "Building V8 mode: $BUILD_MODE, lib: $BUILD_LIB_VERSION, arch: $ARCH, armv7: $ARMV7"

	cd "$V8_DIR"

	# Setup for building V8.
	make dependencies

	# Disable snapshots if requested.
	SNAPSHOT="on"
	if [ $USE_V8_SNAPSHOT = 0 ]; then
		SNAPSHOT="off"
	fi

	# Build V8
	MAKE_TARGET="$BUILD_ARCH.$BUILD_MODE"
	ANDROID_TOOLCHAIN=$TOOLCHAIN_DIR \
	make -j$NUM_CPUS $MAKE_TARGET snapshot=$SNAPSHOT armv7=$ARMV7 --debug=v

	# Copy the static library to our staging area.
	DEST_DIR="$BUILD_DIR/$BUILD_MODE"
	mkdir -p "$DEST_DIR/libs/$BUILD_LIB_VERSION" 2>/dev/null || echo
	cp -R "$V8_DIR/out/$MAKE_TARGET/obj.target/tools/gyp/." \
	      "$DEST_DIR/libs/$BUILD_LIB_VERSION/"
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
	cd v8 && make clean
	exit;
fi

if [ "$LIB_VERSION" = "all" ]; then
	LIB_VERSION="armeabi armeabi-v7a x86"
fi

if [ "$MODE" = "all" ]; then
	MODE="release debug"
fi

if [ "$THIRDPARTY" = "0" ]; then
	for build_lib_version in $LIB_VERSION; do
		# Switch between arm and x86/ia32 arch
		echo $build_lib_version | grep '^arm' 1>/dev/null 2>/dev/null
		IS_ARM=$?
		
		if [ $IS_ARM -eq 0 ]; then
			ARCH='arm'
			BUILD_ARCH='arm'
		else
			REV=`echo ${PLATFORM_VERSION} | sed s/android-//`
			if [ $REV -lt 9 ]; then
				echo "Cannot build x86 with android rev lower than SDK 9; use -p option to specify a different SDK"
				exit 1
			fi;
			ARCH='x86'
			BUILD_ARCH='ia32'
		fi
		
		buildToolchain
		
		for build_mode in $MODE; do
			buildV8 $build_mode $build_lib_version
		done
	done
else
	for build_mode in $MODE; do
		buildThirdparty $build_mode
	done
fi
