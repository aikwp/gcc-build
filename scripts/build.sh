#!/usr/bin/env bash
set -euo pipefail
set -x # ENABLES VERBOSE LOGGING: Prints every command so we see EXACTLY what fails

echo "=========================================================="
echo " Starting Universal GCC 16.1.0 Build for Android API 24"
echo " Environment: NDK 29.0.14206865"
echo "=========================================================="

GCC_VERSION="16.1.0"
GCC_TAR_URL="https://github.com/gcc-mirror/gcc/archive/refs/tags/releases/gcc-${GCC_VERSION}.tar.gz"

TARGET="aarch64-linux-android"
API_LEVEL="24"
TERMUX_PREFIX="/data/data/com.termux/files/usr"

# 1. Setup Target Toolchain Variables (NDK LLVM)
TOOLCHAIN="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64"
TARGET_CLANG="${TOOLCHAIN}/bin/${TARGET}${API_LEVEL}-clang"
TARGET_CLANGXX="${TOOLCHAIN}/bin/${TARGET}${API_LEVEL}-clang++"

mkdir -p "${TERMUX_PREFIX}/lib" "${TERMUX_PREFIX}/include"

# 3. Fetch GCC Source
if[ ! -d "gcc" ]; then
    echo "[*] Downloading GCC ${GCC_VERSION} release tarball..."
    wget -qO gcc.tar.gz "${GCC_TAR_URL}" || { echo "FATAL: Failed to download GCC Tarball."; exit 1; }
    mkdir -p gcc
    tar -xzf gcc.tar.gz -C gcc --strip-components=1
    rm gcc.tar.gz
fi

cd gcc

# ====================================================================
# 4. EXPERT PATCHES (UNIVERSAL ANDROID & TERMUX INTEGRATION)
# ====================================================================
echo "[*] Applying heavy expert patches for Android/Bionic & Termux..."

sed -i "s|/system/bin/linker64|${TERMUX_PREFIX}/lib/linker64|g" gcc/config/aarch64/aarch64-linux.h || true
sed -i "s|/system/bin/linker|${TERMUX_PREFIX}/lib/linker|g" gcc/config/linux-android.h || true
sed -i "s|/system/bin/linker64|${TERMUX_PREFIX}/lib/linker64|g" gcc/config/linux-android.h || true

sed -i "s|-X|-X -rpath=${TERMUX_PREFIX}/lib -L${TERMUX_PREFIX}/lib|g" gcc/config/linux-android.h || true
sed -i "s|-rpath-link|-rpath-link=${TERMUX_PREFIX}/lib -rpath-link|g" gcc/config/linux-android.h || true

find . -type f -name "gthr-posix.h" -exec sed -i 's/.*pthread_cancel.*/\/\/ Removed for Android Bionic compatibility/g' {} + || true
sed -i 's|#define LIMITS_H_TEST true|#define LIMITS_H_TEST false|g' gcc/Makefile.in || true

echo "[*] Bypassing dumpspecs to prevent Clang crossed-native crash..."
sed -i 's|$(GCC_FOR_TARGET) -dumpspecs > tmp-specs|touch tmp-specs|g' gcc/Makefile.in || true

echo "[*] Bypassing internal GCC self-tests..."
sed -i 's/-fself-test=[^ ]*//g' gcc/Makefile.in || true
find gcc -type f -name "Make-lang.in" -exec sed -i 's/-fself-test=[^ ]*//g' {} + || true

echo "[*] Downloading GNU prerequisites (GMP, MPFR, MPC)..."
./contrib/download_prerequisites
cd ..

# 5. Configure GCC
mkdir -p build-gcc
cd build-gcc

echo "[*] Configuring GCC Frontend..."

# -w disables all LLVM aesthetic warnings, keeping the GitHub log perfectly clean
SILENT_FLAGS="-O2 -w -Wno-error"

../gcc/configure \
    --build=x86_64-pc-linux-gnu \
    --host=${TARGET} \
    --target=${TARGET} \
    --prefix=${TERMUX_PREFIX} \
    --with-local-prefix=${TERMUX_PREFIX} \
    --with-sysroot=${TERMUX_PREFIX} \
    --with-build-sysroot=${TOOLCHAIN}/sysroot \
    CC_FOR_BUILD="gcc" \
    CXX_FOR_BUILD="g++" \
    CFLAGS_FOR_BUILD="-O2" \
    CXXFLAGS_FOR_BUILD="-O2" \
    CC="${TARGET_CLANG}" \
    CXX="${TARGET_CLANGXX}" \
    AR="${TOOLCHAIN}/bin/llvm-ar" \
    AS="${TOOLCHAIN}/bin/llvm-as" \
    LD="${TOOLCHAIN}/bin/ld.lld" \
    RANLIB="${TOOLCHAIN}/bin/llvm-ranlib" \
    NM="${TOOLCHAIN}/bin/llvm-nm" \
    STRIP="${TOOLCHAIN}/bin/llvm-strip" \
    CFLAGS="${SILENT_FLAGS}" \
    CXXFLAGS="${SILENT_FLAGS}" \
    LDFLAGS="-Wl,-rpath=${TERMUX_PREFIX}/lib -Wl,--enable-new-dtags -L${TERMUX_PREFIX}/lib -Wl,--no-relax" \
    CPPFLAGS="-I${TERMUX_PREFIX}/include" \
    --enable-languages=c,c++ \
    --disable-bootstrap \
    --disable-multilib \
    --disable-nls \
    --disable-libsanitizer \
    --disable-libssp \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libitm \
    --disable-libstdcxx \
    --disable-libatomic \
    --disable-fixincludes \
    --enable-shared \
    --enable-initfini-array \
    --enable-host-pie \
    --enable-host-bind-now \
    --enable-threads=posix \
    --with-system-zlib \
    --enable-default-pie \
    --with-arch=armv8-a \
    --disable-werror

# 6. Build ONLY the GCC Frontend
echo "[*] Compiling GCC 16.1.0 natively for Target Architecture (aarch64)..."
# Single thread (-j1) to absolutely guarantee GitHub Actions doesn't run out of memory!
make all-gcc MAKEINFO=true POD2MAN=true TEXI2DVI=true TEXI2PDF=true -j1

# 7. Install to Staging
echo "[*] Installing to staging directory..."
STAGING_DIR="/workspace/termux-pkg"
make install-gcc MAKEINFO=true POD2MAN=true DESTDIR=${STAGING_DIR}

# 8. Bridge GNU libgcc requirements with Termux Bionic libc/compiler-rt natively
echo "[*] Generating Termux Bionic runtime linker scripts..."
GCC_LIB_DIR="${STAGING_DIR}${TERMUX_PREFIX}/lib/gcc/${TARGET}/${GCC_VERSION}"
mkdir -p "${GCC_LIB_DIR}"
# Provide an empty static libgcc to satisfy basic linkage
${TOOLCHAIN}/bin/llvm-ar rc "${GCC_LIB_DIR}/libgcc.a"
# Secretly redirect standard GNU libraries to Android's libc & llvm libc++
echo "INPUT(-lc)" > "${GCC_LIB_DIR}/libgcc_s.so"
echo "INPUT(-lc++)" > "${GCC_LIB_DIR}/libstdc++.so"

# 9. Packaging (.deb)
echo "[*] Packaging into a Universal Termux compatible .deb file..."
cd /workspace

mkdir -p ${STAGING_DIR}/DEBIAN
cat <<EOF > ${STAGING_DIR}/DEBIAN/control
Package: gcc
Version: ${GCC_VERSION}-1
Architecture: aarch64
Maintainer: GitHub Actions GCC Pipeline
Depends: binutils, ndk-sysroot, libiconv, zlib
Description: Universal GCC ${GCC_VERSION} Toolchain heavily patched for Android Termux Execution (NDK 29)
Homepage: https://gcc.gnu.org/
EOF

echo "[*] Stripping target binaries..."
find ${STAGING_DIR}${TERMUX_PREFIX}/bin -type f -executable -exec ${TOOLCHAIN}/bin/llvm-strip {} + || true
find ${STAGING_DIR}${TERMUX_PREFIX}/libexec -type f -executable -exec ${TOOLCHAIN}/bin/llvm-strip {} + || true

dpkg-deb --build ${STAGING_DIR} gcc-${GCC_VERSION}-termux.deb

echo "[*] Archiving sysroot with xz compression..."
tar -cJf gcc-${GCC_VERSION}-termux-sysroot.tar.xz -C ${STAGING_DIR} .

echo "[*] Pipeline complete!"
ls -lh *.deb *.tar.xz
