#!/bin/sh
#
# Appcelerator Titanium Mobile
# Copyright (c) 2011 by Appcelerator, Inc. All Rights Reserved.
# Licensed under the terms of the Apache Public License
# Please see the LICENSE included with this distribution for details.
#
# Build and bundling script for v8 / NDK toolchain

# set this to the where the NDK is installed

usage()
{
cat <<EOF
Usage: $0 options

This script builds v8 against the Android NDK. 
Options:
	-h              Show this help message and exit
	-n <ndk_dir>    The path to the Android NDK. Alternatively, you may set the ANDROID_NDK environment variable
	-j <num-cpus>   The number of processors to use in building (passed on to scons)
	-m <mode>       The v8 build mode (release, debug. default: release)
	-t              Build a thirdparty tarball for uploading
EOF
}

NUM_CPUS=1
MODE=release
while getopts "htn:j:m:" OPTION; do
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
	mkdir $BUILD_DIR
fi

V8_DIR=$THIS_DIR/v8
TOOLCHAIN_DIR=$BUILD_DIR/ndk_toolchain
PLATFORM_VERSION=android-8

buildToolchain()
{
	# remove the previous toolchain
	rm -rf ${TOOLCHAIN_DIR}

	# create stand alone toolchain
	${NDK_DIR}/build/tools/make-standalone-toolchain.sh --platform=${PLATFORM_VERSION} --ndk-dir=${NDK_DIR} --install-dir=${TOOLCHAIN_DIR}
}

applyPatch()
{
	# we assume that errors are just an existing applied patch, so we remove rejects..
	patch -p0 -N -i patches/ndk_v8.patch || find v8 -name '*.rej' -exec rm \{\} \;
}

buildV8()
{	
	AR=${TOOLCHAIN_DIR}/bin/arm-linux-androideabi-ar
	CXX="${TOOLCHAIN_DIR}/bin/arm-linux-androideabi-g++ -DANDROID=1 -D__STDC_INT64__=1"
	RANLIB=${TOOLCHAIN_DIR}/bin/arm-linux-androideabi-ranlib

	cd ${V8_DIR}
	AR=${AR} CXX=${CXX} RANLIB=${RANLIB} \
	scons -j $NUM_CPUS mode=$MODE snapshot=off library=static arch=arm os=linux
}

buildThirdparty()
{
  # Copied from v8/tools/push-to-trunk.sh
  VERSION_FILE=$V8_DIR/src/version.cc
  MAJOR=$(grep "#define MAJOR_VERSION" "$VERSION_FILE" | awk '{print $NF}')
  MINOR=$(grep "#define MINOR_VERSION" "$VERSION_FILE" | awk '{print $NF}')
  BUILD=$(grep "#define BUILD_NUMBER" "$VERSION_FILE" | awk '{print $NF}')

  V8_VERSION="$MAJOR.$MINOR.$BUILD"
  cd $V8_DIR
  V8_GIT_REVISION=$(git rev-parse HEAD)
  V8_GIT_BRANCH=$(git status -s -b | grep \#\# | sed 's/\#\# //')
  V8_SVN_REVISION=$(git log -n 1 | grep git-svn-id | perl -ne 's/\s+git-svn-id: [^@]+@([^\s]+) .+/\1/; print')

  DATE=$(date '+%Y-%m-%d %H:%M:%S')
cat <<EOF > $BUILD_DIR/libv8.json
{
	"version": "$V8_VERSION",
	"git_revision": "$V8_GIT_REVISION",
	"git_branch": "$V8_GIT_BRANCH",
	"svn_revision": "$V8_SVN_REVISION",
	"timestamp": "$DATE"
}
EOF

  cp $V8_DIR/libv8.a $BUILD_DIR
  cd $BUILD_DIR

  echo "Building libv8-$V8_VERSION.tar.bz2..."
  tar -cvj -f libv8-$V8_VERSION.tar.bz2 libv8.json libv8.a
}

if [ ! -d "$TOOLCHAIN_DIR" ]; then
	buildToolchain
fi

applyPatch
buildV8

if [ "$THIRDPARTY" = "1" ]; then
	buildThirdparty
fi
