#!/bin/bash
# ============================================================================
# arunlinux - security hardening (safe desktop defaults)
#   Firewall (UFW) + automatic security updates + fail2ban + SSH lockdown.
# Usage: sudo bash scripts/security-harden.sh
# Safe to re-run.
# ============================================================================
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then echo "ERROR: Run as root: sudo bash scripts/security-harden.sh"; exit 1; fi

echo "==> [1/5] Installing security packages..."
apt update || echo "    [WARN] apt update failed - offline? Trying with cached lists."
apt install -y ufw fail2ban unattended-upgrades apt-listchanges 2>/dev/null || \
  apt install -y ufw unattended-upgrades 2>/dev/null || \
  echo "[WARN] Some security packages unavailable on this base - continuing."

echo "==> [2/5] Firewall (UFW: deny incoming, allow outgoing)..."
ufw default deny incoming >/dev/null 2>&1 || true
ufw default allow outgoing >/dev/null 2>&1 || true
# Don't lock out remote admins: if SSH is listening, keep port 22 reachable
if ss -lnt 2>/dev/null | grep -q ':22 ' || systemctl is-active sshd ssh 2>/dev/null | grep -q active; then
  ufw allow 22/tcp >/dev/null 2>&1 || ufw allow OpenSSH >/dev/null 2>&1 || true
  echo "    SSH detected - port 22 left open."
fi
ufw --force enable >/dev/null 2>&1 || echo "    [WARN] ufw enable failed (no netfilter here?)"

echo "==> [3/5] Automatic security updates..."
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -plow unattended-upgrades 2>/dev/null || true
cat > /etc/apt/apt.conf.d/51arunlinux-unattended <<'EOF'
// arunlinux: install security updates automatically, tell the local admin.
Unattended-Upgrade::Origins-Pattern {
  "origin=Debian,codename=${distro_codename},label=Debian-Security";
  "origin=Ubuntu,archive=${distro_codename}-security,label=Ubuntu";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
systemctl enable --now unattended-upgrades 2>/dev/null || true

echo "==> [4/5] fail2ban (brute-force protection)..."
mkdir -p /etc/fail2ban/jail.d
cat > /etc/fail2ban/jail.d/arunlinux.conf <<'EOF'
# arunlinux: protect SSH if it is installed; harmless otherwise.
[sshd]
enabled = true
backend = systemd
maxretry = 5
bantime = 1h
EOF
systemctl enable --now fail2ban 2>/dev/null || echo "    [WARN] fail2ban failed to start."

echo "==> [5/5] SSH daemon lockdown (if installed)..."
if [ -f /etc/ssh/sshd_config ]; then
  # Root login over SSH: disabled. (Password auth untouched - we never lock you out.)
  if grep -qE '^[[:space:]#]*PermitRootLogin' /etc/ssh/sshd_config; then
    sed -i 's/^[[:space:]#]*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  else
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config
  fi
  if sshd -t 2>/dev/null; then
    systemctl reload ssh sshd 2>/dev/null || true
  else
    echo "    [WARN] sshd config test failed - change NOT applied, check /etc/ssh/sshd_config"
  fi
else
  echo "    No SSH server installed - skipping."
fi

# Re-apply our sysctl hardening (installed by kernel-tweak.sh / the ISO hook)
sysctl --system >/dev/null 2>&1 || true

echo ""
echo "--- Security report ---"
echo -n "UFW: "; ufw status 2>/dev/null | head -1 || echo "not available"
echo -n "unattended-upgrades: "; systemctl is-enabled unattended-upgrades 2>/dev/null || echo "not installed"
echo -n "fail2ban: "; systemctl is-active fail2ban 2>/dev/null || echo "not running"
echo -n "ptrace_scope: "; cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || echo "n/a"
echo "[OK] Security hardening complete."
