# arunlinux

![arunlinux icon](assets/arunlinux.svg)

**A featherweight Linux distro for low-RAM laptops and desktops — fast, pretty, and ready for real work.**

Daily-driver ready for: **VS Code, Chrome, coding (Rust, C/C++, Go, Node, Java, Kotlin), Wine apps, and everything else.**

Originally built for the author's own aging laptop, then released as open source for everyone.
If your machine is slow, old, or just short on RAM — this distro is for you.

> **100% vibe-coded:** every line of code, every app, every doc, and every pixel of
> artwork in this project was created with **Arena AI**. No hand-written code. Just prompts,
> patience, and a lot of iterating.

---

## What is arunlinux?

| Piece | Choice | Why |
|---|---|---|
| **Base** | Debian Stable + extra drivers/firmware | Rock-solid + great hardware support |
| **Desktop** | **ArunDE Fusion** — XFCE core + LXQt light apps, debloated | ~450 MB idle, pretty *and* fast |
| **Lite session** | Pure LXQt session at login | Max free RAM when you need it |
| **Kernel** | Debian kernel, tuned (zram, sysctl, Intel/AMD graphics tweaks) | Makes low-RAM machines feel twice as big |
| **Package managers** | `apt` + `flatpak` + `snap` + `npm` + `AppImage` + `pacman` (via Arch container) | Install anything from anywhere |
| **Dev stack** | Rust, C/C++, Go, Node, Java, Kotlin | One script installs all |
| **Windows apps** | Wine + Winetricks | Run .exe stuff |
| **Security** | UFW firewall, automatic security updates, fail2ban, hardened sysctl | Safe defaults out of the box |
| **Installer** | Minimal launcher ISO (netinstall any version from a registry) | Small download, accounts included |
| **Custom apps** | Welcome Center, Wallpaper Gallery, Optimizer, Driver Installer, Account Manager, `arun-pkg` | Bash + YAD: instant startup, tiny RAM |

## Repo layout

```
├── build/            # ISO factories (full ISO + minimal launcher ISO)
├── scripts/          # One-shot setup scripts (also used inside the ISO build)
├── kernel/           # Kernel/boot/RAM tuning (sysctl, zram, grub, graphics)
├── launcher/         # Netinstaller: arun-launcher TUI, engine, .var registry
├── lib/              # Shared libraries (the .var variable-file parser)
├── tools/            # CLI helpers (the `var` tool for .var files)
├── tests/            # Test suites (run: bash tests/test-var.sh)
├── apps/             # Custom arunlinux apps (Bash + YAD — zero Python, instant startup)
│   ├── arun-welcome/     # Welcome Center
│   ├── arun-wallpapers/  # Wallpaper Gallery (Minecraft / Spiderman / Ultra + more)
│   ├── arun-optimizer/   # RAM/battery/startup optimizer
│   ├── arun-drivers/     # Driver autoinstaller (the "Ubuntu drivers" magic)
│   ├── arun-accounts/    # User account manager (.var backend)
│   └── arun-pkg/         # Unified package-manager wrapper
├── assets/           # Icon, logo + AI wallpapers
├── docs/             # Install / build / tweaks / troubleshooting guides
├── AGENT.md          # Handbook for AI agents working on this repo
└── .github/workflows # CI that lints and builds the ISOs automatically
```

## Quick start (4 paths)

### Path A — Try it TODAY without building anything (recommended first step)

Install Debian 13 or Ubuntu 24.04 in a VM (or on any spare machine), then run:

```bash
git clone https://github.com/Seigh-sword/arunlinux.git
cd arunlinux
sudo bash scripts/install-arunlinux.sh
```

This transforms stock Debian/Ubuntu into full arunlinux: desktop fusion, drivers,
kernel tweaks, dev tools, Wine, all package managers, custom apps, wallpapers. (~30-60 min)

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

### Path D — Netinstall with the tiny launcher ISO (smallest download)

Grab `arunlinux-launcher-*.hybrid.iso` from **Actions → Build launcher ISO →
Artifacts** (or build it: `sudo bash build/build-launcher.sh`), flash it to a
USB stick, and boot. The launcher downloads only the version payload (a few MB)
plus Debian packages, creates your user accounts, and installs everything.
See [docs/LAUNCHER.md](docs/LAUNCHER.md).

## System requirements

| | Minimum | Recommended |
|---|---|---|
| RAM | 2 GB | 4 GB or more |
| Disk | 16 GB | 32 GB or more |
| CPU | 64-bit Intel/AMD | Any dual-core or better |
| GPU | Anything (Intel/AMD integrated fully supported) | Same |

## Docs

- [INSTALL.md](docs/INSTALL.md) — install paths, dual-boot with Windows, partitioning guide
- [BUILD-ISO.md](docs/BUILD-ISO.md) — how the ISO factory works
- [LAUNCHER.md](docs/LAUNCHER.md) — the minimal netinstaller ISO + registry + accounts
- [VAR-SPEC.md](docs/VAR-SPEC.md) — the .var variable-file format + tools
- [KERNEL-TWEAKS.md](docs/KERNEL-TWEAKS.md) — every kernel/RAM/GPU tweak explained
- [PACKAGE-MANAGERS.md](docs/PACKAGE-MANAGERS.md) — apt/flatpak/snap/npm/AppImage/pacman guide
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — Wi-Fi, sound, Chrome, VS Code fixes
- [SOURCES.md](docs/SOURCES.md) — every website and reference used to research and build this distro
- [AGENT.md](AGENT.md) — how (human or AI) contributors work on this repo

## Contributing

Found a bug? Have a tweak for old hardware? Open an issue or a pull request —
every PR gets an automatic ISO build so you can test your change on real metal.

## License

MIT — see [LICENSE](LICENSE). Do whatever you want with it, just keep the vibe alive.
