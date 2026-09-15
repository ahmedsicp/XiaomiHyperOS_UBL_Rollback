# payloads/ — per-SoC/per-device files required by both unlock methods

Place the following files here (names configurable in `config.sh`). They are **device/SoC specific** — obtain them for your exact device family (see Sources), and **verify with `scripts/gpt_verify.py` before flashing**.

| File (default) | Purpose |
|---|---|
| `abl.elf` | **Engineering ABL** for the device SoC (e.g. SM8735 "Ennea" for 8s Gen 4). Flashed to `abl_a` (then `abl_b`) via root-dd. Loadable on the target XBL; detector: eng ABL answers `fastboot oem device-info` and reports a different `security-patch-level` than stock. |
| `unlockgpt.bin` | **Unlock GPT** = the factory GPT with `vbmeta_a/b → xbmeta_a/b` and `pvmfw_a/b → xvmfw_a/b` renames (engineering-device names). Flashed via `fastboot flash partition:4` under the eng ABL. Makes the eng ABL treat the device as engineering → unlock persists. |
| `factory_gpt.bin` | **Factory GPT** for the device (or the ROM's own `gpt_both4.bin`). Restored after unlock. |
| `trigger.img` | **Trigger boot image** (community "bonito"/"Ennea" image, ~1.7 MB) booted via `fastboot boot` to persist the unlock state. |
| `preload.so` (higher) | CVE-2026-43499 payload — **build it yourself** for your kernel via `methods/higher/build_cve_preload.sh` (not a fixed file). |

## GPT rename trick (so you can build/verify your own unlock GPT)
The unlock GPT is byte-for-byte the factory GPT except four partition **names** change (LBAs/sizes/guids unchanged):
`vbmeta_a→xbmeta_a`, `vbmeta_b→xbmeta_b`, `pvmfw_a→xvmfw_a`, `pvmfw_b→xvmfw_b`.
`gpt_verify.py` checks that your device GPT equals the factory file exactly, and equals the unlock file modulo these renames — before you flash either.

## How to obtain per-SoC payloads (community sources)
- XDA thread **4797761** — FAHIM package (`abl.elf`, `gpt_both4.bin`, `onyx_gpt_both4.bin`, `bonito.img`) for 8s Gen 4; includes per-codename GPTs.
- GitHub **Linuxoid-cn/Mi8sG4-Unlocker** (release v114514) — per-device `unlockgpt_both4.bin` / factory `gpt_both4.bin`, `8735-Ennea.img`, for 8s Gen 4 (Turbo 4 Pro / Civi 5 Pro / Pad 8).
- XDA thread **4786790** — the broader "Breakthrough" package (up to June 2026 patches).
- **Never mix payloads across SoC/partition layouts.** Verify with `gpt_verify.py`.
