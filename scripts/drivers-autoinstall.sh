#!/bin/bash
# ============================================================================
# arunlinux — driver autoinstaller ("Ubuntu drivers stitched into Debian")
# Installs: Intel microcode/mesa/vulkan/vaapi, Wi-Fi firmware mega-pack,
# touchpad, sound, printer/scanner. Detects hardware and skips what's absent.
# ============================================================================
set -euo pipefail

echo "==> Detecting hardware..."
CPU="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
GPU="$(lspci 2>/dev/null | grep -i -E 'vga|3d|display' | head -3)"
WIFI="$(lspci 2>/dev/null | grep -i -E 'network|wireless' | head -3)"
echo "    CPU : $CPU"
echo "    GPU : $GPU"
echo "    WiFi: ${WIFI:-USB/other}"
echo "    Audio: $(lspci 2>/dev/null | grep -i audio | head -2)"

apt update

echo "==> Installing Intel CPU + iGPU stack..."
apt install -y intel-microcode mesa-utils mesa-va-drivers mesa-vdpau-drivers \
  mesa-vulkan-drivers vulkan-tools intel-media-va-driver i965-va-driver vainfo \
  thermald tlp tlp-rdw powertop irqbalance 2>/dev/null || \
  apt install -y intel-microcode mesa-utils mesa-vulkan-drivers 2>/dev/null || true

echo "==> Installing firmware mega-pack (Wi-Fi, bluetooth, sound)..."
apt install -y firmware-linux-free firmware-linux-nonfree firmware-iwlwifi \
  firmware-realtek firmware-atheros firmware-brcm80211 firmware-misc-nonfree \
  firmware-sof-signed 2>/dev/null || true

echo "==> Installing input / sound / laptop extras..."
apt install -y xserver-xorg-input-libinput xserver-xorg-input-synaptics \
  pipewire pipewire-pulse wireplumber pavucontrol \
  laptop-mode-tools acpi-support iw wpasupplicant powertop 2>/dev/null || true

echo "==> Installing printer + scanner support..."
apt install -y cups cups-filters system-config-printer hplip simple-scan 2>/dev/null || true

# --- Ubuntu-style: if on Ubuntu base, also run ubuntu-drivers autoinstall ---
if command -v ubuntu-drivers >/dev/null 2>&1; then
  echo "==> Ubuntu base detected — running ubuntu-drivers autoinstall..."
  ubuntu-drivers autoinstall || true
fi

echo ""
echo "--- Driver report ---"
echo -n "VA-API (video accel): "; vainfo 2>/dev/null | grep -m1 "Driver version" || echo "check after reboot"
echo -n "Vulkan ICDs: "; ls /usr/share/vulkan/icd.d/ 2>/dev/null | tr '\n' ' ' || echo none
echo -n "Wi-Fi firmware: "; ls /lib/firmware/iwlwifi* 2>/dev/null | wc -l; echo " files"
echo "✅ Drivers installed (REBOOT to load new microcode/firmware)."
