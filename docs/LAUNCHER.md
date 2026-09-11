# The arunlinux launcher (minimal netinstaller)

The full arunlinux ISO is gigabytes. The **launcher** is the alternative: a
minimal console ISO whose only job is to install arunlinux for you — pick a
version from the registry, create your accounts, wipe a disk, done.

## Honest sizing

The launcher *scripts* (installer + registry + `.var` library) are about
50 KB. A bootable ISO cannot be kilobytes though: the Linux kernel, firmware
and base system alone are hundreds of megabytes. Expect the launcher ISO to
land around a few hundred MB — still roughly **10x smaller** than the full
desktop ISO — and the per-version payload it downloads is just a few MB
(the repo tarball) plus Debian packages from the mirror.

## What it does

```
boot launcher ISO (any PC, UEFI or BIOS)
  -> arun-launcher starts on tty1 (whiptail menus, text fallback)
    -> refresh versions-registry.var from the internet (else bundled copy)
    -> Install to disk (netinstall)  |  Write full ISO to USB  |  Accounts
```

**Install to disk:** choose a `netinstall` version, choose a target disk
(the disk you booted from is hidden so you cannot nuke it), guided
(BIOS boot + EFI + root, hybrid GRUB) or manual (`cfdisk`) partitioning,
create accounts (`user`, `user2`, anything), set passwords, review, install.
The engine runs `debootstrap`, configures the base, fetches the version
payload, runs the standard `install-arunlinux.sh` profile inside a chroot,
creates your users, installs GRUB, and cleans up. Log: `/tmp/arun-install.log`.

**Write ISO to USB:** choose an `iso` version, download with resume, verify
SHA256, flash to a USB stick with `dd`.

**Accounts:** `arun-accounts` manages `accounts.var` — add/del/list users,
toggle admin. Passwords are **never** stored in the file; the launcher asks
at install time and pipes them straight to `chpasswd` in the target.

## The registry (`launcher/versions-registry.var`)

Backend store in [`.var` format](VAR-SPEC.md). Two entry kinds:

```
ver.0.kind = "netinstall";   ver.1.kind = "iso";
ver.0.commit = "90130a1";    ver.1.url = "https://.../arunlinux-....iso";
ver.0.payload = "https://github.com/.../archive/90130a1.tar.gz";
                             ver.1.sha256 = "...";
                             ver.1.size = 3900000000;
```

Publishing a version = appending a slot and bumping `ver.count` + `latest`.
The launcher refreshes this file from `registry.refresh` on every boot.

## Building the launcher ISO

On Debian 13 with ~10 GB free:

```bash
sudo bash build/build-launcher.sh
# -> out/arunlinux-launcher-x86_64-v<commit>.hybrid.iso
```

Or let CI build it: every commit triggers **Actions → Build launcher ISO**
automatically (plus a weekly schedule and manual runs). Flash with `dd`,
Rufus, or Balena Etcher, boot, and follow the menus.

Profile layout (`build/launcher/`): `lb-config-launcher.sh` (minimal flags,
no debian-installer — *we* are the installer), `launcher.list.chroot`
(~15 packages: debootstrap, gdisk, parted, network-manager, whiptail...),
`0100-launcher.hook.chroot` (installs the payload + the tty1 service).

## Trying it without rebooting

```bash
sudo DRY_RUN=1 launcher/arun-launcher --dry-run --text   # click through safely
bash tests/test-var.sh                                   # .var test suite
./tools/var get launcher/versions-registry.var registry.latest
./apps/arun-accounts/arun-accounts --db /tmp/t.var add demo
```

## Limits (v1)

- Guided partitioning wipes the whole disk (no dual-boot resize yet).
- No LUKS encryption yet, no LVM, no Wi-Fi passwords stored (use `nmtui`
  on tty2 during install).
- Netinstall needs internet; the full ISO path covers offline machines.
