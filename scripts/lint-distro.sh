#!/bin/bash
# ============================================================================
# arunlinux pre-build linter — catches ISO build failures in ~2 minutes
# instead of ~40. Run locally or in CI (debian:trixie container, as root):
#   bash scripts/lint-distro.sh
# Checks: shell syntax, config syntax, live-build flags, package
# resolvability, test suite, every *.var file valid.
# Exit 0 = clean, 1 = problems found.
# ============================================================================
FAIL=0
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

say()  { echo -e "\033[1;36m==>\033[0m $*"; }
ok()   { echo -e "    \033[1;32m[OK] $*\033[0m"; }
warn() { echo -e "    \033[1;33m[WARN] $*\033[0m"; }
err()  { echo -e "    \033[1;31m[FAIL] $*\033[0m"; FAIL=1; }

cd "$REPO_DIR"

# --- 1. shell syntax ----------------------------------------------------------
say "[1/5] Shell syntax..."
SYNTAX_FAIL=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if ! bash -n "$f" 2>/tmp/lint-sh-err.txt; then
    err "syntax error in $f:"; cat /tmp/lint-sh-err.txt | sed 's/^/    /'; SYNTAX_FAIL=1
  fi
done < <(find build/scripts build/hooks build/launcher scripts apps lib tools tests launcher -type f \( \( -name "*.sh" -o -name "*.hook.chroot" -o -name "arun-*" -o -name "var" \) ! -name "*.desktop" \) ! -path "*__pycache__*"; echo build/build-iso.sh; echo build/lb-config.sh; echo build/build-launcher.sh; echo build/launcher/lb-config-launcher.sh)
[ "$SYNTAX_FAIL" -eq 0 ] && ok "all shell scripts parse"

# --- 2. hook naming (*.hook.chroot required by live-build) + config syntax ---
say "[2/5] Hook filenames + config syntax..."
BADH=0
for h in build/hooks/live/* build/hooks/bootstrap/* build/launcher/*.hook.chroot; do
  [ -f "$h" ] || continue
  case "$h" in
    *.hook.chroot) ;;
    *) err "hook without .hook.chroot suffix: $h"; BADH=1;;
  esac
done
[ "$BADH" -eq 0 ] && ok "all hooks named *.hook.chroot"
# sysctl files: every active line must be "dotted.key = value"
BADS=0
for c in kernel/sysctl/*.conf; do
  [ -f "$c" ] || continue
  BAD_LINES="$(grep -vE '^[[:space:]]*(#|$)' "$c" | grep -vE '^[[:space:]]*[A-Za-z0-9_./-]+[[:space:]]*=[[:space:]]*[^[:space:]]+' || true)"
  if [ -n "$BAD_LINES" ]; then
    err "malformed sysctl line(s) in $c:"; printf '%s\n' "$BAD_LINES" | sed 's/^/    /'; BADS=1
  fi
done
[ "$BADS" -eq 0 ] && ok "sysctl configs well-formed"
# .desktop files: must carry the required freedesktop keys
BADD=0
for d in apps/*/*.desktop; do
  [ -f "$d" ] || continue
  for key in '^Name=' '^Exec=' '^Type=' '^Icon='; do
    grep -q "$key" "$d" || { err "$d is missing $key"; BADD=1; }
  done
done
[ "$BADD" -eq 0 ] && ok "all .desktop files have Name/Exec/Type/Icon"

# --- 3. live-build flag validation -------------------------------------------
say "[3/5] live-build flags (lb config trial run)..."
if command -v lb >/dev/null 2>&1; then
  T=$(mktemp -d)
  cp build/lb-config.sh build/launcher/lb-config-launcher.sh "$T/"
  if ( cd "$T" && LB_CACHE=false bash lb-config.sh trixie amd64 arunlinux linttest >/tmp/lb-config.log 2>&1 ); then
    ok "lb config accepted all flags (full ISO)"
    grep -E "^LB_(DISTRIBUTION|ARCHITECTURES|BINARY_IMAGES|CACHE|DEBIAN_INSTALLER)=" "$T/auto/config" 2>/dev/null | sed 's/^/    /' || true
  else
    err "lb config FAILED:"; tail -20 /tmp/lb-config.log | sed 's/^/    /'
  fi
  rm -rf "$T/auto" "$T/cache" 2>/dev/null || true
  if ( cd "$T" && LB_CACHE=false bash lb-config-launcher.sh trixie amd64 arunlinux-launcher linttest >/tmp/lb-config-launcher.log 2>&1 ); then
    ok "lb config accepted all flags (launcher ISO)"
  else
    err "launcher lb config FAILED:"; tail -20 /tmp/lb-config-launcher.log | sed 's/^/    /'
  fi
  rm -rf "$T"
else
  warn "lb not installed — skipping flag check (CI covers this)"
fi

# --- 4. package resolvability (Debian trixie, root) ---------------------------
say "[4/5] Package resolvability (apt dry-run)..."
if [ "$(id -u)" -eq 0 ] && command -v apt-get >/dev/null 2>&1 && [ -f /etc/debian_version ]; then
  # Ensure full areas (main contrib non-free non-free-firmware)
  for f in /etc/apt/sources.list.d/*.sources; do
    [ -f "$f" ] || continue
    grep -q "non-free-firmware" "$f" 2>/dev/null || \
      sed -i 's/Components: .*/Components: main contrib non-free non-free-firmware/' "$f" 2>/dev/null || true
  done
  grep -rq "non-free-firmware" /etc/apt/sources.list* 2>/dev/null || \
    echo "deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware" >> /etc/apt/sources.list
  dpkg --add-architecture i386
  if apt-get update -qq >/tmp/aptup.log 2>&1; then
    { grep -h -v -e '^\s*#' -e '^\s*$' build/package-lists/*.list.chroot build/launcher/*.list.chroot; } | sort -u > /tmp/want.txt
    echo "wine32" >> /tmp/want.txt   # installed by hook 0150 — verify too
    N=$(wc -l < /tmp/want.txt)
    echo "    resolving $N packages (with i386, recommends off — exactly like the real build)..."
    # shellcheck disable=SC2046
    if DEBIAN_FRONTEND=noninteractive apt-get install -y --dry-run \
         -o APT::Install-Recommends=false \
         $(tr '\n' ' ' < /tmp/want.txt) > /tmp/aptsim.log 2>&1; then
      ok "all $N packages resolve"
      grep -E "^[0-9]+ upgraded" /tmp/aptsim.log | sed 's/^/    /' || true
    else
      err "package resolution FAILED:"
      grep -E "^E:|Unable to locate|has no installation candidate|unmet dependencies|Broken" /tmp/aptsim.log | sort -u | sed 's/^/    /' || tail -20 /tmp/aptsim.log | sed 's/^/    /'
    fi
  else
    warn "apt-get update failed — skipping package check:"
    tail -5 /tmp/aptup.log | sed 's/^/    /'
  fi
else
  warn "not root on Debian — skipping package check (CI covers this)"
fi

# --- 5. test suite + .var validation ---------------------------------------------
say "[5/5] Tests + .var files..."
if bash tests/test-var.sh >/tmp/vartest.log 2>&1; then
  ok ".var test suite passed ($(grep -c PASS /tmp/vartest.log) assertions)"
else
  err ".var test suite FAILED:"; grep -E "FAIL|RESULT" /tmp/vartest.log | sed 's/^/    /'
fi
VAR_FAIL=0
while IFS= read -r v; do
  [ -f "$v" ] || continue
  if ! bash tools/var validate "$v" >/tmp/varval.log 2>&1; then
    err "$v invalid:"; cat /tmp/varval.log | sed 's/^/    /'; VAR_FAIL=1
  fi
done < <(find . -name "*.var" -not -path "./.git/*" | sort)
[ "$VAR_FAIL" -eq 0 ] && ok "all .var files valid"

echo ""
if [ "$FAIL" -eq 0 ]; then echo "LINT CLEAN - safe to build the ISOs."; exit 0;
else echo "LINT FOUND PROBLEMS - fix these before building."; exit 1; fi
