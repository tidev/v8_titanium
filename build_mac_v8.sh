if [ -d "depot_tools" ]; then
  cd depot_tools
	git pull origin master
  cd ..
else
	git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
fi

export PATH=`pwd`/depot_tools:"$PATH"
cd v8
git checkout -- . # "clean" the v8 directory
git apply ../ndk11c_5.9.patch
gclient sync --shallow --no-history --reset --force
cd ..
# wget http://dl.google.com/android/repository/android-ndk-r11c-darwin-x86_64.zip
# unzip android-ndk-r11c-darwin-x86_64.zip
# export ANDROID_NDK=${PWD}/android-ndk-r11c
./build_v8.sh -j8 -l ia32 -m release
./build_v8.sh -j8 -l arm -m release
./build_v8.sh -t -m release
