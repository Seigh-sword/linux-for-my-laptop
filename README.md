# 🐧 arunlinux

**A featherweight Linux distro built for Arun's laptop — 128 GB disk, 4 GB RAM, Intel CPU + Intel iGPU.**

Daily-driver ready for: **VS Code, Chrome, coding (Rust, C/C++, Go, Node, Java, Kotlin), Wine apps, and everything else.**

![arunlinux logo](assets/logo.png)

---

## ✨ What is arunlinux?

| Piece | Choice | Why |
|---|---|---|
| **Base** | Debian Stable + Ubuntu drivers/firmware stitched in | Rock-solid + great hardware support |
| **Desktop** | **ArunDE Fusion** — XFCE core + LXQt light apps, debloated | ~450 MB idle, pretty *and* fast |
| **Lite session** | Pure LXQt session at login | Max free RAM when you need it |
| **Kernel** | Debian kernel, heavily tuned (zram, sysctl, Intel i915 tweaks) | Feels like 6 GB RAM on a 4 GB machine |
| **Package managers** | `apt` + `flatpak` + `snap` + `npm` + `AppImage` + `pacman` (via Arch container) | Install anything from anywhere |
| **Dev stack** | Rust, C/C++, Go, Node, Java, Kotlin | One script installs all |
| **Windows apps** | Wine + Winetricks | Run .exe stuff |
| **Custom apps** | Welcome Center, Wallpaper Gallery, Optimizer, Driver Installer, `arun-pkg` | Built just for you |

## 📁 Repo layout

```
├── build/            # ISO factory (live-build config, package lists, hooks)
├── scripts/          # One-shot setup scripts (also used inside the ISO build)
├── kernel/           # Kernel/boot/RAM tuning (sysctl, zram, grub, i915)
├── apps/             # Custom arunlinux apps (Bash + YAD — zero Python, instant startup)
│   ├── arun-welcome/     # Welcome Center
│   ├── arun-wallpapers/  # Wallpaper Gallery (Minecraft / Spiderman / Ultra + more)
│   ├── arun-optimizer/   # RAM/battery/startup optimizer
│   ├── arun-drivers/     # Driver autoinstaller (the "Ubuntu drivers" magic)
│   └── arun-pkg/         # Unified package-manager wrapper
├── assets/           # Logo + 9 AI wallpapers
├── docs/             # Install / build / tweaks / troubleshooting guides
└── .github/workflows # CI that builds the ISO automatically
```

## 🚀 Quick start (3 paths)

### Path A — Try it TODAY without building anything (recommended first step)
Install Debian 13 or Ubuntu 24.04 in a VM (or on the laptop), then run:

```bash
git clone https://github.com/Seigh-sword/linux-for-my-laptop.git
cd linux-for-my-laptop
sudo bash scripts/install-arunlinux.sh
```

This transforms stock Debian/Ubuntu into full arunlinux: desktop fusion, drivers,
kernel tweaks, dev tools, Wine, all package managers, custom apps, wallpapers. (~30–60 min)

### Path B — Build the bootable ISO yourself
On a Debian 13 machine with ~20 GB free:

```bash
sudo bash build/build-iso.sh
# → out/arunlinux-x86_64-v<commit>.hybrid.iso  (flash with Rufus / Balena Etcher / dd)
```

See [docs/BUILD-ISO.md](docs/BUILD-ISO.md).

### Path C — Let GitHub build the ISO for you
Every commit on every branch triggers a cloud build (or run the workflow
manually) → download the ISO from the **Actions → Build arunlinux ISO →
Artifacts** page. See the workflow file.

## 🖥️ System requirements

| | Minimum | Your laptop ✅ |
|---|---|---|
| RAM | 2 GB | 4 GB |
| Disk | 16 GB | 128 GB |
| CPU | 64-bit Intel/AMD | Intel Core ✅ |
| GPU | Anything | Intel iGPU ✅ (fully supported) |

## 📚 Docs

- [INSTALL.md](docs/INSTALL.md) — install paths, dual-boot with Windows, partitioning for 128 GB
- [BUILD-ISO.md](docs/BUILD-ISO.md) — how the ISO factory works
- [KERNEL-TWEAKS.md](docs/KERNEL-TWEAKS.md) — every kernel/RAM/GPU tweak explained
- [PACKAGE-MANAGERS.md](docs/PACKAGE-MANAGERS.md) — apt/flatpak/snap/npm/AppImage/pacman guide
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — Wi-Fi, sound, Chrome, VS Code fixes

---

*Research notes: XFCE vs LXQt comparisons ([1](https://factually.co/fact-checks/electronics-tech/best-lightweight-desktops-older-hardware-2026-xfce-lxqt-mate-04ec80),
[2](https://www.theinfobits.com/lxqt-vs-xfce/)), Debian live-build ([guide](https://pendrivelinux.com/create-your-own-live-linux-distribution/)),
zram tuning ([zram-generator](https://github.com/karem505/linux-zram-optimization),
[guide](https://linuxvox.com/blog/linux-zram/)).*
