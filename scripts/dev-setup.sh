#!/bin/bash
# ============================================================================
# arunlinux — developer stack
#   C/C++ ✅  Rust ✅  Go ✅  Node ✅  Java ✅  Kotlin ✅
# Usage: sudo bash scripts/dev-setup.sh [username]
# ============================================================================
set -euo pipefail
TARGET_USER="${1:-${SUDO_USER:-$USER}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
as_user() { sudo -u "$TARGET_USER" bash -c "$*"; }

echo "==> Dev stack for user: $TARGET_USER ($TARGET_HOME)"

# --- C / C++ ---
echo "==> [1/6] C/C++ toolchain..."
apt update
apt install -y build-essential clang clang-format cmake ninja-build gdb \
  pkg-config valgrind manpages-dev git curl wget unzip zip neovim tmux \
  htop tree jq shellcheck 2>/dev/null || apt install -y build-essential clang cmake gdb git

# --- Rust (rustup, per-user) ---
echo "==> [2/6] Rust (rustup)..."
if ! as_user 'command -v rustc >/dev/null'; then
  as_user 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal'
  as_user '$HOME/.cargo/bin/rustup component add rustfmt clippy rust-analyzer 2>/dev/null || true'
else
  echo "    rustc $(as_user '$HOME/.cargo/bin/rustc -V' 2>/dev/null || rustc -V) already installed."
fi

# --- Go (official tarball, latest stable) ---
echo "==> [3/6] Go..."
if ! command -v go >/dev/null 2>&1; then
  GO_VER="$(curl -fsSL https://go.dev/VERSION?m=text | head -1)"
  curl -fsSL "https://go.dev/dl/${GO_VER}.linux-amd64.tar.gz" -o /tmp/go.tgz
  rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tgz && rm /tmp/go.tgz
  ln -sf /usr/local/go/bin/go /usr/local/bin/go
  ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
else
  echo "    $(go version) already installed."
fi

# --- Node.js (if pkgmanagers-setup.sh didn't run yet) ---
echo "==> [4/6] Node.js + npm..."
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt install -y nodejs
fi
echo "    node $(node -v), npm $(npm -v)"
# Useful global tools (light ones)
npm install -g --silent yarn pnpm typescript 2>/dev/null || echo "    (global npm tools skipped — offline?)"

# --- Java (OpenJDK 17 + Maven + Gradle) ---
echo "==> [5/6] Java..."
apt install -y openjdk-17-jdk maven gradle 2>/dev/null || apt install -y openjdk-17-jdk
echo "    $(java -version 2>&1 | head -1)"

# --- Kotlin (via SDKMAN, per-user — always latest) ---
echo "==> [6/6] Kotlin (sdkman)..."
if ! as_user 'command -v kotlinc >/dev/null'; then
  as_user 'curl -s https://get.sdkman.io | bash'
  as_user 'source $HOME/.sdkman/bin/sdkman-init.sh && sdk install kotlin && sdk install gradle 2>/dev/null || true'
else
  echo "    kotlinc already installed."
fi

# --- Shell niceties for the user ---
PROFILE_D="/etc/profile.d/arunlinux-dev.sh"
cat > "$PROFILE_D" <<'EOF'
# arunlinux dev paths
export PATH="$HOME/.cargo/bin:$HOME/go/bin:$HOME/.local/bin:/usr/local/go/bin:$PATH"
export GOPATH="$HOME/go"
EOF
chmod +x "$PROFILE_D"

echo ""
echo "--- Dev stack report ---"
echo -n "C/C++ : "; gcc --version | head -1
echo -n "Rust  : "; as_user '$HOME/.cargo/bin/rustc -V 2>/dev/null || echo missing'
echo -n "Go    : "; go version 2>/dev/null || echo missing
echo -n "Node  : "; node -v 2>/dev/null; echo -n "npm   : "; npm -v 2>/dev/null
echo -n "Java  : "; java -version 2>&1 | head -1
echo -n "Kotlin: "; as_user 'source $HOME/.sdkman/bin/sdkman-init.sh >/dev/null 2>&1; kotlinc -version 2>&1 | head -1 || echo missing (open a new terminal)'
echo "✅ Dev stack complete. Open a NEW terminal to get all PATHs."
