#!/bin/sh
# Shared helpers for the UBL unlock methods (lower/rollback and higher/CVE).
# Expects env from config.sh: FB, ADB, METHOD, MQSAS_SERVICE, LOGDIR, DEVICEDIR.
say(){ echo "##### $*"; }
die(){ echo "!!!!! ABORT: $*" >&2; exit 1; }

wait_fastboot(){ for i in $(seq 1 60); do $FB devices 2>/dev/null | grep -q . && return 0; sleep 2; done; return 1; }
wait_adb(){ for i in $(seq 1 120); do $ADB shell true 2>/dev/null && return 0; sleep 3; done; return 1; }
wait_permissive(){ for i in $(seq 1 120); do E=$($ADB shell getenforce 2>/dev/null); case "$E" in *Permissive*) return 0;; *Enforcing*) return 1;; esac; sleep 3; done; return 1; }

# Root command exec via the Xiaomi diagnostic service (lower path).
mqsas_cmd(){ # $1=cmd  $2=args  $3=label
  say "mqsas [$3]: $1 $2"
  $ADB shell "service call $MQSAS_SERVICE 21 i32 1 s16 '$1' i32 1 s16 '$2' s16 '/data/mqsas/log.txt' i32 60" 2>&1 | tee "$LOGDIR/mqsas_$3.log"
}
# Root command exec via su (higher path, after preload.so/ghostlock root).
su_cmd(){ # $1=cmd  $2=args  $3=label
  say "su [$3]: $1 $2"
  $ADB shell "su -c '$1 $2'" 2>&1 | tee "$LOGDIR/su_$3.log"
}
# Root dd dispatcher: lower -> mqsas service, higher -> su.
root_dd(){ # $1=dd args  $2=label
  case "$METHOD" in
    higher) su_cmd dd "$1" "$2";;
    *)      mqsas_cmd dd "$1" "$2";;
  esac
}
root_chmod(){ # $1=chmod args (e.g. "644 /data/local/tmp/x")
  case "$METHOD" in
    higher) su_cmd chmod "$1" chmod;;
    *)      mqsas_cmd chmod "$1" chmod;;
  esac
}
