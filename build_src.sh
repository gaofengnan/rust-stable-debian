#!/bin/bash
# Build the *source* package (.dsc + .orig.tar.gz + .debian.tar.xz), one for
# every suite, for upload to deb.griffo.io.
#
# The shipped payload is upstream's official toolchain, fetched by
# debian/rules at build time, so the .orig tarball is what pins it: the
# signed release manifest (channel-rust-<ver>.toml + .asc, which lists the
# SHA-256 of every component tarball) and upstream's licence files at the
# <ver> tag. Rebuilding from this source package produces the same bits.
#
# Usage: ./build_src.sh <rust_version> <build_version>
set -euo pipefail

VERSION="${1:-}"
BUILD="${2:-}"
if [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
    echo "Usage: $0 <rust_version> <build_version>" >&2
    echo "Example: $0 1.100.0 1" >&2
    exit 1
fi

PACKAGE_NAME="rust-stable"
ORIG_TARBALL="${PACKAGE_NAME}_${VERSION}.orig.tar.gz"
BUILD_DIR="${PACKAGE_NAME}-${VERSION}"
MANIFEST="channel-rust-${VERSION}.toml"

# A rebuild of an upstream version already released here (a +N build bump)
# must ship the very same orig tarball: the pool holds one per upstream
# version and reprepro refuses a different one. Reuse the earlier release's copy.
if [ ! -f "$ORIG_TARBALL" ]; then
    for ((b = BUILD - 1; b >= 1; b--)); do
        if wget -q "https://github.com/dariogriffo/rust-stable-debian/releases/download/${VERSION}%2B${b}/${ORIG_TARBALL}" -O "$ORIG_TARBALL"; then
            echo "  Reusing $ORIG_TARBALL from release ${VERSION}+${b}"
            break
        fi
        rm -f "$ORIG_TARBALL"
    done
fi

if [ ! -f "$ORIG_TARBALL" ]; then
    echo "Assembling $ORIG_TARBALL..."
    rm -rf "$BUILD_DIR"
    mkdir "$BUILD_DIR"
    wget -q "https://static.rust-lang.org/dist/${MANIFEST}" -O "$BUILD_DIR/${MANIFEST}"
    wget -q "https://static.rust-lang.org/dist/${MANIFEST}.asc" -O "$BUILD_DIR/${MANIFEST}.asc"
    for f in COPYRIGHT LICENSE-APACHE LICENSE-MIT README.md; do
        wget -q "https://raw.githubusercontent.com/rust-lang/rust/${VERSION}/${f}" -O "$BUILD_DIR/${f}"
    done
    # Reproducible tarball: fixed order, owner and mtime
    tar --sort=name --owner=0 --group=0 --numeric-owner \
        --mtime="@$(date -d "$(grep -m1 '^date = ' "$BUILD_DIR/${MANIFEST}" | cut -d'"' -f2)" +%s)" \
        -cf - "$BUILD_DIR" | gzip -n -9 > "$ORIG_TARBALL"
    rm -rf "$BUILD_DIR"
    echo "  Saved as $ORIG_TARBALL"
else
    echo "  Using existing $ORIG_TARBALL"
fi

build_source_package() {
    local FULL_VERSION="${VERSION}-${BUILD}~griffo"
    echo "  Building source package ${FULL_VERSION}..."

    rm -rf "$BUILD_DIR"
    tar -xf "$ORIG_TARBALL"
    cp -r debian "$BUILD_DIR/"

    cat > "$BUILD_DIR/debian/changelog" << EOC
rust-stable (${FULL_VERSION}) stable; urgency=medium

  * New upstream release ${VERSION}.

 -- Dario Griffo <dariogriffo@gmail.com>  $(date -R)
EOC

    dpkg-source -b "$BUILD_DIR"
    rm -rf "$BUILD_DIR"
}

echo ""
# One source package for every suite, as with the binaries (see build_debian.sh).
build_source_package

echo ""
echo "Source package created:"
ls -la "${PACKAGE_NAME}_"*.dsc "${PACKAGE_NAME}_"*.orig.tar.gz "${PACKAGE_NAME}_"*.debian.tar.xz 2>/dev/null || true
