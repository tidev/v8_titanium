# Grab depot_tools to get gclient, which gets dependencies
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=`pwd`/depot_tools:"$PATH"

# Apply our patch
git apply android-x86.patch

# Grab dependencies
cd v8
gclient sync

cd ..
mkdir -p v8/third_party/android_tools

# Grab Android NDK r12b ourselves?
# wget http://dl.google.com/android/repository/android-ndk-r12b-darwin-x86_64.zip
# unzip android-ndk-r12b-darwin-x86_64.zip
# ln -s ${PWD}/android-ndk-r12b v8/third_party/android_tools/ndk
# Use NDK we have already (SHOULD BE NDK R12B!)
ln -s $ANDROID_NDK v8/third_party/android_tools/ndk
ln -s $ANDROID_SDK v8/third_party/android_tools/sdk

# ARM
cd v8
tools/dev/v8gen.py gen --no-goma -b "V8 Android Arm - builder" -m client.v8.ports android_arm.release -- v8_enable_i18n_support=false symbol_level=0
ninja -C out.gn/android_arm.release -j 8 v8_nosnapshot v8_libplatform
third_party/android_tools/ndk/toolchains/arm-linux-androideabi-4.9/prebuilt/darwin-x86_64/arm-linux-androideabi/bin/ar -rcsD libv8_base.a out.gn/android_arm.release/obj/v8_base/*.o
third_party/android_tools/ndk/toolchains/arm-linux-androideabi-4.9/prebuilt/darwin-x86_64/arm-linux-androideabi/bin/ar -rcsD libv8_libbase.a out.gn/android_arm.release/obj/v8_libbase/*.o
third_party/android_tools/ndk/toolchains/arm-linux-androideabi-4.9/prebuilt/darwin-x86_64/arm-linux-androideabi/bin/ar -rcsD libv8_libsampler.a out.gn/android_arm.release/obj/v8_libsampler/*.o
third_party/android_tools/ndk/toolchains/arm-linux-androideabi-4.9/prebuilt/darwin-x86_64/arm-linux-androideabi/bin/ar -rcsD libv8_libplatform.a out.gn/android_arm.release/obj/v8_libplatform/*.o
third_party/android_tools/ndk/toolchains/arm-linux-androideabi-4.9/prebuilt/darwin-x86_64/arm-linux-androideabi/bin/ar -rcsD libv8_nosnapshot.a out.gn/android_arm.release/obj/v8_nosnapshot/*.o
cd ..
mkdir -p build/release/libs/arm
cp v8/libv8_*.a build/release/libs/arm

# x86
cd v8
tools/dev/v8gen.py gen --no-goma -b "V8 Android x86 - builder" -m client.v8.ports android_x86.release -- v8_enable_i18n_support=false symbol_level=0
ninja -C out.gn/android_x86.release -j 8 v8_nosnapshot v8_libplatform
third_party/android_tools/ndk/toolchains/x86-4.9/prebuilt/darwin-x86_64/i686-linux-android/bin/ar -rcsD libv8_base.a out.gn/android_arm.release/obj/v8_base/*.o
third_party/android_tools/ndk/toolchains/x86-4.9/prebuilt/darwin-x86_64/i686-linux-android/bin/ar -rcsD libv8_libbase.a out.gn/android_arm.release/obj/v8_libbase/*.o
third_party/android_tools/ndk/toolchains/x86-4.9/prebuilt/darwin-x86_64/i686-linux-android/bin/ar -rcsD libv8_libsampler.a out.gn/android_arm.release/obj/v8_libsampler/*.o
third_party/android_tools/ndk/toolchains/x86-4.9/prebuilt/darwin-x86_64/i686-linux-android/bin/ar -rcsD libv8_libplatform.a out.gn/android_arm.release/obj/v8_libplatform/*.o
third_party/android_tools/ndk/toolchains/x86-4.9/prebuilt/darwin-x86_64/i686-linux-android/bin/ar -rcsD libv8_nosnapshot.a out.gn/android_arm.release/obj/v8_nosnapshot/*.o
cd ..
mkdir -p build/release/libs/x86
cp v8/libv8_*.a build/release/libs/x86
