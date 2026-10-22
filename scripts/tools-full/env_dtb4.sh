#!/usr/bin/env bash
set -u
python3 - <<'PY'
import re
lines = open('/tmp/env.dis').read().splitlines()
def va(ln):
    m = re.match(r'^\s*([0-9a-f]+):', ln)
    return int(m.group(1), 16) if m else None
def win(a, b, label):
    print(f"=== {label} 0x{a:x}-0x{b:x} ===")
    for ln in lines:
        v = va(ln)
        if v is not None and a <= v <= b:
            print("  ", ln)
    print()
win(0x2880, 0x2970, "EnvDxe entry / constructor")
win(0x57bc, 0x5840, "helper 0x57bc (returns thing used as gate)")
PY
