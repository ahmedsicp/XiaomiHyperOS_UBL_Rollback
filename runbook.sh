#!/bin/sh
# ============================================================================
# methods/lower/runbook.sh — Xiaomi rollback method (LOWER path)
# Root vector: stock-ABL cmdline injection -> SELinux permissive, then the
# Xiaomi `miui.mqsas.IMQSNative` service executes `dd` as root (no exploit).
# Unlock: engineering ABL + unlock GPT (vbmeta->xbmeta / pvmfw->xvmfw) + trigger.
# Usage: ./runbook.sh <precheck|permissive|backup|abl|unlock|reflash|verify>
# ============================================================================
cd "$(dirname "$0")"                       # methods/lower
ROOT=$(pwd)
. ./config.sh                              # local -> shared config (METHOD=lower)
. "$ROOT/scripts/helpers.sh"               # wait_* / mqsas_cmd / root_dd helpers
FB="$FBIN"; ADB="$ADBIN"
LOGDIR="$ROOT/$LOGDIR"; DEVICEDIR="$ROOT/$DEVICEDIR"; BACKUP_DIR="$ROOT/$BACKUP_DIR"
mkdir -p "$LOGDIR" "$DEVICEDIR" "$BACKUP_DIR" "$ROOT/$PAYLOAD_DIR"
[ -f "$ROOT/$ABL_FILE" ]    || die "engineering ABL missing: $ABL_FILE"
[ -f "$ROOT/$UNLOCK_GPT" ]  || die "unlock GPT missing: $UNLOCK_GPT"
[ -f "$ROOT/$FACTORY_GPT" ] || die "factory GPT missing: $FACTORY_GPT"
[ -f "$ROOT/$TRIGGER_IMG" ] || die "trigger image missing: $TRIGGER_IMG"

case "$1" in
precheck)
  say "adb device"; $ADB devices -l | grep -v emulator
  say "props (compare with your device's expected values)"
  for p in ro.product.device ro.build.version.incremental ro.build.version.security_patch ro.boot.slot_suffix ro.boot.flash.locked ro.boot.vbmeta.device_state ro.miui.build.region; do
    echo "$p: $($ADB shell getprop $p)"
  done
  say "expected: LOCKED (flash.locked=1), slot _a/_b, matching ROM/SPL"
  ;;
permissive)   # LOWER root vector
  wait_adb || die "need adb"
  $ADB reboot bootloader 2>/dev/null || true; sleep 3
  wait_fastboot || die "device did not reach fastboot"
  $FB getvar all > "$DEVICEDIR/fastboot_getvar_stock.txt" 2>&1 || true
  say "inject permissive cmdline: $OEM_CMD"
  $FB $OEM_CMD > "$LOGDIR/oem_permissive.log" 2>&1; cat "$LOGDIR/oem_permissive.log"
  $FB continue > "$LOGDIR/fastboot_continue.log" 2>&1; tail -3 "$LOGDIR/fastboot_continue.log"
  sleep 20
  $ADB shell true 2>/dev/null || { $FB reboot >/dev/null 2>&1 || true; }
  wait_permissive || die "SELinux not permissive — cmdline hole absent; use higher/CVE repo"
  say "SELinux permissive confirmed"
  ;;
backup)
  wait_adb || die "need permissive boot first"
  say "backing up critical partitions (by-name) + GPT of the abl LUN"
  for p in abl_a abl_b boot_a boot_b misc apdp apdpb; do
    root_dd "if=/dev/block/by-name/$p of=/data/local/tmp/bk_$p.bin" "$p"
  done
  LUN=$($ADB shell readlink -f /dev/block/by-name/abl_a | tr -d '\r\n'); LUN="${LUN#*/dev/block/}"; LUN="${LUN%%[0-9]*}"
  SIZE=$($ADB shell cat /sys/block/$LUN/size | tr -d '[:space:]'); SKIP=$(( SIZE/2048 - 2 ))
  say "abl LUN=$LUN size=$SIZE skip=$SKIP"
  root_dd "if=/dev/block/$LUN of=/data/local/tmp/bk_gpt_head.bin bs=1048576 count=2" gpt_head
  root_dd "if=/dev/block/$LUN of=/data/local/tmp/bk_gpt_tail.bin bs=1048576 skip=$SKIP count=2" gpt_tail
  root_chmod "644 /data/local/tmp/bk_*.bin"
  for f in abl_a abl_b boot_a boot_b misc apdp apdpb gpt_head gpt_tail; do
    $ADB pull "/data/local/tmp/bk_$f.bin" "$BACKUP_DIR/bk_$f.bin" 2>/dev/null || say "pull failed $f"
  done
  sha256sum "$BACKUP_DIR"/bk_*.bin | tee "$LOGDIR/backup_sha256.txt"
  say "verify GPT payload compatibility"
  python3 "$ROOT/scripts/gpt_verify.py" "$BACKUP_DIR/bk_gpt_head.bin" "$ROOT/$FACTORY_GPT" "$ROOT/$UNLOCK_GPT"
  ;;
abl)
  wait_adb || die "need permissive boot first"
  [ -f "$BACKUP_DIR/bk_abl_a.bin" ] || die "run backup phase first"
  $ADB push "$ROOT/$ABL_FILE" /data/local/tmp/abl
  say "flash engineering ABL -> abl_a only (slot b stays stock as safety)"
  root_dd "if=/data/local/tmp/abl of=/dev/block/by-name/abl_a" flash_abl_a
  root_dd "if=/dev/block/by-name/abl_a of=/data/local/tmp/verify_abl_a.bin" verify_abl_a
  root_chmod "644 /data/local/tmp/verify_abl_a.bin"
  $ADB pull /data/local/tmp/verify_abl_a.bin "$BACKUP_DIR/verify_abl_a.bin"
  SZ=$(stat -c%s "$ROOT/$ABL_FILE"); head -c "$SZ" "$BACKUP_DIR/verify_abl_a.bin" > /tmp/vp.bin
  A=$(sha256sum "$ROOT/$ABL_FILE" | cut -d' ' -f1); B=$(sha256sum /tmp/vp.bin | cut -d' ' -f1)
  echo "expected=$A"; echo "readback=$B"
  [ "$A" = "$B" ] || die "ABL read-back MISMATCH"
  say "ABL write verified"
  $ADB reboot bootloader; sleep 3
  wait_fastboot || die "no fastboot"
  timeout 60 $FB getvar all > "$DEVICEDIR/fastboot_getvar_eng.txt" 2>&1 || true
  grep -E "unlocked|current-slot|product|security-patch" "$DEVICEDIR/fastboot_getvar_eng.txt" | head -6
  ;;
unlock)
  wait_fastboot || die "device not in fastboot"
  say "flash UNLOCK GPT (partition:4; eng ABL required)"
  RC=0; $FB flash partition:4 "$ROOT/$UNLOCK_GPT" > "$LOGDIR/flash_unlockgpt.log" 2>&1 || RC=$?
  cat "$LOGDIR/flash_unlockgpt.log"
  if [ "$RC" -ne 0 ] || grep -qiE "FAILED|error" "$LOGDIR/flash_unlockgpt.log"; then die "unlock GPT flash failed — eng ABL not active?"; fi
  say "boot trigger image"
  timeout 90 $FB boot "$ROOT/$TRIGGER_IMG" > "$LOGDIR/fastboot_boot_trigger.log" 2>&1 || true; cat "$LOGDIR/fastboot_boot_trigger.log"
  for i in $(seq 1 150); do $FB devices 2>/dev/null | grep -q . && break; sleep 2; done
  $FB devices 2>/dev/null | grep -q . || die "no fastboot — user must hold Power+VolumeDown to re-enter fastboot"
  RC=0; timeout 30 $FB oem device-info > "$DEVICEDIR/device_info_after.txt" 2>&1 || RC=$?
  cat "$DEVICEDIR/device_info_after.txt"
  [ "$RC" = 0 ] || timeout 20 $FB getvar unlocked > "$DEVICEDIR/getvar_unlocked.txt" 2>&1
  if cat "$DEVICEDIR/device_info_after.txt" "$DEVICEDIR/getvar_unlocked.txt" 2>/dev/null | grep -qiE "unlocked: (true|yes)"; then
    say "BOOTLOADER UNLOCKED"
  else
    say "still locked — re-run trigger (fastboot boot trigger.img), or retry"
  fi
  timeout 60 $FB erase frp > "$LOGDIR/fastboot_erase_frp.log" 2>&1 || true; cat "$LOGDIR/fastboot_erase_frp.log"
  say "restore FACTORY GPT"
  RC=0; $FB flash partition:4 "$ROOT/$FACTORY_GPT" > "$LOGDIR/flash_factorygpt.log" 2>&1 || RC=$?
  cat "$LOGDIR/flash_factorygpt.log"
  if [ "$RC" -ne 0 ] || grep -qiE "FAILED|error" "$LOGDIR/flash_factorygpt.log"; then die "factory GPT restore failed"; fi
  say "restore STOCK ABL to both slots (from backups)"
  timeout 60 $FB flash abl_a "$BACKUP_DIR/bk_abl_a.bin" > "$LOGDIR/flash_abl_a_stock.log" 2>&1 || true; cat "$LOGDIR/flash_abl_a_stock.log"
  timeout 60 $FB flash abl_b "$BACKUP_DIR/bk_abl_b.bin" > "$LOGDIR/flash_abl_b_stock.log" 2>&1 || true; cat "$LOGDIR/flash_abl_b_stock.log"
  timeout 60 $FB getvar all > "$DEVICEDIR/fastboot_getvar_final.txt" 2>&1 || true
  grep -E "unlocked|current-slot|product|security-patch" "$DEVICEDIR/fastboot_getvar_final.txt" | head -6
  ;;
reflash)
  [ -n "$ROM_DIR" ] || die "set ROM_DIR (extracted stock fastboot ROM)"
  [ -f "$ROOT/$ROM_DIR/flash_all.sh" ] || die "flash_all.sh not in ROM_DIR"
  wait_fastboot || die "device not in fastboot"
  say "running $ROM_DIR/flash_all.sh (reflashes boot chain + vbmeta/pvmfw + userdata + misc)"
  ( cd "$ROOT/$ROM_DIR" && export PATH="$ROOT/tools/platform-tools:$PATH" && bash flash_all.sh > "$LOGDIR/flash_all_run.log" 2>&1 & echo started )
  echo "reflash launched; monitor $LOGDIR/flash_all_run.log"
  ;;
verify)
  wait_fastboot || die "device not in fastboot"
  timeout 60 $FB reboot >/dev/null 2>&1 || true
  wait_adb || die "no adb after reboot (bootloop) — reflash stock ROM (reflash phase)"
  for p in ro.product.device ro.build.version.incremental ro.build.version.security_patch ro.boot.flash.locked ro.boot.vbmeta.device_state ro.boot.verifiedbootstate; do
    echo "$p: $($ADB shell getprop $p)"
  done
  say "success expected: flash.locked=0, vbmeta.device_state=unlocked"
  ;;
*) echo "usage: $0 precheck|permissive|backup|abl|unlock|reflash|verify"; exit 1;;
esac
