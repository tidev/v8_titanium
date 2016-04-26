This is where we store the patches and revision of the v8 repository that we use in the Android port of Titanium Mobile. [![Build Status](https://travis-ci.org/appcelerator/v8_titanium.svg?branch=master)](https://travis-ci.org/appcelerator/v8_titanium)

To build V8, you'll need:

- Android NDK r10e

Build V8 for Android against the NDK:

```
$ ./build_v8.sh -n /path/to/android-ndk

OR

$ export ANDROID_NDK=/path/to/android-ndk
$ ./build_v8.sh
```

To publish V8 to S3, you'll need s3cmd: http://tcpdiag.dl.sourceforge.net/project/s3tools/s3cmd/1.6.0/s3cmd-1.6.0.tar.gz

The Whole Shebang
=======
```
# Apply our patches to v8
git apply 0001-Fix-cross-compilation-for-Android-from-a-Mac.patch
git apply 0002-Create-standalone-static-libs.patch

# Install Android NDK
wget http://dl.google.com/android/ndk/android-ndk-r10e-linux-x86.bin
chmod a+x android-ndk-r10e-linux-x86.bin
./android-ndk-r10e-linux-x86.bin
export ANDROID_NDK=${PWD}/android-ndk-r10e

# Download s3cmd
wget http://tcpdiag.dl.sourceforge.net/project/s3tools/s3cmd/1.6.0/s3cmd-1.6.0.tar.gz
tar -xzf s3cmd-1.6.0.tar.gz
export PATH=${PWD}/android-ndk-r10e

# Configure s3cmd
s3cmd --configure

# build v8 for ARM, and then x86
./build_v8.sh -n /path/to/android-ndk-r10e -j16
./build_v8.sh -n /path/to/android-ndk-r10e -j16 -l ia32

# Generate a tarball to publish
./build_v8.sh -t

# Publish
./publish_v8.sh build/release/libv8-5.0.71.33-release.tar.bz2
```

Full build_v8.sh usage:

```
$ ./build_v8.sh -h
Usage: ./build_v8.sh options

This script builds v8 against the Android NDK.
Options:
	-h              Show this help message and exit
	-n <ndk_dir>    The path to the Android NDK. Alternatively, you may set the ANDROID_NDK environment variable
	-j <num-cpus>   The number of processors to use in building (passed on to scons)
	-m <mode>       The v8 build mode (release, debug. default: release)
	-t              Build a thirdparty tarball for uploading
```

Note: This build is designed to work on a 32-bit Linux. If you wish to install it on a 64-bit version, you would need to install 32-bit libraries:

sudo apt-get -y install gcc-multilib g++-multilib
