#!/bin/bash
# Build the rust-stable binary packages (.deb), one set for every suite.
# Nothing is compiled (upstream's official toolchain is repackaged), so the
# per-suite builds would only differ in their version suffix. The fixed
# ~gaofn tag replaces the suite.
#
# Produces, in ./out :
#   rust-stable_<ver>-<build>~gaofn_<arch>.deb                       (amd64, arm64)
#   rust-stable-std-musl_<ver>-<build>~gaofn_<arch>.deb              (amd64, arm64)
#   rust-stable-src_<ver>-<build>~gaofn_all.deb
#   rust-stable-doc_<ver>-<build>~gaofn_all.deb
#   rust-stable-std-wasm32-unknown-unknown_<ver>-<build>~gaofn_all.deb
#   rust-stable-std-wasm32-wasip1_<ver>-<build>~gaofn_all.deb
#   rust-stable-std-wasm32-wasip2_<ver>-<build>~gaofn_all.deb
#
# The arch:all packages are built once, by the first architecture of the run.
# Set SKIP_ARCH_ALL=1 to never build them (CI does this for the arm64 job,
# whose amd64 sibling already produces them).
#
# Usage: ./build_debian.sh <rust_version> <build_version> [amd64|arm64|all]
set -euo pipefail

VERSION="${1:-}"
BUILD="${2:-}"
ARCH="${3:-all}"
if [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
    echo "Usage: $0 <rust_version> <build_version> [amd64|arm64|all]" >&2
    echo "Example: $0 1.100.0 1 all" >&2
    exit 1
fi

FULL_VERSION="${VERSION}-${BUILD}~gaofn"

case "$ARCH" in
    all)   ARCHES=("amd64" "arm64") ;;
    amd64|arm64) ARCHES=("$ARCH") ;;
    *) echo "❌ Unsupported architecture: $ARCH (rust-stable ships amd64 and arm64)" >&2; exit 1 ;;
esac

mkdir -p out

BUILD_TYPE="-b"
[ "${SKIP_ARCH_ALL:-}" = "1" ] && BUILD_TYPE="-B"

# Generate the changelog (overwrites the placeholder).
cat > debian/changelog << EOC
rust-stable (${FULL_VERSION}) stable; urgency=medium

  * New upstream release ${VERSION}.

 -- Fengnan Gao <gao.fengnan@gmail.com>  $(date -R)
EOC

for arch in "${ARCHES[@]}"; do
    echo "==> Building rust-stable ${FULL_VERSION} (${arch}, dpkg-buildpackage ${BUILD_TYPE})"

    docker build -t "rust-stable-${arch}" \
        --build-arg "ARCH=${arch}" \
        --build-arg "BUILD_TYPE=${BUILD_TYPE}" \
        -f Dockerfile .

    cid="$(docker create "rust-stable-${arch}")"
    docker cp "${cid}:/out/." ./out/
    docker rm "${cid}" > /dev/null

    # Later architectures in this run only need the arch-dependent packages
    BUILD_TYPE="-B"
done

echo ""
echo "Built packages:"
ls -la out/rust-stable*.deb
