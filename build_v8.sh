#!/bin/sh
#
# Appcelerator Titanium Mobile
# Copyright (c) 2011-2015 by Appcelerator, Inc. All Rights Reserved.
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
	-l <lib-version>  Architectures to build for (arm, x64, ia32, arm64, mipsel, x87, all. default: arm)
	-t                Package a thirdparty tarball for uploading (don't build)
	-s                Enable V8 snapshot. Improves performance, but takes longer to compile. (default: off)
	-c                Clean the V8 build
	-p				  The Android SDK version to support (android-8, android-9, etc.)
EOF
}

NUM_CPUS=1
MODE=release
LIB_VERSION=arm
THIRDPARTY=0
CLEAN=0
USE_V8_SNAPSHOT=0
PLATFORM_VERSION=android-9

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

buildV8()
{
	BUILD_MODE=$1
	BUILD_LIB_VERSION=$2

	echo "Building V8 mode: $BUILD_MODE, lib: $BUILD_LIB_VERSION, arch: $ARCH"

	cd "$V8_DIR"

	# Setup for building V8.
	# FIXME This is supposed to run gclient sync from depot_tools!
	#make dependencies

	# Disable snapshots if requested.
	SNAPSHOT="on"
	SNAPSHOT_TRUTHY="true"
	if [ $USE_V8_SNAPSHOT = 0 ]; then
		SNAPSHOT="off"
		SNAPSHOT_TRUTHY="false"
	fi

	# Build V8
	MAKE_TARGET="android_$BUILD_LIB_VERSION.$BUILD_MODE"
	make $MAKE_TARGET -j$NUM_CPUS snapshot=$SNAPSHOT GYPFLAGS="-Dandroid_ndk_root=$NDK_DIR -Dv8_use_snapshot='$SNAPSHOT_TRUTHY' -Dv8_enable_i18n_support=0 -Dv8_enable_inspector=1" ANDROID_NDK_ROOT=$NDK_DIR

	# Copy the static libraries to our staging area.
	DEST_DIR="$BUILD_DIR/$BUILD_MODE"
	mkdir -p "$DEST_DIR/libs/$ARCH" 2>/dev/null || echo
	cp -R "$V8_DIR/out/$MAKE_TARGET/obj.target/src/." "$DEST_DIR/libs/$ARCH/"
}

buildThirdparty()
{
	BUILD_MODE=$1

	# Copied from v8/tools/push-to-trunk.sh
	VERSION_FILE=$V8_DIR/include/v8-version.h
	MAJOR=$(grep "#define V8_MAJOR_VERSION" "$VERSION_FILE" | awk '{print $NF}')
	MINOR=$(grep "#define V8_MINOR_VERSION" "$VERSION_FILE" | awk '{print $NF}')
	BUILD=$(grep "#define V8_BUILD_NUMBER" "$VERSION_FILE" | awk '{print $NF}')
	PATCH=$(grep "#define V8_PATCH_LEVEL" "$VERSION_FILE" | awk '{print $NF}')

	cd "$V8_DIR"
	V8_VERSION="$MAJOR.$MINOR.$BUILD.$PATCH"
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
	LIB_VERSION="ia32 x64 arm arm64 mipsel x87"
fi

if [ "$MODE" = "all" ]; then
	MODE="release debug"
fi

if [ "$THIRDPARTY" = "0" ]; then
	for build_lib_version in $LIB_VERSION; do

		# Set ARCH for buildToolchain
	    case $build_lib_version in
	        arm)
	            ARCH=arm
	            ;;
	        ia32)
	            ARCH=x86
	            ;;
	        mipsel)
	            ARCH=mips
	            ;;
	        arm64)
	            ARCH=arm64
	            ;;
	        x64)
	            ARCH=x86_64
	            ;;
	        x87)
	            ARCH=x86
	            ;;
	        *)
	            echo "Invalid -l"
	            echo "Please use one of ia32, x64, arm, arm64, mipsel, or x87"
	            ARCH=null
	            exit 1
	            ;;
	    esac

	    # Verify we have a target platform that works with the selected arch
	    # TODO Do we need to do this? I think Android NDK scripts do this for us!
	    REV=`echo ${PLATFORM_VERSION} | sed s/android-//`
	    case $ARCH in
        arm)
            if [ $REV -lt 3 ]; then
				echo "Cannot build arm with android rev lower than SDK 3; use -p option to specify a different SDK"
				exit 1
			fi;
			;;
        x86|mips)
            if [ $REV -lt 9 ]; then
				echo "Cannot build x86 with android rev lower than SDK 9; use -p option to specify a different SDK"
				exit 1
			fi;
            ;;
        arm64|x86_64|mips64)
            if [ $REV -lt 21 ]; then
				echo "Cannot build 64-bit with android rev lower than SDK 21; use -p option to specify a different SDK"
				exit 1
			fi;
            ;;
        esac

		for build_mode in $MODE; do
			buildV8 $build_mode $build_lib_version
		done
	done
else
	for build_mode in $MODE; do
		buildThirdparty $build_mode
	done
fi
