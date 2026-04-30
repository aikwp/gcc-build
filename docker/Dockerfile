FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ANDROID_HOME=/opt/android-sdk
ENV NDK_VERSION=29.0.14206865
ENV ANDROID_NDK_HOME=${ANDROID_HOME}/ndk/${NDK_VERSION}
ENV PATH=${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl wget git unzip python3 \
    bison flex texinfo gawk libgmp-dev libmpfr-dev libmpc-dev zlib1g-dev \
    openjdk-17-jdk-headless dpkg-dev file cmake patch m4 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    cd ${ANDROID_HOME}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O tools.zip && \
    unzip -q tools.zip && rm tools.zip && \
    mv cmdline-tools latest

RUN yes | sdkmanager --licenses && \
    sdkmanager "platforms;android-24" "ndk;${NDK_VERSION}"

# Create build workspace
RUN mkdir -p /workspace
WORKDIR /workspace
