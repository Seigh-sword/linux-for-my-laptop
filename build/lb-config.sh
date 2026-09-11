#!/bin/bash
# ============================================================================
# arunlinux live-build configuration
# Called by build-iso.sh — you can also run it manually for custom builds:
#     sudo bash build/lb-config.sh trixie amd64 arunlinux x86_64-v1e376dc
# Extra args are passed through to `lb config`. Set LB_CACHE=false to
# disable the on-disk cache (saves gigabytes on CI runners).
# ============================================================================
set -euo pipefail

DEBIAN_DIST="${1:-trixie}"
ARCH="${2:-amd64}"
DISTRO_NAME="${3:-arunlinux}"
VERSION="${4:-1.0}"
shift 4 2>/dev/null || true

LB_CACHE="${LB_CACHE:-true}"

# NOTE (trixie live-build 1:20250505): flags are SINGULAR (--architecture,
# --binary-image), --cache-stages takes stage names (not true/false, dropped),
# and --username/--hostname don't exist (live user comes from --bootappend-live).
lb config noauto \
  --mode debian \
  --system live \
  --architecture "$ARCH" \
  --distribution "$DEBIAN_DIST" \
  --archive-areas "main contrib non-free non-free-firmware" \
  --binary-image iso-hybrid \
  --bootloaders "grub-efi grub-pc" \
  --debian-installer live \
  --debian-installer-distribution "$DEBIAN_DIST" \
  --debian-installer-gui true \
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
  --image-name "live-image" \
  --bootappend-live "boot=live components username=arun hostname=arunlinux quiet splash intel_iommu=on i915.enable_psr=1 i915.enable_fbc=1 zswap.enabled=0" \
  "$@"

echo "[OK] live-build configured for ${DISTRO_NAME} v${VERSION} (${DEBIAN_DIST}/${ARCH})"
