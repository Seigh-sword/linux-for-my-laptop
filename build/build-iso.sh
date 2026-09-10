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

# --- 2b. Install our customizations into the live-build config tree -----------
# (lb build ONLY reads config/ — lists, hooks and includes must live there!)
echo "📦 Installing arunlinux customizations into config/..."
mkdir -p config/package-lists config/hooks/live config/hooks/bootstrap \
         config/includes.installer config/includes.chroot
cp package-lists/*.list.chroot config/package-lists/
for d in live bootstrap; do
  if [ -d "hooks/$d" ]; then
    for h in "hooks/$d"/*; do
      [ -f "$h" ] && cp "$h" "config/hooks/$d/"
    done
  fi
done
cp includes.installer/* config/includes.installer/
cp -r arun-src config/includes.chroot/arun-src
chmod +x config/hooks/live/* config/hooks/bootstrap/* 2>/dev/null || true
echo "   package lists: $(ls config/package-lists/ | tr '\n' ' ')"
echo "   hooks: $(ls config/hooks/live/ config/hooks/bootstrap/ 2>/dev/null | tr '\n' ' ')"

# --- 3. Build -----------------------------------------------------------------
echo "🔨 Building ISO (this takes 20–60 minutes)..."
lb build

# --- 4. Collect output --------------------------------------------------------
# live-build names it <image-name>-<arch>.hybrid.iso — but be tolerant in
# case naming varies by live-build version (pick newest ISO-like file).
ISO_SRC="live-image-${ARCH}.hybrid.iso"
if [ ! -f "$ISO_SRC" ]; then
  ISO_SRC="$(ls -t *.hybrid.iso *.iso 2>/dev/null | head -1)"
fi
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
