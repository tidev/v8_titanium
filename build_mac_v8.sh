#!/bin/sh
if [ -d "depot_tools" ]; then
  echo "Updating existing depot_tools checkout..."
  cd depot_tools
  git pull origin master
  cd ..
else
  echo "Cloning depot_tools..."
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
fi

export PATH=`pwd`/depot_tools:"$PATH"
cd v8
git checkout -- . # "clean" the v8 directory
rm -rf out.gn/
git apply ../ndkr16b_6.7.patch
echo "Asking gclient to update v8 dependencies"
gclient sync --shallow --no-history
cd ..
# wget http://dl.google.com/android/repository/android-ndk-r16b-darwin-x86_64.zip
# unzip android-ndk-r16b-darwin-x86_64.zip
# export ANDROID_NDK=${PWD}/android-ndk-r16b
echo "Building v8 for x86..."
./build_v8.sh "-j" "8" "-l" "ia32" "-m" "release"
echo "Building v8 for ARM..."
./build_v8.sh "-j" "8" "-l" "arm" "-m" "release"
echo "Building v8 for ARM-64..."
./build_v8.sh "-j" "8" "-l" "arm64" "-m" "release"
echo "Packaging built v8 into tarball..."
./build_v8.sh "-t" "-m" "release"
