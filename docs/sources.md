# Sources — the documented community methods this tooling implements

## Method (UBL / engineering-ABL)
1. **XDA thread 4797761** — *[GUIDE] Redmi Turbo 4 Pro — Unofficial Bootloader Unlock / UBL Mode Method — Chinese ROM* (hv_refat, updated Aug 2026; FAHIM package, zip `redmi_2026`).
   - "LOWER" package: `fastboot oem set-gpu-preemption 0 androidboot.selinux=permissive` + `fastboot continue` → permissive boot; `service call miui.mqsas.IMQSNative 21 … dd …` root-flash of engineering ABL; `fastboot flash partition:4 <GPT>`; `fastboot boot bonito.img` trigger; restore factory GPT; reflash stock ROM.
   - "HIGHER" package: same unlock, root via `LD_PRELOAD preload.so` → `su -c dd`.
2. **XDA thread 4786790** — *[Breakthrough] Free Offline Bootloader Unlock … 8Elite/8G3/8G2/8sGen4/8sGen3/MTK* (triitziii; up to June 2026 security patches). Confirms: after unlock the device may bootloop until the **same stock ROM is re-flashed** (restores boot chain incl. newer-SPL `boot.img`, `vbmeta`, `pvmfw`).
3. **GitHub `Linuxoid-cn/Mi8sG4-Unlocker`** (release v114514) — one-click Windows tool for 8s Gen 4; documents the same eng-ABL + unlock-GPT + trigger flow; `check-unlock.bat` uses `fastboot oem device-info` → "Device unlocked: true".

## Root vectors
4. **GitHub `Linuxoid-cn/CVE-2026-43499-Poc-Analysis`** (branch `secret`) — Android arm64 LPE; `preload.so` via `LD_PRELOAD /system/bin/true` grants uid 0; offsets (`p0_phys_offset`, `p0_kernel_phys_load`) from rooted `/proc/iomem`; `target.h` generated from the device `boot.img`; build with Android NDK r29 + llvm-objdump. Generated preload prints a challenge → password via `make_password_blob.py`.
5. **GitHub `YuKongA/ghostlock-app`** — generic kernel-race temp-root (CVE-2026-43499 family); offsets per-kernel derived from `boot.img` via its `tools/extract_rs`; gives uid 0 on a locked device (used to extract `boot.img` / read `/proc/iomem`).

## Stock ROM
6. Official Xiaomi CDN (`bigota.d.miui.com`), or mirrors (mifirm.net / xiaomifirmware.com). The ROM's own `flash_all.sh` reflashes the entire boot chain + `vbmeta`/`pvmfw` + `userdata`/`metadata`/`misc` — the standard post-unlock restore.

## Safety note
These methods bypass Xiaomi's official unlock authorization (no Mi-account binding / wait). Warranty/TOS void; data wiped; brick risk. Target builds only up to the community-documented security-patch cutoff — upgrading past it can permanently fuse the SoC and prevent future unlock.
