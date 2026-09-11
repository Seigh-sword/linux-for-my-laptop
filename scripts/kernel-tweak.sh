#!/bin/bash
# ============================================================================
# arunlinux - kernel / RAM / GPU tuning for low-RAM laptops
# Applies: zram, sysctl, Intel i915 tweaks, earlyoom, tlp, thermald.
# Safe to re-run.
# ============================================================================
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Applying arunlinux kernel tweaks..."

# --- Packages that make low-RAM machines feel much bigger ---
apt update
apt install -y earlyoom tlp tlp-rdw thermald irqbalance preload \
  intel-microcode mesa-utils vulkan-tools 2>/dev/null || \
  apt install -y earlyoom tlp thermald intel-microcode mesa-utils

# zram backend: prefer systemd generator, fall back to zram-tools
if apt install -y systemd-zram-generator 2>/dev/null; then
  install -Dm644 "$REPO_DIR/kernel/zram/zram-generator.conf" /etc/systemd/zram-generator.conf
  systemctl daemon-reload
  systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || true
else
  apt install -y zram-tools
  install -Dm644 "$REPO_DIR/kernel/zram/zram-swap.default" /etc/default/zramswap
  systemctl restart zramswap 2>/dev/null || service zramswap restart 2>/dev/null || true
fi

# --- sysctl tuning ---
install -Dm644 "$REPO_DIR/kernel/sysctl/99-arunlinux.conf" /etc/sysctl.d/99-arunlinux.conf
sysctl --system >/dev/null 2>&1 || true

# --- Intel iGPU modprobe tweaks + rare-protocol blacklist ---
install -Dm644 "$REPO_DIR/kernel/modprobe/i915.conf" /etc/modprobe.d/i915-arunlinux.conf
install -Dm644 "$REPO_DIR/kernel/modprobe/arunlinux-blacklist.conf" /etc/modprobe.d/arunlinux-blacklist.conf
update-initramfs -u 2>/dev/null || true

# --- earlyoom (freeze protection) ---
if [ -f "$REPO_DIR/kernel/earlyoom/earlyoom.default" ]; then
  install -Dm644 "$REPO_DIR/kernel/earlyoom/earlyoom.default" /etc/default/earlyoom
fi
systemctl enable --now earlyoom 2>/dev/null || true

# --- Laptop power services ---
systemctl enable --now tlp 2>/dev/null || true
systemctl enable --now thermald 2>/dev/null || true
systemctl enable --now irqbalance 2>/dev/null || true

# --- GRUB cmdline (append ours if missing) ---
if [ -f /etc/default/grub ]; then
  # Some installs lack the CMDLINE line entirely - create it so flags below stick
  grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub || \
    echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"' >> /etc/default/grub
  for flag in "intel_iommu=on" "i915.enable_psr=1" "i915.enable_fbc=1" "zswap.enabled=0" "nowatchdog"; do
    grep -q "$flag" /etc/default/grub || \
      sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$flag /" /etc/default/grub
  done
  update-grub 2>/dev/null || true
fi

echo "--- Status ---"
echo -n "zram: "; (zramctl 2>/dev/null || swapon --show 2>/dev/null) | head -5
echo -n "swappiness: "; cat /proc/sys/vm/swappiness
echo "[OK] Kernel tweaks applied (some need a REBOOT)."
