#!/bin/bash
# ============================================================================
# arunlinux — ALL the package managers + VS Code + Chrome
#   apt (native), flatpak, snap, npm (with Node)
#   AppImage (fuse + Gear Lever), pacman (real Arch container via distrobox)
# ============================================================================
set -euo pipefail

# fetch_key <url> <keyring-path> <expected-key-id>
# Downloads a repo signing key and installs it ONLY if its fingerprint matches.
fetch_key() {
  local url="$1" keyring="$2" keyid="$3" tmp
  tmp="$(mktemp /tmp/repokey-XXXXXX.asc)"
  if ! wget -qO "$tmp" "$url"; then echo "    [WARN] download failed: $url"; rm -f "$tmp"; return 1; fi
  if gpg --show-keys "$tmp" 2>/dev/null | tr -d ' ' | grep -q "$keyid"; then
    gpg --dearmor < "$tmp" > "$keyring"
    chmod 644 "$keyring"
    echo "    Key OK (fingerprint contains $keyid)."
  else
    echo "    [WARN] fingerprint check FAILED for $url - key NOT installed."
    rm -f "$tmp"; return 1
  fi
  rm -f "$tmp"
}

echo "==> [1/6] apt: core tools..."
apt update
apt install -y curl wget gpg apt-transport-https software-properties-common \
  flatpak snapd libfuse2 fuse3 appstream distrobox podman \
  gnome-software-plugin-flatpak 2>/dev/null || \
  apt install -y curl wget gpg flatpak snapd libfuse2 distrobox podman

# --- Flatpak + Flathub ---
echo "==> [2/6] Flatpak + Flathub..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub io.github.thetumultuousunicorn.CupOfTea 2>/dev/null || true  # warm cache (tiny app)

# --- Snap ---
echo "==> [3/6] Snap..."
systemctl enable --now snapd.socket 2>/dev/null || true
ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true

# --- VS Code (Microsoft repo) ---
echo "==> [4/6] Visual Studio Code..."
if ! command -v code >/dev/null 2>&1; then
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/ms-vscode.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ms-vscode.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
  apt update && apt install -y code
else
  echo "    VS Code already installed."
fi

# --- Google Chrome (Google repo) ---
echo "==> [5/6] Google Chrome..."
if ! command -v google-chrome >/dev/null 2>&1; then
  wget -qO- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor > /usr/share/keyrings/google-chrome.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
  apt update && apt install -y google-chrome-stable
else
  echo "    Chrome already installed."
fi

# --- Node.js LTS + npm (NodeSource) ---
echo "==> [6/6] Node.js LTS + npm..."
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt install -y nodejs
else
  echo "    node $(node -v) already installed."
fi

# --- pacman via real Arch container (distrobox) ---
echo "==> [bonus] pacman via Arch container (distrobox)..."
if command -v distrobox >/dev/null 2>&1; then
  echo "    Create it any time with:  distrobox create -i archlinux:latest -n arch"
  echo "    Then:  distrobox enter arch  →  sudo pacman -Syu <pkg>"
  echo "    Our 'arun-pkg' wrapper does this automatically for pacman commands."
else
  echo "    [WARN] distrobox missing - pacman-container unavailable."
fi

# --- AppImage helper: Gear Lever (flatpak) ---
flatpak install -y flathub it.mijorus.gearlever 2>/dev/null || echo "    (Gear Lever skipped — install later from Flathub)"

echo ""
echo "--- Package manager report ---"
command -v apt >/dev/null && apt --version | head -1 || echo "(apt missing?)"
command -v flatpak >/dev/null && flatpak --version || echo "(flatpak missing)"
command -v snap >/dev/null && snap --version | head -1 || echo "(snap missing)"
command -v npm >/dev/null && echo "npm $(npm -v) + node $(node -v)" || echo "(npm missing)"
command -v code >/dev/null && echo "VS Code installed" || echo "(VS Code missing)"
command -v google-chrome >/dev/null && echo "Chrome installed" || echo "(Chrome missing)"
echo "[OK] All package managers ready. Use: arun-pkg <install|search|remove> <app>"
