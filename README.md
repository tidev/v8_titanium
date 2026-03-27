# V8 for Titanium Android

This repository stores the patches and revision of the V8 JavaScript engine used in the Titanium Mobile Android port.

## Prerequisites

- Linux (64-bit)
- Python 3 (tested with 3.10+)
- Android NDK r25c
- Android SDK
- ~20GB free disk space

## Setup

### 1. Install depot_tools

```bash
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$PWD/depot_tools:$PATH"
```

### 2. Initialize V8 submodule

```bash
git submodule init
git submodule update --depth 1
```

### 3. Apply patches

```bash
cd v8

# Apply all patches (patch -p1 handles line-offset fuzz tolerance)
patch -p1 < ../DEPS.patch
patch -p1 < ../compat.patch
patch -p1 < ../compat_sparkplug.patch
patch -p1 < ../python3_fixes.patch
patch -p1 < ../compat_jsargs.patch
patch -p1 < ../compat_adaptor.patch
patch -p1 < ../build_options.patch
patch -p1 < ../bit-field-fix.patch
```

### 4. Sync V8 dependencies

```bash
export PATH="$PWD/../depot_tools:$PATH"
export VPYTHON_BYPASS="manually managed python not supported by chrome operations"

gclient sync --shallow --no-history --reset --force --nohooks
```

### 5. Download Android NDK

```bash
# Option A: NDK r25c (recommended for modern systems)
wget https://dl.google.com/android/repository/android-ndk-r25c-linux.zip
unzip android-ndk-r25c-linux.zip
export ANDROID_NDK=$PWD/android-ndk-r25c


### 6. Link NDK into V8

```bash
ln -sf $ANDROID_NDK v8/third_party/android_ndk
```

### 7. Build

```bash
export ANDROID_SDK=/path/to/android-sdk
export ANDROID_NDK=/path/to/android-ndk

# Build for arm64 (uses 64-bit host tools, works on any 64-bit system)
./build_v8.sh -l arm64 -m release -j8

# Build for x64
./build_v8.sh -l x64 -m release -j8
```

### 8. Package

```bash
./build_v8.sh -t
```

This generates `build/release/libv8-<version>-release.tar.bz2` containing:
- `libs/arm64/` - arm64 static library, mksnapshot, embedded.S
- `libs/x86_64/` - x64 static library, mksnapshot, embedded.S
- `include/` - V8 header files
- `libv8.json` - version metadata

## Supported Architectures

| Arch | Builder Host | Notes |
|------|-------------|-------|
| arm64 | x64 | Works on 64-bit systems |
| x64 | x64 | Works on 64-bit systems |
| arm | i386 | Requires 32-bit host libraries |
| ia32 | i386 | Requires 32-bit host libraries |

The `arm` and `ia32` targets build host tools (torque, mksnapshot) as 32-bit
binaries. On systems without 32-bit support, these fail. Install 32-bit libs
with `sudo apt-get install gcc-multilib g++-multilib` on Debian/Ubuntu.

## Patch Description

| Patch | Purpose |
|-------|---------|
| `DEPS.patch` | Modify V8 dependency versions |
| `compat.patch` | API compatibility for Titanium |
| `compat_jsargs.patch` | Revert V8 reverse jsargs argument ordering |
| `compat_adaptor.patch` | Revert V8 arguments adaptor removal |
| `compat_sparkplug.patch` | Sparkplug compiler compatibility |
| `build_options.patch` | Simplify build optimization config |
| `bit-field-fix.patch` | Fix clang enum-constexpr-conversion warning |
| `python3_fixes.patch` | Python 3.10+ compatibility for build tools |

## GitHub Actions

The repository includes a GitHub Actions workflow (`.github/workflows/build.yml`)
that builds V8 for all architectures and packages the final tarball. It uses
NDK r25c and Python 3.
