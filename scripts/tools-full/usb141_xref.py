#!/usr/bin/env python3
"""Find adrp+add references to given VAs in a small EFI and print context."""
import re
import subprocess
import sys

EFI = "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"
TARGETS = {
    0x131C8: "EB97088E (unknown)",
    0x13178: "gQcomPmicVersionProtocolGuid",
    0x13148: "FA5F306B (SPMI?)",
    0x130D8: "gEfiChipInfoProtocolGuid",
    0x13198: "gEfiPlatformInfoProtocolGuid",
}

out = subprocess.run(["llvm-objdump", "-d", "--no-show-raw-insn", EFI],
                     capture_output=True, text=True).stdout
lines = out.splitlines()

# collect (addr, text) for instruction lines like "   1a2b0: b 0x..."
insns = []
for ln in lines:
    m = re.match(r"^\s*([0-9a-f]+):\s+(.*)$", ln)
    if m:
        insns.append((int(m.group(1), 16), m.group(2).strip()))

# track adrp register -> page target
hits = []
for i, (addr, txt) in enumerate(insns):
    m = re.match(r"adrp\s+(x\d+),\s+0x([0-9a-f]+)", txt)
    if not m:
        continue
    reg, page = m.group(1), int(m.group(2), 16)
    for j in range(i + 1, min(i + 8, len(insns))):
        a2, t2 = insns[j]
        m2 = re.match(r"add\s+%s,\s+%s,\s+#0x([0-9a-f]+)" % (reg, reg), t2)
        if m2:
            va = page + int(m2.group(1), 16)
            if va in TARGETS:
                hits.append((addr, j, va))
            break
        # mov with page offset?
        m3 = re.match(r"(?:mov|add)\s+%s,\s+%s,\s+#0x([0-9a-f]+)" % (reg, reg), t2)
        if m3:
            break

print("=== adrp+add code references to protocol GUIDs ===")
for addr, j, va in hits:
    print("\n--- %s at 0x%x ---" % (TARGETS[va], addr))
    lo = max(0, j - 6)
    hi = min(len(insns), j + 14)
    for k in range(lo, hi):
        mark = ">>" if k == j else "  "
        print(" %s %06x: %s" % (mark, insns[k][0], insns[k][1]))
