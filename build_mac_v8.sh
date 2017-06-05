git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=`pwd`/depot_tools:"$PATH"
git apply 0000-hack-gclient-for-travis.patch
cd v8
git apply ../ndk12_5.9.patch
gclient sync
cd ..
wget http://dl.google.com/android/repository/android-ndk-r12b-darwin-x86_64.zip
unzip android-ndk-r12b-darwin-x86_64.zip
export ANDROID_NDK=${PWD}/android-ndk-r12b
./build_v8.sh -j8
