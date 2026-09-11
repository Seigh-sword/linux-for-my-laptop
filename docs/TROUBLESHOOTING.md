# arunlinux troubleshooting

## Wi-Fi doesn't work / no networks
```bash
rfkill list              # if "Soft blocked: yes" → sudo rfkill unblock wifi
lspci | grep -i network  # identify your chip
sudo arun-drivers        # reinstall firmware mega-pack
```
- **Broadcom (brcm):** needs `firmware-brcm80211` + reboot (already in our pack).
- **Realtek 8852/8821:** usually fine with `firmware-realtek` on kernel 6.10+.
- Still stuck? USB-tether your phone for net, then `sudo apt update && sudo apt full-upgrade -y`.

## Screen flickering (Intel iGPU)
Panel Self-Refresh quirk on some laptops — disable it:
```bash
echo "options i915 enable_psr=0" | sudo tee /etc/modprobe.d/i915-arunlinux.conf
sudo update-initramfs -u && sudo reboot
```

## System freezes with Chrome open
1. `systemctl status earlyoom` — must be **active** (it kills hogs before freezes).
2. Chrome → `⋮ → Settings → Performance` → enable **Memory Saver** + **Energy Saver**.
3. `arun-optimizer clean` frees reclaimable cache safely.
4. Nuclear option: `arun-optimizer` → battery saver lowers background pressure.

## VS Code "ENOSPC / file watcher" error
Already fixed by our sysctl (`fs.inotify.max_user_watches=524288`). If it
still appears: `echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p`.

## No sound / Bluetooth headset issues
```bash
systemctl --user restart pipewire pipewire-pulse wireplumber
pavucontrol   # check Output Devices tab
```
Bluetooth: open **Blueman** → pair → right-click → Audio Profile → A2DP.

## Wine app won't start
```bash
winecfg                    # creates ~/.wine prefix (Windows 10 mode)
winetricks corefonts vcrun2019   # fixes 90% of app issues
```
Use **PlayOnLinux** for per-app isolated prefixes.

## Snap apps are slow to start first time
Normal (squashfs mount). Prefer apt/flatpak builds when available:
`arun-pkg info <app>` shows alternatives.

## Boot drops to GRUB rescue / Windows vanished
- Boot the USB → live mode → `sudo os-prober && sudo update-grub` from the installed system (chroot), or use **Boot-Repair**.
- Windows usually just needs its EFI entry re-added — don't panic, data is safe.

## Still stuck?
- Full log of your install: `/tmp/arunlinux-install.log`
- Health report: `arun-optimizer status` (paste this when asking for help)
- File an issue: https://github.com/Seigh-sword/arunlinux/issues
