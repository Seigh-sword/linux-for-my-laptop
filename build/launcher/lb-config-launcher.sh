#!/bin/bash
# ============================================================================
# arunlinux LAUNCHER live-build configuration (minimal console installer ISO)
# Called by build/build-launcher.sh. No desktop, no installer packages:
# just debootstrap + partitioning + network + dialogs + our launcher.
# Extra args are passed through to `lb config`. Set LB_CACHE=false on CI.
# ============================================================================
set -euo pipefail

DEBIAN_DIST="${1:-trixie}"
ARCH="${2:-amd64}"
DISTRO_NAME="${3:-arunlinux-launcher}"
VERSION="${4:-1.0}"
shift 4 2>/dev/null || true

LB_CACHE="${LB_CACHE:-true}"

# NOTE: no --debian-installer flag at all (default = none; WE are the
# installer). No --username/--hostname (trixie live-build lacks them).
lb config noauto \
  --mode debian \
  --system live \
  --architecture "$ARCH" \
  --distribution "$DEBIAN_DIST" \
  --archive-areas "main contrib non-free non-free-firmware" \
  --binary-image iso-hybrid \
  --bootloaders "grub-efi grub-pc" \
  --debootstrap-options "--variant=minbase" \
  --apt-recommends false \
  --apt-secure true \
  --backports true \
  --security true \
  --updates true \
  --firmware-binary true \
  --firmware-chroot true \
  --source false \
  --cache "$LB_CACHE" \
  --cache-indices "$LB_CACHE" \
  --cache-packages "$LB_CACHE" \
  --iso-publisher "arunlinux" \
  --iso-volume "${DISTRO_NAME}-${VERSION}" \
  --iso-application "${DISTRO_NAME} ${VERSION}" \
  --image-name "arun-launcher" \
  --bootappend-live "boot=live components quiet" \
  "$@"

echo "[OK] live-build configured for ${DISTRO_NAME} v${VERSION} (${DEBIAN_DIST}/${ARCH})"
