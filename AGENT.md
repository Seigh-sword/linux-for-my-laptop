# AGENT.md — handbook for working on arunlinux

Read this before changing anything. It captures how this repo is built,
verified, and shipped, plus the traps that wasted hours in past sessions.

## What this is

arunlinux is a featherweight Debian-trixie-based distro for low-RAM machines:
a live-build ISO factory (`build/`), a convert-in-place installer (`scripts/`),
kernel tuning (`kernel/`), five Bash+YAD apps (`apps/`), artwork (`assets/`),
guides (`docs/`), and CI that lints + builds the ISO on every push.

The whole project is vibe-coded with Arena AI: Bash + YAD for apps (no Python
GUI stack), Markdown for docs, hand-made SVG for the icon.

## Repo map

```
build/build-iso.sh        main ISO build (run as root on Debian 13, from repo root)
build/lb-config.sh        live-build flags (called by build-iso.sh + the linter)
build/package-lists/      *.list.chroot = packages installed INTO the image
build/hooks/bootstrap/    runs BEFORE packages (enables i386 multiarch for Wine)
build/hooks/live/         runs AFTER packages (repos, wine32, tweaks+apps copy)
build/includes.installer/ preseed.cfg (locale, timezone, user; NEVER auto-partition)
scripts/                  installer modules; also shipped inside the ISO
kernel/                   sysctl / zram / modprobe / grub / earlyoom sources
apps/<name>/<name>        executables (Bash); some ship a .desktop file
assets/arunlinux.svg      distro icon (source of truth); logo.png = banner art
docs/                     user guides; SOURCES.md = research links (keep updated)
.github/workflows/        lint-packages.yml (~2 min) + build-iso.yml (~25-50 min)
```

## Verify before you commit (run all of these)

```bash
# 1. shell syntax for everything executable
find build scripts apps -type f \( -name '*.sh' -o -name '*.hook.chroot' \
  -o -name 'arun-*' ! -name '*.desktop' \) -exec bash -n {} + \
  && bash -n build/build-iso.sh && bash -n build/lb-config.sh

# 2. fast linter (syntax + hooks + lb flags + package resolution on Debian)
bash scripts/lint-distro.sh

# 3. no emojis anywhere in tracked text files (repo rule - see below)
python3 - <<'EOF'
import subprocess, re
pat = re.compile(r'[\U0001F000-\U0001FAFF\u2600-\u27BF\u2B00-\u2BFF\uFE0F\u200D\u2139]')
files = subprocess.run(['git', 'ls-files'], capture_output=True, text=True).stdout.split()
bad = [f for f in files if not f.endswith(('.png', '.jpg', '.jpeg'))
       and pat.search(open(f, encoding='utf-8', errors='ignore').read())]
print('EMOJI FOUND IN:', bad if bad else 'none - clean')
EOF

# 4. icon still valid XML
python3 -c "import xml.dom.minidom; xml.dom.minidom.parse('assets/arunlinux.svg')"
```

## CI behavior (important)

- BOTH workflows trigger on **every push to every branch** plus manual dispatch.
  build-iso.yml also runs weekly (Sunday 02:00 UTC).
- `lint-packages.yml` (~2 min): runs `scripts/lint-distro.sh` in a debian:trixie
  container. Must stay green before caring about the ISO.
- `build-iso.yml` (~25-50 min): builds the full ISO in a privileged container.
  ISO + sha256 land in Actions Artifacts (7-day retention). Both post the tail
  of their logs as a PR comment **only when a PR is open** for that branch.
- Monitor runs with: `gh run watch <id> --exit-status`
- From a sandboxed agent, `gh run view --log` and artifact downloads may be
  blocked; rely on `gh run watch` status, job conclusions, and the API.

## Hard conventions (do not break)

1. **No emojis in code, scripts, workflows, or docs.** Use `[OK]`, `[WARN]`,
   `[ERROR]`, `[PASS]`, `[FAIL]` text tags instead. Check with the scan above.
2. **Public arch name is `x86_64`, Debian-internal name stays `amd64`.**
   ISO files: `arunlinux-x86_64-v<commit>.hybrid.iso`. Never rename the
   Debian arch in lb flags, package lists, or repo lines or the build breaks.
3. **Live user is `arun`, hostname `arunlinux`** (lb-config `--bootappend-live`
   + preseed must agree).
4. **Hooks must be named `*.hook.chroot` and executable.** bootstrap/0100
   enables i386 BEFORE packages; live/0150 installs wine32 AFTER (ordering
   matters — wine32 in a package list would fail).
5. **Every script must be idempotent** (safe to re-run): guard with
   `command -v`, `grep -q`, `|| true`, `--if-not-exists`.
6. **`set -e` hazard:** a bare `command -v foo && echo ...` line EXITS the
   script when foo is missing. Always end report lines with `|| ...` fallback.
7. **Third-party APT keys must be fingerprint-verified** (`fetch_key` helper):
   Microsoft `EB3E94ADBE1229CF`, Google `7721F63BD38B4796`.
8. **Docs address the community, never the author:** no personal specs, no
   "your 4 GB laptop". Generic terms: "low-RAM machines", "small disks".
9. **New research goes in `docs/SOURCES.md`** with the URL and what it was for.

## Trixie gotchas (learned the hard way)

- live-build flags are SINGULAR: `--architecture`, `--binary-image`
  (not `--architectures` / `--binary-images`).
- `--cache-stages` takes stage names; there is no `--username`/`--hostname`.
- Renamed/removed packages: `policykit-1` -> `polkitd`, `polkitd-pkla` gone,
  `libfuse3-3` gone (fuse3 pulls its own lib), `neofetch` gone (use `inxi`),
  some `libasound2` -> `libasound2t64` (the wine32 hook tries both).
- Debian 12+ APT sources are deb822 `.sources` files; debloat.sh patches both
  formats. Ubuntu still uses `.list` — scripts must handle both.
- Host that builds the ISO must BE Debian 13 (live-build rule); CI uses a
  privileged `debian:trixie` container for exactly this reason.

## Adding things

- **New package:** append to the right `build/package-lists/*.list.chroot`
  (one name per line, `#` comments allowed), then the linter verifies it
  against real trixie repos. Prefer small native .debs; keep the ISO < 4 GB.
- **New ISO build step:** add `build/hooks/live/04*.hook.chroot`, `chmod +x`,
  `set -e`, `|| true` on anything network-dependent (hooks run in chroot).
- **New installer module:** add `scripts/<name>.sh`, call it from
  `scripts/install-arunlinux.sh`, keep it re-runnable. It ships inside the
  ISO automatically via hook 0300 (`/usr/share/arunlinux/scripts/`).
- **New app:** `apps/<name>/<name>` (executable Bash) + optional `.desktop`
  (must have Name/Exec/Type/Icon — the linter checks). Symlink it into
  `/usr/local/bin` in BOTH `scripts/install-arunlinux.sh` AND hook 0300.
- **New docs page:** link it from README.md "Docs" section.

## Agent tooling rules (read this, future agent)

- **NEVER issue parallel edits to the SAME file.** Parallel `edit_file` calls
  to one file race: only one survives, the rest report success and are
  silently lost. This once shipped a broken `arun-pkg` (used `$SUDO` without
  defining it). Same-file edits MUST be sequential, one per response block.
- Parallel edits to DIFFERENT files are safe.
- After any batch of edits, re-verify with `grep -c` that every intended
  change is actually on disk BEFORE committing. Trust `grep`, not tool receipts.

## Arena session notes

- Work stays on the session branch (`arena/...`); commit + push there only.
- Never open/close PRs casually: closing the session PR can revoke the
  session's GitHub access.
- Commit messages: short, descriptive, no emoji.
