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

rm -rf build/

export PATH="`pwd`/depot_tools:$PATH"
cd v8
git checkout -- . # "clean" the v8 directory
rm -rf out.gn/
echo "Asking gclient to clean v8 dependencies"
../depot_tools/gclient recurse git clean -fdx
echo "Applying dependency patch"
git apply ../DEPS.patch
ln -s $ANDROID_NDK third_party/android_ndk
echo "Asking gclient to update v8 dependencies"
../depot_tools/gclient sync --shallow --no-history --reset --force
cd ..

echo "Cleaning v8 build"
./build_v8.sh -c
# Now manually clean since that usually fails trying to clean non-existant tags dir
rm -rf build/

echo "Building v8 for x86..."
./build_v8.sh "-l" "ia32" "-m" "release"
echo "Building v8 for ARM..."
./build_v8.sh "-l" "arm" "-m" "release"
echo "Building v8 for ARM-64..."
./build_v8.sh "-l" "arm64" "-m" "release"

echo "Packaging built v8 into tarball..."
./build_v8.sh "-t" "-m" "release"
