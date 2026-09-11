#!/bin/bash
# ============================================================================
# launcher/install-engine.sh - arunlinux netinstall engine
# Sourced by arun-launcher (never run directly). All destructive operations
# go through _run and honor DRY_RUN=1 (print instead of execute).
# ----------------------------------------------------------------------------
# Pipeline: partition -> format -> debootstrap -> base config -> payload ->
#           profile -> users -> bootloader -> cleanup
# Tested strategy: Debian debootstrap + chroot + grub (see docs/SOURCES.md).
# ============================================================================

ENG_TARGET="${ENG_TARGET:-/mnt/arun-target}"
ENG_MIRROR="${ENG_MIRROR:-https://deb.debian.org/debian}"
ENG_DIST="${ENG_DIST:-trixie}"
ENG_EFI=""
ENG_ROOT=""
ENG_LOG="${ENG_LOG:-/tmp/arun-install.log}"

_run() { # "$@" = command; dry-run prints, real run executes + logs
  if [ "${DRY_RUN:-0}" = "1" ]; then echo "+ $*"; return 0; fi
  echo "+ $*" >> "$ENG_LOG"
  "$@"
}

eng_require_root() {
  [ "$(id -u)" -eq 0 ] || { echo "ERROR: run as root" >&2; return 1; }
}

eng_check_network() { # exit 0 if the Debian mirror is reachable
  curl -fsSI --max-time 10 "$ENG_MIRROR/dists/$ENG_DIST/InRelease" >/dev/null 2>&1
}

eng_is_uefi() { [ -d /sys/firmware/efi ]; }

# --- disks -------------------------------------------------------------------
eng_list_disks() { # "name size model" per line, e.g. "sda 120G ATA_SSD"
  lsblk -dnro NAME,SIZE,MODEL,TYPE 2>/dev/null | awk '$4=="disk" {print $1, $2, $3}'
}

eng_boot_disk() { # best effort: the disk the live launcher booted from (or empty)
  local m src pk
  for m in /run/live/medium /lib/live/mount/medium; do
    mountpoint -q "$m" 2>/dev/null || continue
    src="$(findmnt -no SOURCE "$m" 2>/dev/null)" || continue
    src="${src#/dev/}"
    pk="$(lsblk -no PKNAME "/dev/$src" 2>/dev/null | head -1)"
    [ -n "$pk" ] && { echo "$pk"; return 0; }
    echo "$src" | grep -qE '^sd[a-z]|^nvme|^vd|^hd' && { echo "$src"; return 0; }
  done
  return 1
}

eng_part_suffix() { # $1 = disk name -> "p" for nvme/mmcblk, else ""
  case "$1" in nvme*|mmcblk*) printf 'p';; *) printf '';; esac
}

eng_list_parts() { # $1 = /dev/disk -> "name size fstype" per partition
  lsblk -lnro NAME,SIZE,FSTYPE,TYPE "/dev/$1" 2>/dev/null | awk '$4=="part" {print $1, $2, ($3==""?"-":$3)}'
}

# --- guided partitioning: 1M BIOS boot + 512M EFI + rest root (hybrid boot) ---
eng_partition_guided() { # $1 = disk name (sda); sets ENG_EFI / ENG_ROOT
  local disk="$1" dev="/dev/$1" sfx
  sfx="$(eng_part_suffix "$disk")"
  _run sgdisk --zap-all "$dev" || return 1
  _run sgdisk -o "$dev" || return 1
  _run sgdisk -n "1:0:+1M" -t 1:ef02 -c 1:"BIOS boot" "$dev" || return 1
  _run sgdisk -n "2:0:+512M" -t 2:ef00 -c 2:"EFI system" "$dev" || return 1
  _run sgdisk -n "3:0:0" -t 3:8300 -c 3:"arunlinux root" "$dev" || return 1
  if [ "${DRY_RUN:-0}" = "1" ]; then echo "+ partprobe $dev"; else partprobe "$dev" || true; fi
  ENG_EFI="${dev}${sfx}2"
  ENG_ROOT="${dev}${sfx}3"
}

eng_format() { # uses ENG_EFI / ENG_ROOT; mounts at ENG_TARGET
  [ -n "$ENG_EFI" ] && [ -n "$ENG_ROOT" ] || { echo "ERROR: partitions not set" >&2; return 1; }
  _run mkfs.fat -F32 -n ARUN-EFI "$ENG_EFI" || return 1
  _run mkfs.ext4 -F -L arunlinux "$ENG_ROOT" || return 1
  _run mkdir -p "$ENG_TARGET" || return 1
  _run mount "$ENG_ROOT" "$ENG_TARGET" || return 1
  _run mkdir -p "$ENG_TARGET/boot/efi" || return 1
  _run mount "$ENG_EFI" "$ENG_TARGET/boot/efi" || return 1
}

# --- bootstrap + base system ---------------------------------------------------
eng_debootstrap() {
  if [ "${DRY_RUN:-0}" != "1" ]; then
    command -v debootstrap >/dev/null 2>&1 || { echo "ERROR: debootstrap not installed" >&2; return 1; }
  fi
  _run debootstrap --variant=minbase "$ENG_DIST" "$ENG_TARGET" "$ENG_MIRROR" || return 1
  _run mount --bind /dev "$ENG_TARGET/dev" || return 1
  _run mount --bind /proc "$ENG_TARGET/proc" || return 1
  _run mount --bind /sys "$ENG_TARGET/sys" || return 1
  _run mount --bind /run "$ENG_TARGET/run" || return 1
  if [ "${DRY_RUN:-0}" = "1" ]; then echo "+ cp /etc/resolv.conf $ENG_TARGET/etc/resolv.conf"
  else cp /etc/resolv.conf "$ENG_TARGET/etc/resolv.conf"; fi
}

eng_write_base() { # $1 = hostname, $2 = timezone (e.g. UTC)
  local host="$1" tz="$2" root_uuid efi_uuid
  root_uuid="$(blkid -s UUID -o value "$ENG_ROOT" 2>/dev/null || echo DRYRUN-ROOT-UUID)"
  efi_uuid="$(blkid -s UUID -o value "$ENG_EFI" 2>/dev/null || echo DRYRUN-EFI-UUID)"
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ write apt sources, hostname=$host, timezone=$tz, fstab, policy-rc.d"
    return 0
  fi
  cat > "$ENG_TARGET/etc/apt/sources.list.d/debian.sources" <<EOF
Types: deb
URIs: $ENG_MIRROR
Suites: $ENG_DIST $ENG_DIST-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: $ENG_DIST-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
  echo "$host" > "$ENG_TARGET/etc/hostname"
  cat > "$ENG_TARGET/etc/hosts" <<EOF
127.0.0.1 localhost
127.0.1.1 $host
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
EOF
  cat > "$ENG_TARGET/etc/fstab" <<EOF
UUID=$root_uuid  /          ext4  defaults  0  1
UUID=$efi_uuid   /boot/efi  vfat  umask=0077  0  1
EOF
  echo "$tz" > "$ENG_TARGET/etc/timezone"
  ln -sf "/usr/share/zoneinfo/$tz" "$ENG_TARGET/etc/localtime" 2>/dev/null || true
  echo "LANG=C.UTF-8" > "$ENG_TARGET/etc/locale.conf"
  # keep chroot apt from trying to start daemons mid-install (removed after)
  printf '#!/bin/sh\nexit 101\n' > "$ENG_TARGET/usr/sbin/policy-rc.d"
  chmod +x "$ENG_TARGET/usr/sbin/policy-rc.d"
}

# --- payload: the arunlinux repo at the chosen version -------------------------
eng_fetch_payload() { # $1 = tarball URL; extracts to $TARGET/root/arun-src
  local url="$1"
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ curl -fSL $url -o /tmp/payload.tgz"
    echo "+ tar xzf to $ENG_TARGET/root/arun-src"
    return 0
  fi
  curl -fSL --retry 3 "$url" -o /tmp/arun-payload.tgz || return 1
  mkdir -p "$ENG_TARGET/root/arun-src"
  tar -xzf /tmp/arun-payload.tgz -C "$ENG_TARGET/root/arun-src" --strip-components=1 || return 1
  rm -f /tmp/arun-payload.tgz
}

# Full profile: bootable base set, then our own master installer in chroot.
# Honors ARUN_VERSION (branding), ARUN_SKIP_DEV / ARUN_SKIP_WINE (1 = skip).
eng_apply_profile() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ chroot apt install linux-image-amd64 grub-efi-amd64 grub-pc sudo network-manager ..."
    echo "+ chroot bash /root/arun-src/scripts/install-arunlinux.sh (ARUN_VERSION=$ARUN_VERSION ARUN_SKIP_DEV=${ARUN_SKIP_DEV:-0} ARUN_SKIP_WINE=${ARUN_SKIP_WINE:-0})"
    return 0
  fi
  _run chroot "$ENG_TARGET" apt update || return 1
  DEBIAN_FRONTEND=noninteractive _run chroot "$ENG_TARGET" apt install -y \
    linux-image-amd64 grub-efi-amd64 grub-pc sudo network-manager wpasupplicant \
    console-setup tzdata firmware-linux efibootmgr || return 1
  _run chroot "$ENG_TARGET" env \
    "ARUN_VERSION=${ARUN_VERSION:-}" \
    "ARUN_SKIP_DEV=${ARUN_SKIP_DEV:-0}" \
    "ARUN_SKIP_WINE=${ARUN_SKIP_WINE:-0}" \
    bash /root/arun-src/scripts/install-arunlinux.sh || return 1
}

# --- users from an accounts.var database ---------------------------------------
eng_users() { # $1 = accounts.var path, $2 = "user:pass" file (600, shredded after)
  local db="$1" passfile="$2" k name shell admin
  [ -f "$passfile" ] || { echo "ERROR: password file missing" >&2; return 1; }
  while IFS= read -r k; do
    case "$k" in user.*.name) ;;
      *) continue ;;
    esac
    name="${k#user.}"; name="${name%.name}"
    shell="$(var_get "$db" "user.$name.shell" "/bin/bash")"
    admin="$(var_get "$db" "user.$name.admin" "false")"
    if [ "$admin" = "true" ]; then
      _run chroot "$ENG_TARGET" useradd -m -s "$shell" -G sudo "$name" || return 1
    else
      _run chroot "$ENG_TARGET" useradd -m -s "$shell" "$name" || return 1
    fi
  done < <(var_keys "$db" "user.")
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ chroot chpasswd < $passfile (then shred)"
  else
    chroot "$ENG_TARGET" chpasswd < "$passfile" || return 1
    shred -u "$passfile" 2>/dev/null || rm -f "$passfile"
  fi
}

# --- bootloader (hybrid: EFI removable fallback + BIOS) --------------------------
eng_bootloader() { # $1 = /dev/disk
  local disk="$1" ok=0
  if eng_is_uefi || [ "${DRY_RUN:-0}" = "1" ]; then
    if _run chroot "$ENG_TARGET" grub-install --target=x86_64-efi \
        --efi-directory=/boot/efi --bootloader-id=arunlinux --removable; then
      ok=1
    else
      echo "[WARN] EFI grub-install failed, trying BIOS target..." >&2
    fi
  fi
  if _run chroot "$ENG_TARGET" grub-install --target=i386-pc --recheck "$disk"; then
    ok=1
  else
    echo "[WARN] BIOS grub-install failed." >&2
  fi
  [ "$ok" -eq 1 ] || { echo "ERROR: no bootloader installed (system would not boot)" >&2; return 1; }
  _run chroot "$ENG_TARGET" update-grub || return 1
}

eng_cleanup() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ rm policy-rc.d + payload, unmount binds, unmount target"
    return 0
  fi
  rm -f "$ENG_TARGET/usr/sbin/policy-rc.d"
  rm -rf "$ENG_TARGET/root/arun-src"
  umount -R "$ENG_TARGET/run" 2>/dev/null || true
  umount -R "$ENG_TARGET/sys" 2>/dev/null || true
  umount -R "$ENG_TARGET/proc" 2>/dev/null || true
  umount -R "$ENG_TARGET/dev" 2>/dev/null || true
  umount "$ENG_TARGET/boot/efi" 2>/dev/null || true
  umount "$ENG_TARGET" 2>/dev/null || true
}

# --- ISO download (for the write-ISO-to-USB path) ---------------------------------
eng_download_iso() { # $1 = url, $2 = sha256, $3 = dest file
  local url="$1" sha="$2" dest="$3" got
  echo "Downloading (resumable, Ctrl+C then re-run resumes)..."
  curl -fSL --retry 3 -C - "$url" -o "$dest" || return 1
  echo "Verifying SHA256..."
  got="$(sha256sum "$dest" | awk '{print $1}')"
  if [ "$got" = "$sha" ]; then echo "[OK] checksum matches."; return 0; fi
  echo "ERROR: checksum mismatch (got $got)" >&2
  return 1
}

eng_flash_usb() { # $1 = iso file, $2 = /dev/usb-disk (NOT a partition)
  local iso="$1" usb="$2"
  case "$usb" in *[0-9]) echo "ERROR: give the whole disk ($usb looks like a partition)" >&2; return 1;; esac
  [ -b "$usb" ] || { echo "ERROR: $usb is not a block device" >&2; return 1; }
  _run dd "if=$iso" "of=$usb" bs=4M status=progress conv=fsync || return 1
  _run sync
}
