#!/bin/bash
# ============================================================================
# arunlinux LAUNCHER factory - minimal console installer ISO (netinstall)
# ----------------------------------------------------------------------------
# Run from the repo root on a Debian Stable host with ~10 GB free, as root:
#     sudo bash build/build-launcher.sh
# Output: out/arunlinux-launcher-x86_64-v<commit>.hybrid.iso
# Much smaller than the full ISO: no desktop, just the installer.
# ============================================================================
set -euo pipefail

VERSION="${VERSION:-$(git rev-parse --short HEAD 2>/dev/null || echo 1.0)}"
if [[ "$VERSION" =~ ^[0-9a-f]{40}$ ]]; then VERSION="${VERSION:0:7}"; fi
DISTRO_NAME="arunlinux-launcher"
ARCH="amd64"
DEBIAN_DIST="trixie"
WORKDIR="$(pwd)/iso-launcher-build"
OUTDIR="$(pwd)/out"

case "$ARCH" in
  amd64) ARCH_LABEL="x86_64" ;;
  i386)  ARCH_LABEL="i386" ;;
  arm64) ARCH_LABEL="aarch64" ;;
  *)     ARCH_LABEL="$ARCH" ;;
esac
FULLVER="${ARCH_LABEL}-v${VERSION}"

echo "=============================================="
echo "  Building ${DISTRO_NAME} ${FULLVER}"
echo "  Base: Debian ${DEBIAN_DIST} (${ARCH} = ${ARCH_LABEL})"
echo "=============================================="

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: Please run as root: sudo bash build/build-launcher.sh"
  exit 1
fi
if [ ! -f build/launcher/lb-config-launcher.sh ]; then
  echo "ERROR: Run from the repo root: sudo bash build/build-launcher.sh"
  exit 1
fi
if ! command -v lb >/dev/null 2>&1; then
  echo "Installing live-build..."
  apt update && apt install -y live-build debootstrap cdebootstrap \
    squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin \
    mtools dosfstools parted curl git
fi

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR" "$OUTDIR"
cp build/launcher/lb-config-launcher.sh "$WORKDIR/"
mkdir -p "$WORKDIR/package-lists" "$WORKDIR/hooks"
cp build/launcher/*.list.chroot "$WORKDIR/package-lists/"
cp build/launcher/*.hook.chroot "$WORKDIR/hooks/"
# Launcher payload: installer scripts + .var lib + tools + accounts app
mkdir -p "$WORKDIR/arun-src"
cp -r launcher lib tools "$WORKDIR/arun-src/"
mkdir -p "$WORKDIR/arun-src/apps"
cp -r apps/arun-accounts "$WORKDIR/arun-src/apps/"
echo "$FULLVER" > "$WORKDIR/arun-src/VERSION"

cd "$WORKDIR"

echo "Configuring live-build..."
bash lb-config-launcher.sh "$DEBIAN_DIST" "$ARCH" "$DISTRO_NAME" "$FULLVER"

echo "Installing launcher customizations into config/..."
mkdir -p config/package-lists config/hooks/live config/includes.chroot
cp package-lists/*.list.chroot config/package-lists/
cp hooks/*.hook.chroot config/hooks/live/
cp -r arun-src config/includes.chroot/arun-src
chmod +x config/hooks/live/* 2>/dev/null || true
echo "   package lists: $(ls config/package-lists/ | tr '\n' ' ')"
echo "   hooks: $(ls config/hooks/live/ | tr '\n' ' ')"

echo "Building launcher ISO (this takes 10-30 minutes)..."
lb build

ISO_SRC="arun-launcher-${ARCH}.hybrid.iso"
if [ ! -f "$ISO_SRC" ]; then
  ISO_SRC="$(ls -t *.hybrid.iso *.iso 2>/dev/null | head -1)"
fi
ISO_DST="${OUTDIR}/${DISTRO_NAME}-${FULLVER}.hybrid.iso"
if [ -f "$ISO_SRC" ]; then
  mv "$ISO_SRC" "$ISO_DST"
  ( sha256sum "$ISO_DST" > "${ISO_DST}.sha256" )
  echo ""
  echo "=============================================="
  echo "  DONE: $ISO_DST"
  echo "  Size: $(du -h "$ISO_DST" | cut -f1)"
  echo "  Flash it with: sudo dd if=$ISO_DST of=/dev/sdX bs=4M status=progress"
  echo "  (replace /dev/sdX with your USB stick!)"
  echo "=============================================="
else
  echo "ERROR: Build failed - no ISO produced. Check the log above."
  exit 1
fi
