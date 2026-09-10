# 🏭 How the arunlinux ISO factory works

We use **Debian live-build** — the official tool for rolling custom Debian
live/installer ISOs. Same tech behind Kali, MX and many remixes.

## Architecture

```
build/
├── build-iso.sh                 ← YOU ARE HERE (run with sudo on Debian 13)
├── lb-config.sh                 ← live-build settings (repos, bootloader, user…)
├── package-lists/*.list.chroot  ← what gets INSTALLED into the image
├── hooks/                       ← scripts that run INSIDE the image mid-build
│   ├── bootstrap/0100-enable-i386 → dpkg --add-architecture i386 BEFORE packages (Wine!)
│   └── live/
│       ├── 0100-enable-i386      → re-ensures i386 (backup)
│       ├── 0150-wine32           → installs wine32 + 32-bit libs (needs i386)
│       ├── 0200-thirdparty-repos → adds VS Code + Chrome repos, installs them
│       └── 0300-arun-tweaks      → copies kernel tweaks, apps, wallpapers
└── includes.installer/preseed.cfg ← installer defaults (locale, timezone…)
```

Build stages: **bootstrap** (minbase) → **chroot** (packages + hooks) →
**binary** (squashfs + ISO) → `out/arunlinux-1.0-amd64.hybrid.iso`.

## Build requirements
- Host OS: **Debian 13** (must match target — live-build rule)
- Root, ~20 GB free, decent network. Time: 20–60 min.

```bash
sudo bash build/build-iso.sh
```

## Customizing
| Want to… | Edit… |
|---|---|
| Add/remove apps | `build/package-lists/*.list.chroot` |
| Change kernel/RAM tuning | `kernel/*` (auto-copied by hook 0300) |
| Add your own first-boot script | new `build/hooks/live/04*.hook.chroot` (+ `chmod +x`) |
| Change live username | `build/lb-config.sh` (`--username`) |
| Change boot splash options | `build/lb-config.sh` (`--bootappend-live`) |

After editing: `cd iso-build && sudo lb clean && sudo lb build` for a fast rebuild.

## CI builds
`.github/workflows/build-iso.yml` builds the ISO in a privileged Debian
container on every push to `main` (and on demand). The ISO lands in the
workflow's **Artifacts** (kept 7 days). Note: GitHub runners take ~30–50 min.

## Troubleshooting builds
- **Hook fails / drops to shell:** read the error, `apt-get install <missing>`, `exit` to resume.
- **Stuck at bootstrap:** bad mirror — check network/DNS on host.
- **`lb: command not found`:** `sudo apt install live-build`.
- **ISO too big (>4 GB)?** Trim `arun-apps.list.chroot` (LibreOffice, Thunderbird…).
