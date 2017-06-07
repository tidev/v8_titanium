git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=`pwd`/depot_tools:"$PATH"
cd v8
git apply ../ndk11c_5.9.patch
gclient sync
cd ..
wget http://dl.google.com/android/repository/android-ndk-r11c-darwin-x86_64.zip
unzip android-ndk-r11c-darwin-x86_64.zip
export ANDROID_NDK=${PWD}/android-ndk-r11c
./build_v8.sh -j8
