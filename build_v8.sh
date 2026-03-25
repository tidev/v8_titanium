#!/bin/sh
#
# Appcelerator Titanium Mobile
# Copyright (c) 2011-2017 by Appcelerator, Inc. All Rights Reserved.
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
	-s <sdk_dir>      The path to the Android SDK. Alternatively, you may set the ANDROID_SDK environment variable
	-n <ndk_dir>      The path to the Android NDK. Alternatively, you may set the ANDROID_NDK environment variable
	-j <num-cpus>     The number of processors to use in building (passed on to make)
	-m <mode>         The v8 build mode (release, debug, all. default: release)
	-l <lib-version>  Architectures to build for (arm, x64, ia32, arm64, mipsel, x87, all. default: arm)
	-t                Package a thirdparty tarball for uploading (don't build)
	-c                Clean the V8 build
	-p <api-level>    The Android SDK version to support (android-8, android-9, etc. default: android-23)
	-x <target>       Target to build (v8_snapshot || v8_monolith. default: v8_monolith)
EOF
}

# NUM_CPUS=0
MODE=release
LIB_VERSION=arm
THIRDPARTY=0
CLEAN=0
PLATFORM_VERSION=android-29

while getopts "hts:cn:j:m:l:p:x:" OPTION; do
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
			SDK_DIR=$OPTARG
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
		x)
			TARGET=$OPTARG
			;;
		?)
			usage
			exit
			;;
	esac
done

# NDK
if [ "$NDK_DIR" = "" ]; then
	NDK_DIR=$ANDROID_NDK
fi
if [ "$NDK_DIR" = "" ]; then
	echo "Error: No Android NDK directory was specified, supply '-n </path/to/ndk>' or set ANDROID_NDK"
	usage
	exit 1
fi
echo "Building against Android NDK: $NDK_DIR"

# SDK
if [ "$SDK_DIR" = "" ]; then
	SDK_DIR=$ANDROID_SDK
fi
if [ "$SDK_DIR" = "" ]; then
	echo "Error: No Android SDK directory was specified, supply '-s </path/to/sdk>' or set ANDROID_SDK"
	usage
	exit 1
fi
echo "Building against Android SDK: $SDK_DIR"

# build target
if [ "$TARGET" = "" ]; then
	TARGET=v8_monolith
fi

THIS_DIR=$(cd "$(dirname "$0")"; pwd)
BUILD_DIR=$THIS_DIR/build

if [ ! -d "$BUILD_DIR" ]; then
	mkdir "$BUILD_DIR"
fi

V8_DIR=$THIS_DIR/v8

OS=$(uname)

buildV8()
{
	BUILD_MODE=$1
	BUILD_LIB_VERSION=$2
	BUILDER_NAME=$3
	BUILDER_GROUP=$4

	echo "Building $TARGET - mode: $BUILD_MODE, lib: $BUILD_LIB_VERSION, arch: $ARCH"

	cd "$V8_DIR"
	
	# Debug info
	echo "=== Build Configuration ==="
	echo "MAKE_TARGET: $MAKE_TARGET"
	echo "ARCH: $ARCH"
	echo "NDK_DIR: $NDK_DIR"
	echo "SDK_DIR: $SDK_DIR"
	echo "TARGET: $TARGET"

	# Hack one of the toolchain items to fix AR executable used for android
	if [ "$OS" = "Darwin" ]; then
		cp -f ../overrides/build/toolchain/android/BUILD.gn "$V8_DIR/build/toolchain/android/BUILD.gn"
	fi
	# Force building with libc++ from Android NDK
	cp -fvv ../overrides/build/config/android/BUILD.gn "$V8_DIR/build/config/android/BUILD.gn"
	# Create NDK build config directory and copy files
	mkdir -p "$V8_DIR/third_party/android_ndk/sources/android/cpufeatures"
	cp -fvv ../overrides/third_party/android_ndk/BUILD.gn "$V8_DIR/third_party/android_ndk/BUILD.gn"
	if [ ! -f "$V8_DIR/third_party/android_ndk/sources/android/cpufeatures/cpu-features.c" ]; then
		cp -fv "$NDK_DIR/sources/android/cpufeatures/cpu-features.c" "$V8_DIR/third_party/android_ndk/sources/android/cpufeatures/"
	fi

	# Verify NDK files exist
	echo "=== Verifying NDK setup ==="
	echo "Checking: $V8_DIR/third_party/android_ndk/BUILD.gn"
	ls -la "$V8_DIR/third_party/android_ndk/BUILD.gn" || echo "ERROR: BUILD.gn not found!"
	echo "Checking: $V8_DIR/third_party/android_ndk/sources/android/cpufeatures/cpu-features.c"
	ls -la "$V8_DIR/third_party/android_ndk/sources/android/cpufeatures/cpu-features.c" || echo "ERROR: cpu-features.c not found!"

	# Build V8
	MAKE_TARGET="android_$BUILD_LIB_VERSION.$BUILD_MODE"
	
	# Generate args.gn manually to avoid mb.py issues
	echo "=== Generating args.gn ==="
	mkdir -p out.gn/$MAKE_TARGET
	cat > out.gn/$MAKE_TARGET/args.gn << EOF
is_debug = false
is_component_build = false
is_official_build = true
use_goma = false
target_os = "android"
target_cpu = "$GN_ARCH"
v8_enable_pointer_compression = false
v8_enable_minor_mc = false
v8_use_external_startup_data = false
v8_static_library = true
v8_enable_i18n_support = false
v8_monolithic = true
use_custom_libcxx = false
v8_android_log_stdout = false
android_sdk_root = "$SDK_DIR"
android_ndk_root = "$NDK_DIR"
EOF
	cat out.gn/$MAKE_TARGET/args.gn
	
	# Run gn gen
	echo "=== Running gn gen ==="
	buildtools/linux64/gn gen out.gn/$MAKE_TARGET 2>&1 || { echo "ERROR: gn gen failed!"; cat out.gn/$MAKE_TARGET/args.gn; exit 1; }
	
	# Verify build.ninja was created
	if [ -f "out.gn/$MAKE_TARGET/build.ninja" ]; then
		echo "=== build.ninja created successfully ==="
	else
		echo "ERROR: build.ninja was NOT created!"
		exit 1
	fi
	
	# Build using ninja
	if [ ! -z "$NUM_CPUS" ]; then
		ninja -v -C out.gn/$MAKE_TARGET -j $NUM_CPUS $TARGET
	else
		ninja -v -C out.gn/$MAKE_TARGET $TARGET
	fi

	# Copy the static libraries to our staging area.
	DEST_DIR="$BUILD_DIR/$BUILD_MODE"
	mkdir -p "$DEST_DIR/libs/$ARCH" 2>/dev/null || echo
	if [ "$TARGET" = "v8_monolith" ]; then
		cp "$V8_DIR/out.gn/$MAKE_TARGET/obj/libv8_monolith.a"  "$DEST_DIR/libs/$ARCH/libv8_monolith.a"
	fi

	MKSNAPSHOT_X86="$V8_DIR/out.gn/$MAKE_TARGET/clang_x86/mksnapshot"
	if [ -f $MKSNAPSHOT_X86 ]; then
		cp $MKSNAPSHOT_X86 "$DEST_DIR/libs/$ARCH/mksnapshot"
	fi
	MKSNAPSHOT_X64="$V8_DIR/out.gn/$MAKE_TARGET/clang_x64/mksnapshot"
	if [ -f $MKSNAPSHOT_X64 ]; then
		cp $MKSNAPSHOT_X64 "$DEST_DIR/libs/$ARCH/mksnapshot"
	fi
	MKSNAPSHOT_ARM="$V8_DIR/out.gn/$MAKE_TARGET/clang_x86_v8_arm/mksnapshot"
	if [ -f $MKSNAPSHOT_ARM ]; then
		cp $MKSNAPSHOT_ARM "$DEST_DIR/libs/$ARCH/mksnapshot"
	fi
	MKSNAPSHOT_ARM64="$V8_DIR/out.gn/$MAKE_TARGET/clang_x64_v8_arm64/mksnapshot"
	if [ -f $MKSNAPSHOT_ARM64 ]; then
		cp $MKSNAPSHOT_ARM64 "$DEST_DIR/libs/$ARCH/mksnapshot"
	fi

	# Copy embedded blob.
	EMBEDDED="$V8_DIR/out.gn/$MAKE_TARGET/gen/embedded.S"
	if [ -f $EMBEDDED ]; then
		cp $EMBEDDED "$DEST_DIR/libs/$ARCH/embedded.S"
	fi
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
	V8_GIT_BRANCH=$(git status -s -b | grep \#\# | sed 's/\#\# //' | sed 's/...origin\/.*//')
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

	mkdir -p "$DEST_DIR/libs" "$DEST_DIR/include" "$DEST_DIR/include/libplatform" "$DEST_DIR/include/cppgc" 2>/dev/null
	find "$V8_DIR/include" -maxdepth 1 -name '*.h' -exec cp -pv '{}' "$DEST_DIR/include" ';'
	find "$V8_DIR/include/libplatform" -name '*.h' -exec cp -pv '{}' "$DEST_DIR/include/libplatform" ';'
	find "$V8_DIR/include/cppgc" -maxdepth 1 -name '*.h' -exec cp -pv '{}' "$DEST_DIR/include/cppgc" ';'
	cp -r "$V8_DIR/include/cppgc/internal" "$DEST_DIR/include/cppgc/"

	cd "$DEST_DIR"
	echo "Building libv8-$V8_VERSION-$BUILD_MODE.tar.bz2..."
	tar -cvj -f libv8-$V8_VERSION-$BUILD_MODE.tar.bz2 libv8.json libs include
}

if [ "$CLEAN" = "1" ]; then
	cd v8 && rm -rf out.gn/
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
				GN_ARCH=arm
				BUILDER_NAME="V8 Android Arm - builder"
				BUILDER_GROUP="client.v8.ports"
				;;
			ia32)
				ARCH=x86
				GN_ARCH=x86
				BUILDER_NAME="V8 Win32 - builder"
				BUILDER_GROUP="client.v8"
				;;
			mipsel)
				ARCH=mips
				GN_ARCH=mips
				BUILDER_NAME="V8 Mips - builder"
				BUILDER_GROUP="client.v8.ports"
				;;
			arm64)
				ARCH=arm64
				GN_ARCH=arm64
				BUILDER_NAME="V8 Android Arm64 - builder"
				BUILDER_GROUP="client.v8.ports"
				;;
			x64)
				ARCH=x86_64
				GN_ARCH=x64
				BUILDER_NAME="V8 Win64"
				BUILDER_GROUP="client.v8"
				;;
			x87)
				ARCH=x86
				GN_ARCH=x86
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
			buildV8 $build_mode $build_lib_version "$BUILDER_NAME" $BUILDER_GROUP
		done
	done
else
	for build_mode in $MODE; do
		buildThirdparty $build_mode
	done
fi
