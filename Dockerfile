# Use Ubuntu 20.04 as the base image
FROM ubuntu:20.04

# Set arguments for building
ARG ARCH
ARG CHIP
ARG QEMU

# Set environment variables for running
ENV ARCH=${ARCH}
ENV DEBIAN_FRONTEND=interactive
ENV CHIP=${CHIP}
ENV QEMU=${QEMU}

# Update and install prerequisites
RUN apt update && \
    apt install -y \
        build-essential \
        debootstrap \
        binfmt-support \
        qemu-user-static && \
    apt autoremove -y && \
    apt clean

# Create and initialize chroot environment with qemu-debootstrap
RUN qemu-debootstrap --arch ${ARCH} buster /mnt/data/${ARCH} http://deb.debian.org/debian/

# Copy qemu static to chroot for architecture emulation
RUN cp /usr/bin/qemu-${QEMU}-static /mnt/data/${ARCH}/usr/bin/

# Install additional packages within the chroot environment
RUN chroot /mnt/data/${ARCH} /bin/bash -c "\
    apt update && \
    apt install -y \
        build-essential \
        git \
        wget \
        libdrm-dev \
        python3 \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        ninja-build \
        libopenal-dev \
        premake4 \
        autoconf \
        libevdev-dev \
        ffmpeg \
        libsnappy-dev \
        libboost-tools-dev \
        magics++ \
        libboost-thread-dev \
        libboost-all-dev \
        pkg-config \
        zlib1g-dev \
        libpng-dev \
        libsdl2-dev \
        clang \
        cmake \
        cmake-data \
        libarchive13 \
        libcurl4 \
        libfreetype6-dev \
        libjsoncpp1 \
        librhash0 \
        libuv1 \
        mercurial \
        libgbm-dev \
        libsdl2-ttf-2.0-0 \
        libsdl2-ttf-dev && \
    apt autoremove -y && \
    apt clean && \
    ln -s /usr/include/libdrm /usr/include/drm"

# Install, clone and set up Meson in the chroot
RUN chroot /mnt/data/${ARCH} /bin/bash -c "\
    pip3 install meson && \
    git clone https://github.com/mesonbuild/meson.git && \
    ln -s /meson/meson.py /usr/bin/meson"

# Clone libgo2 and copy headers within the chroot
RUN chroot /mnt/data/${ARCH} /bin/bash -c "\
    git clone https://github.com/OtherCrashOverride/libgo2.git && \
    mkdir -p /usr/include/go2 && \
    cp libgo2/src/*.h /usr/include/go2/"

# Clone core_builds repository within the chroot
RUN chroot /mnt/data/${ARCH} /bin/bash -c "\
    git clone https://github.com/Akira8484/rk3566_core_builds.git

# Add a script to run build.sh and copy the output
RUN echo '#!/bin/bash\n\
cd /mnt/data/${ARCH}/${CHIP}_core_builds\n\
ls . > /tmp/first_ls.txt\n\
chroot /mnt/data/${ARCH} /bin/bash -c "cd ${CHIP}_core_builds && ./builds.sh $1"\n\
ls . > /tmp/second_ls.txt\n\
comm -13 <(sort /tmp/first_ls.txt) <(sort /tmp/second_ls.txt) > /tmp/changes.txt\n\
mkdir -p /mnt/host/${CHIP}_core_builds\n\
while IFS= read -r item; \
do [[ -d "./${item}" ]] && [[ ! -d "./${item}/.git" ]] && cp -r "./${item}" /mnt/host/${CHIP}_core_builds; \
done < /tmp/changes.txt' > /run_builds.sh

# Make the script executable
RUN chmod +x /run_builds.sh

# Set the entrypoint to the script
ENTRYPOINT ["/run_builds.sh"]
