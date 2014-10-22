This is where we store the patches and revision of the v8 repository that we use in the Android port of Titanium Mobile. [![Build Status](https://travis-ci.org/appcelerator/v8_titanium.svg?branch=master)](https://travis-ci.org/appcelerator/v8_titanium)

To build V8, you'll need:

- Android NDK r8d

Build V8 for Android against the NDK:

```
$ ./build_v8.sh -n /path/to/android-ndk

OR

$ export ANDROID_NDK=/path/to/android-ndk
$ ./build_v8.sh
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
