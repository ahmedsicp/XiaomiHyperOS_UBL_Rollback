# Generic config for the Xiaomi rollback (LOWER) unlock method. Override via env.
export METHOD="${METHOD:-lower}"            # lower | higher (root_dd backend in helpers.sh)
export FBIN="${FBIN:-tools/platform-tools/fastboot}"
export ADBIN="${ADBIN:-adb -d}"
export MQSAS_SERVICE="${MQSAS_SERVICE:-miui.mqsas.IMQSNative}"
export OEM_CMD="${OEM_CMD:-oem set-gpu-preemption 0 androidboot.selinux=permissive}"
export PAYLOAD_DIR="${PAYLOAD_DIR:-payloads}"
export ABL_FILE="${ABL_FILE:-$PAYLOAD_DIR/abl.elf}"            # engineering ABL for the device SoC
export UNLOCK_GPT="${UNLOCK_GPT:-$PAYLOAD_DIR/unlockgpt.bin}"  # unlock GPT (vbmeta->xbmeta / pvmfw->xvmfw)
export FACTORY_GPT="${FACTORY_GPT:-$PAYLOAD_DIR/factory_gpt.bin}" # factory GPT
export TRIGGER_IMG="${TRIGGER_IMG:-$PAYLOAD_DIR/trigger.img}"  # trigger boot image
export BACKUP_DIR="${BACKUP_DIR:-backups}"
export ROM_DIR="${ROM_DIR:-}"              # extracted stock fastboot ROM folder (reflash)
export LOGDIR="${LOGDIR:-logs}"
export DEVICEDIR="${DEVICEDIR:-device}"
