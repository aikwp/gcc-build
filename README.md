# Universal GCC 16.1.0 For Android / Termux

An expert-grade pipeline that cross-compiles **GCC 16.1.0** via **Android NDK 29.0.14206865 (API 24)** strictly for native execution on Android ARM64 devices.

## Architecture Highlights
* **Phase 1 (Builder):** Automatically provisions an isolated environment with NDK 29 and builds the GCC 16 frontends natively for `aarch64`. Target GNU runtime libraries (`libgcc`, `libstdc++`) are intentionally bypassed to prevent crossed-native execution crashes.
* **Phase 2 (Scratch):** Distills the entire 6GB footprint into an empty `scratch` container. Uses the `local` export flag to dump the `.deb` straight out of the void onto the GitHub Actions runner for Release uploading.

## Native Android Termux Integration
Since Android utilizes Bionic (`libc`) and LLVM (`compiler-rt`), GNU's standard libraries are inherently redundant. This package uses lightweight linker scripts placed in the GCC `lib` folder. When you compile code on your device, GCC seamlessly redirects `-lgcc` and `-lstdc++` to Termux's native Android system libraries.

## Termux Installation
Download `gcc-16.1.0-termux.deb` from the [Releases](../../releases) tab and execute within Termux:
```bash
pkg install ./gcc-16.1.0-termux.deb
gcc -v```
