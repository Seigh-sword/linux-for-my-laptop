#!/bin/bash
# ============================================================================
# 🌟 arunlinux master installer
# Transforms a fresh Debian 13 (trixie) or Ubuntu 24.04 install into arunlinux.
# ----------------------------------------------------------------------------
# Usage:
#   git clone https://github.com/Seigh-sword/linux-for-my-laptop.git
#   cd linux-for-my-laptop
#   sudo bash scripts/install-arunlinux.sh
#
# Safe to re-run. Takes ~30–60 min depending on network.
# ============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG="/tmp/arunlinux-install.log"
STEP=0

log()  { echo -e "\n\033[1;36m[$((++STEP))] $*\033[0m" | tee -a "$LOG"; }
ok()   { echo -e "\033[1;32m    ✅ $*\033[0m" | tee -a "$LOG"; }
warn() { echo -e "\033[1;33m    ⚠️  $*\033[0m" | tee -a "$LOG"; }

if [ "$(id -u)" -ne 0 ]; then echo "❌ Run as root: sudo bash scripts/install-arunlinux.sh"; exit 1; fi
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

echo "🐧 arunlinux master installer — log: $LOG" | tee "$LOG"
echo "   Repo: $REPO_DIR | User: $REAL_USER" | tee -a "$LOG"

# --- Detect base ---------------------------------------------------------------
if [ -f /etc/os-release ]; then . /etc/os-release; fi
echo "   Base OS: ${PRETTY_NAME:-unknown}" | tee -a "$LOG"

# --- 1. Base update -------------------------------------------------------------
log "Updating base system..."
apt update && apt full-upgrade -y
ok "Base updated."

# --- 2. Fusion desktop (XFCE + LXQt, debloated) ----------------------------------
log "Installing ArunDE Fusion desktop (XFCE + LXQt, debloated)..."
bash "$REPO_DIR/scripts/debloat.sh" 2>&1 | tee -a "$LOG"
ok "Desktop installed."

# --- 3. Kernel / RAM / GPU tuning ------------------------------------------------
log "Applying kernel + RAM + Intel GPU tweaks..."
bash "$REPO_DIR/scripts/kernel-tweak.sh" 2>&1 | tee -a "$LOG"
ok "Kernel tweaked."

# --- 4. Drivers (Ubuntu-style autoinstall) ----------------------------------------
log "Installing drivers (Intel + Wi-Fi + firmware mega-pack)..."
bash "$REPO_DIR/scripts/drivers-autoinstall.sh" 2>&1 | tee -a "$LOG"
ok "Drivers installed."

# --- 5. Package managers + VS Code + Chrome ---------------------------------------
log "Setting up package managers (apt/flatpak/snap/npm/AppImage/pacman) + VS Code + Chrome..."
bash "$REPO_DIR/scripts/pkgmanagers-setup.sh" 2>&1 | tee -a "$LOG"
ok "Package managers ready."

# --- 6. Dev stack: Rust, C/C++, Go, Node, Java, Kotlin ------------------------------
log "Installing dev stack (Rust, C/C++, Go, Node, Java, Kotlin)..."
bash "$REPO_DIR/scripts/dev-setup.sh" "$REAL_USER" 2>&1 | tee -a "$LOG"
ok "Dev stack installed."

# --- 7. Wine -----------------------------------------------------------------------
log "Installing Wine + Winetricks..."
bash "$REPO_DIR/scripts/wine-setup.sh" 2>&1 | tee -a "$LOG"
ok "Wine ready."

# --- 8. Custom arunlinux apps + wallpapers -------------------------------------------
log "Installing custom arunlinux apps + wallpapers..."
mkdir -p /usr/share/arunlinux /usr/share/backgrounds/arunlinux
cp -r "$REPO_DIR/apps"/* /usr/share/arunlinux/
cp -r "$REPO_DIR/assets/wallpapers"/* /usr/share/backgrounds/arunlinux/
cp "$REPO_DIR/assets/logo.png" /usr/share/arunlinux/logo.png
ln -sf /usr/share/arunlinux/arun-pkg/arun-pkg /usr/local/bin/arun-pkg
ln -sf /usr/share/arunlinux/arun-optimizer/arun-optimizer /usr/local/bin/arun-optimizer
ln -sf /usr/share/arunlinux/arun-wallpapers/arun-wallpapers /usr/local/bin/arun-wallpapers
ln -sf /usr/share/arunlinux/arun-welcome/arun-welcome /usr/local/bin/arun-welcome
ln -sf /usr/share/arunlinux/arun-drivers/arun-drivers /usr/local/bin/arun-drivers
for app in arun-welcome arun-wallpapers arun-optimizer; do
  [ -f "/usr/share/arunlinux/$app/$app.desktop" ] && \
    ln -sf "/usr/share/arunlinux/$app/$app.desktop" /usr/share/applications/
done
# Welcome app autostart on first login
mkdir -p "/etc/skel/.config/autostart" "$REAL_HOME/.config/autostart"
cp /usr/share/arunlinux/arun-welcome/arun-welcome.desktop /etc/skel/.config/autostart/ 2>/dev/null || true
cp /usr/share/arunlinux/arun-welcome/arun-welcome.desktop "$REAL_HOME/.config/autostart/" 2>/dev/null || true
chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.config" 2>/dev/null || true
ok "Apps + wallpapers installed."

# --- 9. Branding ----------------------------------------------------------------------
log "Branding the system..."
if [ -f /etc/os-release ]; then
  sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="arunlinux 1.0 (Debian-based)"/' /etc/os-release
  grep -q '^NAME=' /etc/os-release && sed -i 's/^NAME=.*/NAME="arunlinux"/' /etc/os-release
fi
ok "This machine is now arunlinux. 🎉"

echo ""
echo "=================================================================="
echo "  🎉 arunlinux installation complete!"
echo "  👉 REBOOT now, then run:  arun-welcome"
echo "  📦 Try: arun-pkg search <app>   |  🖼️  Try: arun-wallpapers"
echo "  📄 Full log: $LOG"
echo "=================================================================="
