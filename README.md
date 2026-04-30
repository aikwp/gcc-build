# gcc-build
# Universal GCC 16 For Android / Termux

An expert-grade pipeline that cross-compiles **GCC 16** via **Android NDK 29.0.14206865 (API 24)** strictly for native execution on Android ARM64 devices.

## Architecture Highlights
* **Decoupled CI/CD Phases:**
  * **Phase 1 (Docker):** Generates a deterministic Ubuntu 24.04 build image with NDK 29. Hashes the `Dockerfile` to push and cache to **GitHub Container Registry (GHCR)**. If the hash hasn't changed, this stage completes in seconds.
  * **Phase 2 (GCC Build):** Leverages the GHCR Docker image to isolate the GCC build. Utilizes the workflow's natively provisioned `GITHUB_TOKEN` to seamlessly upload the final `.deb` and `.tar.gz` to GitHub Releases.
* **Heavy Native Android Patching:**
  * Aggressively mutates internal GCC Spec files directly injecting the proper Termux Bionic `/usr/lib` locations.
  * Disables standard UNIX `pthread_cancel` definitions natively absent in Bionic.
  * Enables modern `--enable-initfini-array` configurations required for API 24+.

## Termux Installation
Download `gcc-16-termux.deb` from the [Releases](https://github.com/yourusername/repo/releases) and execute within Termux:
```bash
pkg install ./gcc-16-termux.deb
gcc -v
