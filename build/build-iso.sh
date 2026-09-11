#!/bin/bash
# ============================================================================
# arunlinux ISO factory — main build script (Debian live-build)
# ----------------------------------------------------------------------------
# Run from the repo root on a Debian Stable host with ~20 GB free, as root:
#     sudo bash build/build-iso.sh
# Output: out/arunlinux-x86_64-v<commit>.hybrid.iso
#   - x86_64 = Intel/AMD 64-bit (Debian calls it "amd64" internally)
#   - <commit> = short git SHA this ISO was built from (or VERSION= override)
# ============================================================================
set -euo pipefail

VERSION="${VERSION:-$(git rev-parse --short HEAD 2>/dev/null || echo 1.0)}"
# Normalize a full 40-char commit SHA to its short form for filenames
if [[ "$VERSION" =~ ^[0-9a-f]{40}$ ]]; then VERSION="${VERSION:0:7}"; fi
DISTRO_NAME="arunlinux"
ARCH="amd64"                  # Debian arch name ("amd64" == x86_64 Intel/AMD 64-bit)
DEBIAN_DIST="trixie"          # Debian Stable
WORKDIR="$(pwd)/iso-build"
OUTDIR="$(pwd)/out"

# Public arch label for filenames: x86_64 (not amd64)
case "$ARCH" in
  amd64) ARCH_LABEL="x86_64" ;;
  i386)  ARCH_LABEL="i386" ;;
  arm64) ARCH_LABEL="aarch64" ;;
  *)     ARCH_LABEL="$ARCH" ;;
esac
FULLVER="${ARCH_LABEL}-v${VERSION}"

echo "=============================================="
echo "  🐧 Building ${DISTRO_NAME} ${FULLVER}"
echo "  Base: Debian ${DEBIAN_DIST} (${ARCH} = ${ARCH_LABEL})"
echo "=============================================="

# --- 0. Sanity checks --------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ Please run as root: sudo bash build/build-iso.sh"
  exit 1
fi
if [ ! -f build/lb-config.sh ]; then
  echo "❌ Run from the repo root: sudo bash build/build-iso.sh"
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
cp -r build/lb-config.sh build/package-lists build/hooks build/includes.installer "$WORKDIR/" 2>/dev/null || true
# Copy our scripts/apps/kernel tweaks into the build so hooks can use them
mkdir -p "$WORKDIR/arun-src"
cp -r scripts apps kernel assets "$WORKDIR/arun-src/"
echo "$FULLVER" > "$WORKDIR/arun-src/VERSION"

cd "$WORKDIR"

# --- 2. Configure live-build --------------------------------------------------
echo "⚙️  Configuring live-build..."
bash lb-config.sh "$DEBIAN_DIST" "$ARCH" "$DISTRO_NAME" "$FULLVER"

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
ISO_DST="${OUTDIR}/${DISTRO_NAME}-${FULLVER}.hybrid.iso"
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
