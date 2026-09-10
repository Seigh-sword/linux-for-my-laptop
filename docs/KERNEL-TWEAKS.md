# ⚙️ arunlinux kernel & performance tweaks — explained

Every tweak, why it exists, and where it lives. Nothing here recompiles the
kernel (risky on a daily driver) — instead we tune the stock Debian kernel
to behave perfectly on 4 GB RAM + Intel iGPU.

## 1. zram — compressed RAM swap (the big one 🚀)
- **What:** half your RAM (2 GB) becomes lightning-fast compressed swap
  with the `zstd` algorithm (~3:1 ratio). Effective memory ≈ **6–8 GB**.
- **Files:** `kernel/zram/zram-generator.conf` → `/etc/systemd/zram-generator.conf`
  (fallback: `zram-swap.default` → `/etc/default/zramswap` for `zram-tools`).
- **Why zstd:** best compression/speed balance; recommended by Fedora & Arch.
- **Check:** `zramctl` or `swapon --show`.

## 2. sysctl VM tuning — tuned *for* zram
File: `kernel/sysctl/99-arunlinux.conf` → `/etc/sysctl.d/99-arunlinux.conf`

| Setting | Value | Why |
|---|---|---|
| `vm.swappiness` | 100 | zram is ~100x faster than disk — swapping idle pages into it *frees* RAM for Chrome/VS Code. (Same logic as Fedora.) |
| `vm.watermark_scale_factor` | 125 | More headroom for proactive reclaim, fewer stalls |
| `vm.watermark_boost_factor` | 0 | Boost is pointless overhead with zram |
| `vm.page-cluster` | 0 | zram has zero seek time — fetch one page at a time |
| `vm.vfs_cache_pressure` | 50 | Don't nuke file cache too eagerly |
| `vm.dirty_ratio/_background_ratio` | 10 / 5 | Smoother writes on slow laptop disks |
| `fs.inotify.max_user_watches` | 524288 | Fixes VS Code "ENOSPC / watcher" errors |

Apply live: `sudo sysctl --system`.

## 3. Intel iGPU tweaks (your integrated graphics)
- **modprobe:** `kernel/modprobe/i915.conf` — framebuffer compression (`enable_fbc`),
  panel self-refresh (`enable_psr`), GuC firmware (`enable_guc=2`), fastboot.
- **GRUB flags:** `intel_iommu=on i915.enable_psr=1 i915.enable_fbc=1` (see `kernel/grub/grub-defaults`).
- **Packages:** `intel-microcode`, `mesa-vulkan-drivers`, `intel-media-va-driver`
  (hardware video decode = smooth YouTube), `vainfo` to verify.
- ⚠️ If you ever see screen flicker: set `enable_psr=0` (see TROUBLESHOOTING.md).

## 4. Never-run-both rule: zram XOR zswap
`zswap.enabled=0` on the kernel cmdline — zswap would intercept pages *before*
they reach zram and waste both. We picked **zram** (simpler, no SSD wear).

## 5. Freeze protection: earlyoom
Config: `kernel/earlyoom/earlyoom.default`. Kills the biggest RAM hog at
10% free RAM / 5% free swap — *before* the desktop locks up. The desktop
session itself is protected. Check: `systemctl status earlyoom`.

## 6. Laptop power: TLP + thermald + irqbalance
- **TLP** — battery profiles (`sudo tlp bat` / `sudo tlp ac`; the Optimizer app does this).
- **thermald** — prevents Intel thermal throttling.
- **irqbalance** — spreads interrupts across CPU cores.
- **GRUB:** `nowatchdog nmi_watchdog=0` — tiny boot + battery win.

## 7. Responsiveness sprinkles
- **preload** — learns which apps you launch, preloads them.
- **ananicy** — auto-nices background tasks so the UI stays smooth.
- **TCP buffers + fastopen** — snappier Wi-Fi.

## Verify everything after install
```bash
arun-optimizer status   # one-screen health report
zramctl                 # zram devices
cat /proc/sys/vm/swappiness   # should be 100
vainfo | head -5        # video acceleration
```
