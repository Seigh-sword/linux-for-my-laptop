#!/bin/bash
# ============================================================================
# arunlinux — ArunDE Fusion desktop: install XFCE core + LXQt light apps,
# remove heavy/bloated stuff. Idempotent — safe to re-run.
# ============================================================================
set -euo pipefail

echo "==> Installing ArunDE Fusion desktop..."

# --- Enable contrib/non-free/firmware repos (Debian) ---
if grep -qi debian /etc/os-release; then
  apt install -y software-properties-common 2>/dev/null || true
  add-apt-repository -y contrib 2>/dev/null || true
  add-apt-repository -y non-free 2>/dev/null || true
  add-apt-repository -y non-free-firmware 2>/dev/null || true
  # Debian 12+ uses deb822 .sources files — patch them too
  for f in /etc/apt/sources.list.d/*.sources /etc/apt/sources.list; do
    [ -f "$f" ] || continue
    grep -q "non-free-firmware" "$f" 2>/dev/null || \
      sed -i 's/Components: main/Components: main contrib non-free non-free-firmware/' "$f" 2>/dev/null || \
      sed -i 's/ main$/ main contrib non-free non-free-firmware/' "$f" 2>/dev/null || true
  done
  apt update
fi

# --- XFCE core (the stable, pretty base) ---
apt install -y --no-install-recommends \
  xorg lightdm lightdm-gtk-greeter \
  xfce4-session xfwm4 xfce4-panel xfce4-settings xfce4-power-manager \
  xfce4-screenshooter xfce4-taskmanager xfce4-terminal xfce4-whiskermenu-plugin \
  thunar thunar-archive-plugin thunar-volman tumbler \
  gvfs gvfs-backends udisks2 policykit-1 polkitd-pkla \
  network-manager network-manager-gnome pavucontrol pasystray \
  arc-theme papirus-icon-theme plank \
  fonts-dejavu fonts-liberation fonts-noto fonts-noto-color-emoji \
  fonts-firacode fonts-jetbrains-mono \
  firefox-esr mousepad galculator file-roller evince \
  blueman bluez pulseaudio pulseaudio-module-bluetooth alsa-utils \
  upower acpi cups cups-filters system-config-printer \
  baobab gnome-disk-utility gparted

# Ubuntu calls it firefox (snap); Debian calls it firefox-esr — cover both
apt install -y firefox 2>/dev/null || true

# --- LXQt light apps (the "fusion"): lighter than XFCE equivalents ---
apt install -y --no-install-recommends \
  qterminal lxqt-runner featherpad lximage-qt \
  lxqt-notificationd lxqt-policykit openbox obconf-qt 2>/dev/null || \
  echo "⚠️  Some LXQt packages unavailable on this base — continuing."

# --- arunlinux apps runtime: YAD dialogs + ImageMagick (wallpaper thumbs) ---
# Our apps are pure Bash + YAD — no Python GUI stack needed.
apt install -y --no-install-recommends yad imagemagick

# --- REMOVE bloat: heavy GNOME bits, extra XFCE toys, games, python-tk ---
apt purge -y --autoremove \
  parole ristretto xfce4-dict xfce4-notes gigolo orage xfburn \
  gnome-shell gnome-session gnome-control-center gnome-software \
  gnome-music gnome-videos totem rhythmbox shotwell \
  aisleriot gnome-mines gnome-sudoku gnome-mahjongg \
  python3-tk \
  thunderbird* 2>/dev/null || true
apt autoremove -y && apt autoclean

# --- Make LightDM the display manager ---
echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt install -y lightdm 2>/dev/null || true

echo "✅ ArunDE Fusion desktop done."
