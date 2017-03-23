This is where we store the patches and revision of the v8 repository that we use in the Android port of Titanium Mobile. [![Build Status](https://travis-ci.org/appcelerator/v8_titanium.svg?branch=master)](https://travis-ci.org/appcelerator/v8_titanium)

To build V8, you'll need:

- Android NDK r11c

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
wget http://dl.google.com/android/repository/android-ndk-r11c-linux-x86_64.zip
unzip android-ndk-r11c-linux-x86_64.zip
export ANDROID_NDK=${PWD}/android-ndk-r11c

# Download s3cmd
wget http://tcpdiag.dl.sourceforge.net/project/s3tools/s3cmd/1.6.0/s3cmd-1.6.0.tar.gz
tar -xzf s3cmd-1.6.0.tar.gz
export PATH=${PWD}/s3cmd-1.6.0

# Configure s3cmd
s3cmd --configure

# build v8 for ARM, and then x86
./build_v8.sh -n /path/to/android-ndk-r11c -j16
./build_v8.sh -n /path/to/android-ndk-r11c -j16 -l ia32

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


# Notes

- https://github.com/v8/v8/wiki/Building-with-GN
- https://medium.com/@hyperandroid/compile-v8-for-arm-7-df45372f9d4e#.q9to6evr0
- https://chromium.googlesource.com/chromium/src/+/master/tools/gn/docs/quick_start.md
- https://chromium.googlesource.com/chromium/src/+/master/docs/android_build_instructions.md


Uses Android NDK r12b with a couple patches
- cd v8
- # On Mac, we need to hack the NDK/SDK used, since it uses linux version. So create symbolic link to pre-installed versions we have
- mkdir third_party/android_tools
- ln -s /opt/android-ndk-r12b third_party/android_tools/ndk
- ln -s /opt/android-sdk third_party/android_tools/sdk
- tools/dev/v8gen.py gen --no-goma -b "V8 Android Arm - builder" -m client.v8.ports android_arm.release -- v8_enable_i18n_support=false symbol_level=0
- ninja -C out.gn/android_arm.release -j 8 v8_nosnapshot
- third_party/android_tools/ndk/toolchains/arm-linux-androideabi-4.9/prebuilt/darwin-x86_64/arm-linux-androideabi/bin/ar -rcsD libv8_base.a out.gn/android_arm.release/obj/v8_base/*.o
- third_party/android_tools/ndk/toolchains/arm-linux-androideabi-4.9/prebuilt/darwin-x86_64/arm-linux-androideabi/bin/ar -rcsD libv8_libbase.a out.gn/android_arm.release/obj/v8_libbase/*.o
- third_party/android_tools/ndk/toolchains/arm-linux-androideabi-4.9/prebuilt/darwin-x86_64/arm-linux-androideabi/bin/ar -rcsD libv8_libsampler.a out.gn/android_arm.release/obj/v8_libsampler/*.o
- third_party/android_tools/ndk/toolchains/arm-linux-androideabi-4.9/prebuilt/darwin-x86_64/arm-linux-androideabi/bin/ar -rcsD libv8_libplatform.a out.gn/android_arm.release/obj/v8_libplatform/*.o
- third_party/android_tools/ndk/toolchains/arm-linux-androideabi-4.9/prebuilt/darwin-x86_64/arm-linux-androideabi/bin/ar -rcsD libv8_nosnapshot.a out.gn/android_arm.release/obj/v8_nosnapshot/*.o
