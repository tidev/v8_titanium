git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=`pwd`/depot_tools:"$PATH"
git apply 0000-hack-gclient-for-travis.patch
cd v8
git apply ../ndk14_5.8.patch
gclient sync
cd ..
wget http://dl.google.com/android/repository/android-ndk-r14b-darwin-x86_64.zip
unzip android-ndk-r14b-darwin-x86_64.zip
export ANDROID_NDK=${PWD}/android-ndk-r14b
./build_v8.sh -j8
