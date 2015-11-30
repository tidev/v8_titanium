git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=`pwd`/depot_tools:"$PATH"
git apply 0000-hack-gclient-for-travis.patch
cd v8
gclient sync
cd ..
git apply 0001-Fix-cross-compilation-for-Android-from-a-Mac.patch
git apply 0002-Create-standalone-static-libs.patch
wget http://dl.google.com/android/ndk/android-ndk-r10e-darwin-x86_64.bin
chmod a+x android-ndk-r10e-darwin-x86_64.bin
./android-ndk-r10e-darwin-x86_64.bin -y | grep -v Extracting
export ANDROID_NDK=${PWD}/android-ndk-r10e
./build_v8.sh -j4
