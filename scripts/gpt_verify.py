#!/usr/bin/env python3
"""Verify the device GPT (head backup) against the payload factory/unlock GPT files.

Usage: gpt_verify.py <device_gpt_head_backup.bin> <factory_gpt.bin> <unlock_gpt.bin>

Verdicts:
 - factory GPT is safe to flash if the device GPT matches it EXACTLY;
 - unlock GPT is safe to flash if the device GPT matches it modulo the
   vbmeta_a/b -> xbmeta_a/b and pvmfw_a/b -> xvmfw_a/b renames (engineering names).
"""
import struct, sys

def parse(data, what):
    off = data.find(b'EFI PART')
    if off < 0:
        return None, f'{what}: no GPT signature'
    hdr = data[off:]
    ptbl_lba, num, esz, _ = struct.unpack_from('<QIII', hdr, 72)
    for s in (512, 4096):
        eo = ptbl_lba * s
        if 0 <= eo < len(data) and eo + num * esz <= len(data):
            ok, lst = True, []
            for i in range(num):
                e = data[eo + i*esz: eo + (i+1)*esz]
                if len(e) < esz:
                    ok = False; break
                if e[:16] == b'\x00' * 16:
                    continue
                first, last = struct.unpack_from('<QQ', e, 32)
                name = e[56:128].decode('utf-16le', 'ignore').split('\x00')[0]
                if not name or not name.isprintable():
                    ok = False; break
                lst.append((name, first, last))
            if ok and lst:
                return {'entries': lst}, None
    return None, f'{what}: could not parse entries'

def load(path, what):
    try:
        data = open(path, 'rb').read()
    except OSError as e:
        return None, f'{what}: {e}'
    return parse(data, what)

def main():
    if len(sys.argv) < 4:
        print('usage: gpt_verify.py <device_gpt_backup> <factory_gpt> <unlock_gpt>')
        return 2
    dev, e1 = load(sys.argv[1], 'device')
    fac, e2 = load(sys.argv[2], 'factory')
    unl, e3 = load(sys.argv[3], 'unlock')
    if e1 or e2 or e3:
        print('FATAL:', e1 or e2 or e3); return 2
    dE = {(n, f, l) for (n, f, l) in dev['entries']}
    fE = {(n, f, l) for (n, f, l) in fac['entries']}
    uE = {(n, f, l) for (n, f, l) in unl['entries']}
    print('entries: device %d  factory %d  unlock %d' % (len(dE), len(fE), len(uE)))
    ok = 1
    if dE == fE:
        print('OK: device GPT == factory GPT exactly -> factory GPT safe to flash')
    else:
        ok = 0; print('MISMATCH vs factory:')
        for x in sorted(dE - fE)[:10]: print('  device-only:', x)
        for x in sorted(fE - dE)[:10]: print('  factory-only:', x)
    rename = {'vbmeta_a':'xbmeta_a','vbmeta_b':'xbmeta_b','pvmfw_a':'xvmfw_a','pvmfw_b':'xvmfw_b'}
    mE = {(rename.get(n, n), f, l) for (n, f, l) in dE}
    if mE == uE:
        print('OK: device GPT == unlock GPT (modulo vbmeta->xbmeta / pvmfw->xvmfw) -> unlock GPT safe to flash')
    else:
        ok = 0; print('MISMATCH vs unlock:')
        for x in sorted(mE - uE)[:10]: print('  device(mapped)-only:', x)
        for x in sorted(uE - mE)[:10]: print('  unlock-only:', x)
    if ok:
        print('VERDICT: payload GPT files compatible with this device')
    else:
        print('VERDICT: DO NOT flash — layouts differ; investigate')
    return 0 if ok else 1

if __name__ == '__main__':
    sys.exit(main())
