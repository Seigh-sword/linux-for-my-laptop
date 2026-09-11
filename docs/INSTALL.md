# Installing arunlinux

Three ways to get arunlinux, easiest first.

---

## Path A — Convert Debian/Ubuntu into arunlinux (fastest, no ISO needed)

Best for trying everything TODAY in a VM or on any spare machine.

1. Install **Debian 13** (netinst, XFCE task) or **Ubuntu 24.04** normally.
2. Open a terminal:
   ```bash
   sudo apt update && sudo apt install -y git
   git clone https://github.com/Seigh-sword/arunlinux.git
   cd arunlinux
   sudo bash scripts/install-arunlinux.sh
   ```
3. **Reboot.** Log in → the Welcome Center appears - done!

> Re-running the script is safe — it skips what's already installed.

---

## Path B — Flash the ISO (real install / dual-boot with Windows)

### 1. Get the ISO
- Build it: `sudo bash build/build-iso.sh` (on Debian 13), or
- Download it from GitHub: **Actions → Build arunlinux ISO → Artifacts**.

### 2. Make a bootable USB
- **Windows:** [Rufus](https://rufus.ie) → select ISO → GPT + UEFI → Start.
- **Linux:** `sudo dd if=arunlinux-x86_64-v<commit>.hybrid.iso of=/dev/sdX bs=4M status=progress`
  (triple-check `/dev/sdX` is your USB stick!)

### 3. Partition plan for a small disk (dual-boot example, 128 GB)
| Partition | Size | Notes |
|---|---|---|
| Windows C: | ~60-70 GB | shrink from Windows Disk Management first! |
| `/` (root, ext4) | ~40-50 GB | arunlinux system + apps |
| `swap` | 2 GB | tiny disk swap as zram backup |
| EFI | existing | reuse Windows' EFI partition, don't format it |

> **Back up first.** Disable **BitLocker**, **Fast Startup**, and **Secure Boot**
> (or enroll MOK) before installing alongside Windows.

### 4. Boot USB → try live mode → click Install → reboot → enjoy.

---

## Path C — Virtual machine test (safe playground)
- VirtualBox/VMware: 2 CPU, 4 GB RAM, 25 GB disk, EFI enabled.
- Boot the ISO → live mode works without installing.
- Inside the VM you can also test Path A on a Debian netinst.

---

## First boot checklist
- [ ] Run `arun-welcome` → Update everything
- [ ] Run `arun-wallpapers` → pick your vibe
- [ ] Open VS Code + Chrome, sign in, install extensions
- [ ] `arun-optimizer status` → confirm zram is active
- [ ] Set up Timeshift (first snapshot = time machine for your system)
