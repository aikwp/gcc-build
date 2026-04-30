#!/bin/bash
set -euo pipefail

echo "=========================================================="
echo " Starting Universal GCC 16 Build for Android API 24"
echo " Environment: NDK 29.0.14206865"
echo "=========================================================="

GCC_BRANCH="master"
TARGET="aarch64-linux-android"
API_LEVEL="24"
TERMUX_PREFIX="/data/data/com.termux/files/usr"

# 1. Setup Host Toolchain Variables
export CC_FOR_BUILD="gcc"
export CXX_FOR_BUILD="g++"
export LD_FOR_BUILD="ld"
export AR_FOR_BUILD="ar"
export AS_FOR_BUILD="as"
export RANLIB_FOR_BUILD="ranlib"

# 2. Setup Target Toolchain Variables (NDK LLVM)
TOOLCHAIN="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64"
export AR="${TOOLCHAIN}/bin/llvm-ar"
export AS="${TOOLCHAIN}/bin/llvm-as"
export CC="${TOOLCHAIN}/bin/${TARGET}${API_LEVEL}-clang"
export CXX="${TOOLCHAIN}/bin/${TARGET}${API_LEVEL}-clang++"
export LD="${TOOLCHAIN}/bin/ld.lld"
export RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
export STRIP="${TOOLCHAIN}/bin/llvm-strip"

# 3. Environment Headers & Linkers Flags
export LDFLAGS="-Wl,-rpath=${TERMUX_PREFIX}/lib -Wl,--enable-new-dtags -L${TERMUX_PREFIX}/lib"
export CPPFLAGS="-I${TERMUX_PREFIX}/include"
export CXXFLAGS="-O2 -fPIC"
export CFLAGS="-O2 -fPIC"

# Mock the environment to prevent build-time linker warnings
mkdir -p "${TERMUX_PREFIX}/lib" "${TERMUX_PREFIX}/include"

# 4. Fetch GCC Source
if [ ! -d "gcc" ]; then
    echo "[*] Cloning GCC repository (branch: ${GCC_BRANCH})..."
    git clone --depth 1 -b ${GCC_BRANCH} https://gcc.gnu.org/git/gcc.git gcc
fi

cd gcc

# ====================================================================
# 5. THE HEAVY PATCHES (UNIVERSAL ANDROID & TERMUX INTEGRATION)
# ====================================================================
echo "[*] Applying heavy expert patches for Android/Bionic & Termux..."

# Patch A: Rewrite linker paths in GCC specs for aarch64
sed -i "s|/system/bin/linker64|${TERMUX_PREFIX}/lib/linker64|g" gcc/config/aarch64/aarch64-linux.h || true
sed -i "s|/system/bin/linker|${TERMUX_PREFIX}/lib/linker|g" gcc/config/linux-android.h || true
sed -i "s|/system/bin/linker64|${TERMUX_PREFIX}/lib/linker64|g" gcc/config/linux-android.h || true

# Patch B: Inject Termux Library Search Paths into Android Spec
sed -i "s|-X|-X -rpath=${TERMUX_PREFIX}/lib -L${TERMUX_PREFIX}/lib|g" gcc/config/linux-android.h || true
sed -i "s|-rpath-link|-rpath-link=${TERMUX_PREFIX}/lib -rpath-link|g" gcc/config/linux-android.h || true

# Patch C: Universal Bionic libc compatibility (Disable pthread_cancel)
# Bionic doesn't support thread cancellation. Standard libgcc compilation fails without this.
# Instead of a static file check, we aggressively find and patch all gthr-posix.h variants in the tree.
echo "[*] Purging pthread_cancel for Android Bionic compatibility..."
find . -type f -name "gthr-posix.h" -exec sed -i 's/.*pthread_cancel.*/\/\/ Removed for Android Bionic compatibility/g' {} + || true

# Patch D: Prevent Limits.h generation issues on cross-compiles
sed -i 's|#define LIMITS_H_TEST true|#define LIMITS_H_TEST false|g' gcc/Makefile.in || true

echo "[*] Downloading GNU prerequisites (GMP, MPFR, MPC)..."
./contrib/download_prerequisites
cd ..

# 6. Configure GCC
mkdir -p build-gcc
cd build-gcc

echo "[*] Configuring GCC..."
# We use initfini-array because Android API 24 completely deprecates .ctors/.dtors
../gcc/configure \
    --build=x86_64-pc-linux-gnu \
    --host=${TARGET} \
    --target=${TARGET} \
    --prefix=${TERMUX_PREFIX} \
    --with-local-prefix=${TERMUX_PREFIX} \
    --with-sysroot=${TOOLCHAIN}/sysroot \
    --enable-languages=c,c++ \
    --disable-multilib \
    --disable-nls \
    --disable-libsanitizer \
    --enable-shared \
    --enable-initfini-array \
    --enable-threads=posix \
    --with-system-zlib \
    --enable-default-pie \
    --with-arch=armv8-a \
    --disable-werror

# 7. Build GCC
echo "[*] Compiling GCC natively for Target Architecture (aarch64)..."
make -j$(nproc)

# 8. Install to Staging
echo "[*] Installing to staging directory..."
STAGING_DIR="${GITHUB_WORKSPACE}/termux-pkg"
make DESTDIR=${STAGING_DIR} install

# 9. Packaging (.deb)
echo "[*] Packaging into a Universal Termux compatible .deb file..."
cd ${GITHUB_WORKSPACE}

mkdir -p ${STAGING_DIR}/DEBIAN
cat <<EOF > ${STAGING_DIR}/DEBIAN/control
Package: gcc-16
Version: 16.0.0-1
Architecture: aarch64
Maintainer: GitHub Actions GCC Pipeline
Depends: binutils, ndk-sysroot, libiconv, zlib
Description: Universal GCC 16 Toolchain heavily patched for Android Termux Execution (NDK 29)
Homepage: https://gcc.gnu.org/
EOF

# Vigorously strip compiler executables to minimize the final .deb package footprint
echo "[*] Stripping target binaries..."
find ${STAGING_DIR}${TERMUX_PREFIX}/bin -type f -executable -exec ${STRIP} {} + || true
find ${STAGING_DIR}${TERMUX_PREFIX}/libexec -type f -executable -exec ${STRIP} {} + || true

dpkg-deb --build ${STAGING_DIR} gcc-16-termux.deb

# Compressed backup sysroot artifact
tar -czf gcc-16-termux-sysroot.tar.gz -C ${STAGING_DIR} .

echo "[*] Pipeline complete!"
ls -lh *.deb *.tar.gz
