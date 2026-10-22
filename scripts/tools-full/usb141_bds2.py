#!/usr/bin/env python3
"""PE section parser + GUID xref inspector (no llvm-readobj dependency)."""
import os
import re
import struct
import subprocess

GUIDS = {
    "EB97088E-CFDF-49C6-BE4B-D906A5B20E86": "EB97088E",
    "E722B03F-B250-42CE-8EBD-5BD51812D037": "E722B03F",
    "B0760469-970C-487A-A4B5-28DB7B45CEF1": "ChipInfo",
    "FA5F306B-F47D-4AC4-A47D-882F8204EC30": "SPMI",
    "F4E5C7D0-D239-47CB-AACD-7F66EF763238": "SMEM",
    "157A5C45-21B2-43C5-BA7C-822FEE5FE599": "PlatformInfo",
    "4684800A-2755-4EDC-B443-7F8CEB3239D3": "PmicVersion",
}


def gb(s):
    q = s.split("-")
    return struct.pack("<IHH", int(q[0], 16), int(q[1], 16), int(q[2], 16)) + bytes.fromhex(q[3] + q[4])


def pe_sections(data):
    e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
    nsec = struct.unpack_from("<H", data, e_lfanew + 6)[0]
    opt = struct.unpack_from("<H", data, e_lfanew + 20)[0]
    base = e_lfanew + 24 + opt
    secs = []
    for i in range(nsec):
        o = base + i * 40
        name = data[o:o + 8].rstrip(b"\0").decode("latin1")
        vsize, va, rsize, roff = struct.unpack_from("<IIII", data, o + 8)
        secs.append({"name": name, "va": va, "vsize": vsize, "rsize": rsize, "roff": roff})
    return secs


def inspect(efi, targets):
    print("\n===== %s =====" % os.path.basename(efi))
    data = open(efi, "rb").read()
    secs = pe_sections(data)
    print("  sections:", [(s["name"], hex(s["va"]), hex(s["roff"]), hex(s["rsize"])) for s in secs])

    def off_to_va(off):
        for s in secs:
            if s["roff"] <= off < s["roff"] + s["rsize"]:
                return s["va"] + (off - s["roff"])
        return None

    vas = {}
    for g, nm in targets.items():
        pat = gb(g)
        pos = data.find(pat)
        while pos >= 0:
            va = off_to_va(pos)
            if va is not None:
                vas.setdefault(va, []).append((nm, pos))
            pos = data.find(pat, pos + 1)
    for va, lst in sorted(vas.items()):
        print("  GUID %-14s VA=0x%x file=0x%x" % (lst[0][0], va, lst[0][1]))

    out = subprocess.run(["llvm-objdump", "-d", "--no-show-raw-insn", efi], capture_output=True, text=True).stdout
    insns = []
    for ln in out.splitlines():
        m = re.match(r"^\s*([0-9a-f]+):\s+(.*)$", ln)
        if m:
            insns.append((int(m.group(1), 16), m.group(2).strip()))
    target_vas = set(vas.keys())
    for i, (addr, txt) in enumerate(insns):
        m = re.match(r"adrp\s+(x\d+),\s+0x([0-9a-f]+)", txt)
        if not m:
            continue
        reg, page = m.group(1), int(m.group(2), 16)
        for j in range(i + 1, min(i + 6, len(insns))):
            t2 = insns[j][1]
            m2 = re.match(r"add\s+%s,\s+%s,\s+#0x([0-9a-f]+)" % (reg, reg), t2)
            if not m2:
                if t2.startswith(("adrp", "ldr", "blr", "bl ", "ret", "b ")):
                    break
                continue
            va = page + int(m2.group(1), 16)
            if va in target_vas:
                print("\n  --- ref to %s (0x%x) from 0x%x ---" % (vas[va][0][0], va, addr))
                for k in range(max(0, i - 3), min(len(insns), j + 10)):
                    print("   %s %06x: %s" % (">>" if k == j else "  ", insns[k][0], insns[k][1]))
            break


BDS = None
for root, dirs, files in os.walk("/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB"):
    if "BdsDxe.efi" in files:
        BDS = os.path.join(root, "BdsDxe.efi")
        break
print("BdsDxe path:", BDS)
if BDS:
    inspect(BDS, {"EB97088E-CFDF-49C6-BE4B-D906A5B20E86": "EB97088E"})
inspect("/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi", GUIDS)
