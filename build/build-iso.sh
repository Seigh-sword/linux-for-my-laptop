#!/bin/bash
# ============================================================================
# arunlinux ISO factory — main build script (Debian live-build)
# ----------------------------------------------------------------------------
# Run on a Debian Stable host with ~20 GB free, as root:
#     sudo bash build/build-iso.sh
# Output: out/arunlinux-<version>-amd64.hybrid.iso
# ============================================================================
set -euo pipefail

VERSION="${VERSION:-1.0}"
DISTRO_NAME="arunlinux"
ARCH="amd64"
DEBIAN_DIST="trixie"          # Debian Stable
WORKDIR="$(pwd)/iso-build"
OUTDIR="$(pwd)/out"

echo "=============================================="
echo "  🐧 Building ${DISTRO_NAME} v${VERSION}"
echo "  Base: Debian ${DEBIAN_DIST} (${ARCH})"
echo "=============================================="

# --- 0. Sanity checks --------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ Please run as root: sudo bash build/build-iso.sh"
  exit 1
fi
if ! command -v lb >/dev/null 2>&1; then
  echo "📦 Installing live-build..."
  apt update && apt install -y live-build debootstrap cdebootstrap \
    squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin \
    mtools dosfstools parted curl git
fi

# --- 1. Fresh build dir -------------------------------------------------------
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR" "$OUTDIR"
cp -r build/lb-config.sh build/package-lists build/hooks build/includes.chroot \
      build/includes.installer "$WORKDIR/" 2>/dev/null || true
# Copy our scripts/apps/kernel tweaks into the build so hooks can use them
mkdir -p "$WORKDIR/arun-src"
cp -r scripts apps kernel assets "$WORKDIR/arun-src/"

cd "$WORKDIR"

# --- 2. Configure live-build --------------------------------------------------
echo "⚙️  Configuring live-build..."
bash lb-config.sh "$DEBIAN_DIST" "$ARCH" "$DISTRO_NAME" "$VERSION"

# --- 3. Build -----------------------------------------------------------------
echo "🔨 Building ISO (this takes 20–60 minutes)..."
lb build

# --- 4. Collect output --------------------------------------------------------
ISO_SRC="live-image-${ARCH}.hybrid.iso"
ISO_DST="${OUTDIR}/${DISTRO_NAME}-${VERSION}-${ARCH}.hybrid.iso"
if [ -f "$ISO_SRC" ]; then
  mv "$ISO_SRC" "$ISO_DST"
  ( sha256sum "$ISO_DST" > "${ISO_DST}.sha256" )
  echo ""
  echo "=============================================="
  echo "  ✅ DONE: $ISO_DST"
  echo "  Size: $(du -h "$ISO_DST" | cut -f1)"
  echo "  Flash it with: sudo dd if=$ISO_DST of=/dev/sdX bs=4M status=progress"
  echo "  (replace /dev/sdX with your USB stick!)"
  echo "=============================================="
else
  echo "❌ Build failed — no ISO produced. Check the log above."
  exit 1
fi
