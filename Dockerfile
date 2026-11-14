FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# Packaging environment, shared by every suite. Nothing is compiled:
# debian/rules downloads the official Rust components, verifies them against
# the Rust release signing key and dpkg-buildpackage assembles the debs.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        debhelper \
        dpkg-dev \
        wget \
        ca-certificates \
        xz-utils \
        gpg \
        gpgv \
    && rm -rf /var/lib/apt/lists/*

# ARCH is the Debian architecture to package (amd64 or arm64). The toolchain
# is only unpacked and copied, never executed, so arm64 is assembled on an
# amd64 builder with dpkg-buildpackage's --host-arch and no emulation.
# BUILD_TYPE is -b (arch-dependent + arch-independent packages) or -B
# (arch-dependent only, for a second architecture when another build already
# produced the arch:all debs).
ARG ARCH=amd64
ARG BUILD_TYPE=-b

WORKDIR /build/rust-stable
COPY debian /build/rust-stable/debian

RUN chmod +x debian/rules && dpkg-buildpackage ${BUILD_TYPE} -us -uc -d -Zxz --host-arch ${ARCH}

RUN mkdir -p /out && cp ../rust-stable*.deb /out/ && chmod 644 /out/*.deb
