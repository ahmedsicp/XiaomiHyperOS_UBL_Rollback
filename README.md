# Xiaomi HyperOS unofficial bootloader unlock — rollback method (LOWER path)

Separate repo for the stock-ABL cmdline-injection / rollback unlock technique — **no kernel exploit needed**.

## Method
1. **Permissive boot** via the stock-ABL hole: `fastboot oem set-gpu-preemption 0 androidboot.selinux=permissive` + `fastboot continue`.
2. **Root-dd via the Xiaomi diagnostic service**: `adb shell service call miui.mqsas.IMQSNative 21 … 'dd' …` (runs as root; SELinux permissive makes the binder call succeed).
3. **Unlock (UBL)**: flash the engineering ABL, flash the unlock GPT (`vbmeta→xbmeta`/`pvmfw→xvmfw`) via `fastboot flash partition:4`, `fastboot boot <trigger.img>`, confirm unlock, `erase frp`, restore factory GPT + stock ABL.
4. **Post-unlock**: reflash the stock ROM (`flash_all.sh`), wipe, verify.

Applies to Xiaomi/Redmi/POCO HyperOS builds where the cmdline hole is accepted (community-documented up to ~3.0.2.x / pre-patch). If the hole is absent, use the **Linux CVE method** repo (same unlock, CVE-2026-43499 root).

## Usage
```sh
./runbook.sh precheck          # device props + lock state
./runbook.sh permissive        # cmdline injection -> SELinux permissive
./runbook.sh backup            # mqsas root-dd backups + gpt_verify
./runbook.sh abl               # flash engineering ABL + read-back verify
./runbook.sh unlock            # unlock GPT + trigger + restore factory GPT/stock ABL
./runbook.sh reflash           # reflash stock ROM (set ROM_DIR in config)
./runbook.sh verify            # reboot + confirm unlocked
```

## Components
- `runbook.sh` (method), `scripts/helpers.sh` (shared), `scripts/gpt_verify.py` (payload-vs-device GPT verification), `scripts/fetch_mifirm.js` (stock-ROM fetch helper, optional)
- `config.sh` (generic, parametrized; no device-specific identifiers)
- `payloads/README.md` (per-SoC payload files + the GPT-rename trick), `docs/sources.md` (documented method)
- `tools/` (fastboot/adb) is gitignored — fetch from Google platform-tools.

## Safety
Unofficial; bypasses Xiaomi's official unlock authorization. Warranty/TOS void, data wiped, brick risk. Target builds only up to the documented security-patch cutoff — upgrading past it can permanently fuse the SoC. Use on devices you own.
