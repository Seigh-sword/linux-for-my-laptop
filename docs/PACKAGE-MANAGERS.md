# Package managers on arunlinux

arunlinux ships all of them — here is how they fit together.

## The lineup

| Manager | What it's for | Example |
|---|---|---|
| **apt** | System apps, drivers, dev tools (native .deb — smallest, fastest) | `sudo apt install htop` |
| **flatpak** (+Flathub) | Big desktop apps, always fresh (VLC, GIMP, OBS…) | `flatpak install vlc` |
| **snap** | Whatever's only on the Snap Store | `sudo snap install <app>` |
| **npm** | JS dev tools + global CLIs | `npm install -g typescript` |
| **AppImage** | Portable single-file apps (download → double-click) | Gear Lever app manages them |
| **pacman** | Real Arch Linux in a container (for AUR/arch-only stuff) | see below |

## Just use `arun-pkg` - it picks for you

```bash
sudo arun-pkg install vlc     # tries apt → flatpak → snap → npm → pacman
arun-pkg search obs           # searches everywhere at once
sudo arun-pkg sysupdate       # updates apt + flatpak + snap + npm together
arun-pkg info <app>           # shows which sources provide it
```

It even knows shortcuts: `arun-pkg install code` → VS Code, `chrome` → Chrome.

## Which source should win? (priority logic)
1. **apt** — native packages use the least RAM/disk. Always preferred on low-RAM machines.
2. **flatpak** — sandboxed + fresh; costs ~500 MB–1 GB runtime (one-time).
3. **snap** — fine, but snapd idles in RAM; use only if needed.
4. **npm -g** — only for JS CLI tools (never for desktop apps).
5. **pacman-in-distrobox** — escape hatch for Arch-only packages.

## pacman, really? On Debian??
Yes — really! `pacman` can't manage a Debian system (different package
format), so we give you the next best thing: a **real Arch container**:

```bash
distrobox create -i archlinux:latest -n arch   # one-time (~500 MB)
distrobox enter arch
sudo pacman -Syu neofetch                      # real pacman!
# Export GUI apps to your menu:
distrobox-export --app <appname>
```

`arun-pkg install` does all of this automatically as its last resort.

## AppImage tips
- `chmod +x file.AppImage` then double-click (or right-click → Allow executing).
- Install **Gear Lever** (Flathub) — it integrates AppImages into your menu
  and handles updates.
- Good sources: [appimagesearch.org](https://appimagesearch.org),
  [Flathub](https://flathub.org), [Snap Store](https://snapcraft.io/store).

## Disk-space rules for small disks
- Prefer apt builds. Uninstall unused flatpaks: `flatpak uninstall --unused`.
- Clean regularly: `arun-optimizer disk` (apt + flatpak + logs in one go).
- Check hogs: `baobab` (Disk Usage Analyzer) or `du -sh ~/* | sort -h`.
