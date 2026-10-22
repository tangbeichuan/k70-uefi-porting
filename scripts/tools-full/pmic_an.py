#!/usr/bin/env python3
import re, sys

ASM = "/tmp/pmic/pmic.asm"
lines = open(ASM, encoding="utf-8", errors="replace").read().splitlines()

insns = []  # (addr, text, raw)
pat = re.compile(r'^\s*([0-9a-f]+):\s*(?:[0-9a-f]{8}\s+)?(.*)$')
for ln in lines:
    m = pat.match(ln)
    if m:
        addr = int(m.group(1), 16)
        insns.append((addr, m.group(2).strip(), ln))
by_addr = {a: t for a, t, _ in insns}
sorted_addrs = sorted(by_addr)


def show(s, e):
    print(f"===== {s:x} - {e:x} =====")
    for a, t, raw in insns:
        if s <= a <= e:
            print(f"{a:06x}: {t}")


def at(a):
    return by_addr.get(a)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "show":
        show(int(sys.argv[2], 16), int(sys.argv[3], 16))
