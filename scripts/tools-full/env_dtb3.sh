#!/usr/bin/env bash
set -u
python3 - <<'PY'
import re
lines = open('/tmp/env.dis').read().splitlines()
def va(ln):
    m = re.match(r'^\s*([0-9a-f]+):', ln)
    return int(m.group(1), 16) if m else None

print("=== window 0x2c00 - 0x2c50 ===")
for ln in lines:
    v = va(ln)
    if v is not None and 0x2c00 <= v <= 0x2c50:
        print("  ", ln)

print()
print("=== callers of 0x2ba8 / 0x2b0c-ish helpers ===")
for idx, ln in enumerate(lines):
    m = re.search(r'\bbl\s+0x2ba8\b', ln)
    if m:
        print("---")
        for j in range(max(0, idx - 22), min(len(lines), idx + 6)):
            print("   ", lines[j])

print()
print("=== entry point / driver entry candidates ===")
for idx, ln in enumerate(lines):
    if 'InstallMultipleProtocolInterfaces' in ln:
        print("  ", ln)
PY
