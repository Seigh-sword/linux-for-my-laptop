# Research sources

Every website and reference consulted while designing and building arunlinux.
Grouped by topic, with what each source was used for.

## ISO factory (Debian live-build)

- Debian live-build manpage (trixie) — canonical flag reference
  <https://manpages.debian.org/trixie/live-build/live-build.7.en.html>
- Debian Live Manual — stages, hooks, includes, preseeding
  <https://live-team.pages.debian.net/live-manual/html/live-manual.en.html>
- Debian Wiki: ReproducibleInstalls/LiveImages — rebuild flow, squashfs options
  <https://wiki.debian.org/ReproducibleInstalls/LiveImages>
- live-build trixie walkthrough (blog) — practical lb config example
  <https://terkeyberger.wordpress.com/2022/03/07/live-build-how-to-build-an-installable-debian-10-buster-live-cd/>
- unix.stackexchange: trixie live-build thread — minimal working lb config
  <https://unix.stackexchange.com/questions/801208/modifying-a-debian-hybrid-iso-live-build-to-perform-auto-login-as-root>
- pendrivelinux.com live-build guide — beginner-oriented overview
  <https://pendrivelinux.com/create-your-own-live-linux-distribution/>

## Desktop choice (XFCE vs LXQt)

- factually.co: lightweight desktops for older hardware (2026)
  <https://factually.co/fact-checks/electronics-tech/best-lightweight-desktops-older-hardware-2026-xfce-lxqt-mate-04ec80>
- theinfobits.com: LXQt vs XFCE comparison
  <https://www.theinfobits.com/lxqt-vs-xfce/>

## zram + swap tuning

- karem505/linux-zram-optimization — zram-generator config baseline
  <https://github.com/karem505/linux-zram-optimization>
- linuxvox.com zram guide — zstd sizing walkthrough
  <https://linuxvox.com/blog/linux-zram/>
- programming.dev thread: zram + swappiness on 4 GB Fedora
  <https://programming.dev/post/20681159?scrollToComments=true>
- dev.to: practical zram with systemd-zram-generator — sizing formulas
  <https://dev.to/lyraalishaikh/stop-hitting-swap-too-late-practical-zram-on-linux-with-systemd-zram-generator-4m4j>

## Intel graphics (i915 module options)

- Arch forums: optimal i915 settings — fbc/fastboot discussion
  <https://bbs.archlinux.org/viewtopic.php?id=304318>
- reddit r/linuxquestions: i915 GuC/HuC parameters
  <https://www.reddit.com/r/linuxquestions/comments/jhq52j/i915_intel_kernel_parameters_guc_huc/>
- Brainiarc7 gist: Skylake+ iGPU tuning — enable_guc values
  <https://gist.github.com/Brainiarc7/aa43570f512906e882ad6cdd835efe57>

## APT key verification (VS Code + Chrome repos)

- Microsoft Linux package repositories — official key fingerprints
  <https://github.com/microsoft/linux-package-repositories>
- VS Code official Linux install docs
  <https://code.visualstudio.com/docs/setup/linux>
- linuxcapable.com: VS Code on Linux Mint — keyring + signed-by format
  <https://linuxcapable.com/how-to-install-vscode-on-linux-mint/>
- linuxfordevices.com: VS Code on Linux — repo setup variants
  <https://www.linuxfordevices.com/tutorials/linux/install-visual-studio-code-on-linux>
- cloudhousetechnologies.com: fixing apt NO_PUBKEY errors — modern keyring layout
  <https://cloudhousetechnologies.com/blog/how-to-fix-ubuntu-apt-no-pubkey-gpg-key-error-third-party-repository-2026>
- Kicksecure wiki: Chrome repository insecurity — Google key fingerprint data
  <https://www.kicksecure.com/wiki/Google_Chrome_Repository_Insecurity>
- reddit r/Crostini: Google GPG key thread — key id cross-check
  <https://www.reddit.com/r/Crostini/comments/et4rp0/gpg_error_during_apt_update_from_googles/>
- unix.stackexchange: google-chrome-stable repo thread — key import flow
  <https://unix.stackexchange.com/questions/774687/e-unable-to-locate-package-google-chrome-stable>

## Kernel / sysctl hardening

- Kernel Self Protection Project: recommended settings — sysctl baseline
  <https://kspp.github.io/Recommended_Settings.html>
- secure-os.org: Linux hardening guide (2026) — desktop sysctl set
  <https://secure-os.org/articles/linux-hardening/>
- linuxhardening.com: kernel sysctl hardening — key-by-key rationale
  <https://www.linuxhardening.com/en/blog/kernel-sysctl-hardening>
- oneuptime.com: hardening Ubuntu kernel with sysctl — complete config example
  <https://oneuptime.com/blog/post/2026-03-02-how-to-harden-ubuntu-kernel-with-sysctl-settings/view>
- NVIDIA DriveOS docs: Linux security hardening — YAMA/ptrace/dmesg reference
  <https://developer.nvidia.com/docs/drive/drive-os/7.0.3/public/drive-os-linux-sdk/production-deployment/linux_security_hardening.html>

## Firewall + automatic updates + fail2ban

- progressiverobot.com: fail2ban on Debian 13 — install + best practices
  <https://www.progressiverobot.com/2025/12/05/how-to-configure-fail2ban-on-debian-13/>
- progressiverobot.com: fail2ban remediation guide — unattended-upgrades setup
  <https://www.progressiverobot.com/2026/05/25/debian-13-fail2ban-vulnerability-patch-remediation/>
- ohyaan.github.io: Raspberry Pi OS trixie hardening — UFW + updates checklist
  <https://ohyaan.github.io/tips/raspberry_pi_security_hardening_complete_guide/>

## Netinstaller (debootstrap, partitioning, GRUB)

- grml-debootstrap docs — reference debootstrap installer flow
  <https://grml.org/grml-debootstrap/>
- grml-debootstrap manpage — target/grub/efi options
  <https://manpages.debian.org/unstable/grml-debootstrap/grml-debootstrap.8.en.html>
- oneuptime.com: debootstrap from scratch — chroot config, fstab, grub-install
  <https://oneuptime.com/blog/post/2026-03-02-debootstrap-minimal-ubuntu-system-from-scratch/view>
- debian-user thread: debootstrap + grub-install recipe (BIOS and EFI)
  <https://groups.google.com/g/linux.debian.user/c/sQvWgMieH2w>
- reddit r/debian: reinstalling grub-efi — --removable/--no-nvram flags
  <https://www.reddit.com/r/debian/comments/sb736l/how_to_installreinstall_grubefi_for_debian_1011/>
- rodsbooks.com: sgdisk walkthrough — scripted GPT partitioning
  <https://www.rodsbooks.com/gdisk/sgdisk-walkthrough.html>
- codelucky.com: sgdisk guide — type codes (ef00/ef02/8300), zap, naming
  <https://codelucky.com/sgdisk-command-linux/>
