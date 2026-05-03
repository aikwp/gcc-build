# Universal GCC 16.1.0 For Android / Termux

An expert-grade pipeline that cross-compiles **GCC 16.1.0** via **Android NDK 29.0.14206865 (API 24)** strictly for native execution on Android ARM64 devices.

## Architecture Highlights: Docker Scratch Extraction
This pipeline utilizes a pure multi-stage Docker build to guarantee absolutely immaculate artifact generation:
* **Stage 1 (Builder):** Automatically provisions an isolated environment with NDK 29, builds GCC 16 natively, and isolates the generated `.deb`.
* **Stage 2 (Scratch):** Distills the entire 6GB build footprint into an empty `scratch` image containing *only* the `.deb` and `.tar.xz`.
* **Docker Buildx:** Uses the `local` export flag to dump those artifacts straight out of the virtualized void onto the GitHub Actions runner for Release uploading.

## Native Android Patching
Because LLVM/Clang acts as the cross-compiler, we actively sed/mutate several internal GCC targets to prevent "Exec format errors" and Bionic linker faults:
* Completely silences legacy LLVM C++ C-tag warnings via universal `-w` injections.
* Removes internal `-fbuilding-libgcc`, `-dumpspecs`, and `-fself-test` assertions incompatible with Clang's strict interface parsing.
* Injects Termux Library Runpaths (`-rpath`) safely onto natively executed target binaries.

## Termux Installation
Download `gcc-16.1.0-termux.deb` from the [Releases](../../releases) tab and execute within Termux:
```bash
pkg install ./gcc-16.1.0-termux.deb
gcc -v
