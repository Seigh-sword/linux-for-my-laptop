#!/bin/bash
# ============================================================================
# arunlinux — Wine + Winetricks (run Windows apps)
# ============================================================================
set -euo pipefail

echo "==> Setting up Wine..."

dpkg --add-architecture i386
apt update
apt install -y wine64 wine32 winetricks playonlinux dosbox 2>/dev/null || \
  apt install -y wine64 winetricks 2>/dev/null || \
  echo "⚠️  Wine packages unavailable on this base."

# Helpful default: 32-bit prefix libs many apps need
apt install -y libasound2-plugins:i386 libsdl2-2.0-0:i386 2>/dev/null || true

echo ""
wine --version 2>/dev/null || echo "(wine works after first run: run 'winecfg')"
echo "✅ Wine ready. Tip: run 'winetricks corefonts vcrun2019' for best app compat."
echo "   GUI helper: PlayOnLinux. DOS games: DOSBox."
