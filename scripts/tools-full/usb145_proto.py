#!/usr/bin/env python3
"""
usb145_proto.py -- for every USB-chain driver, print each gBS->LocateProtocol /
OpenProtocol / HandleProtocol call site, the GUID it uses (resolved through
adrp+add + .data bytes), and whether the returned status is checked correctly in
the next few instructions (the vendor has a known "ldur w8; tbz x8,#0x3f" bug
where the w-register zero-extension makes the EFI_ERROR check dead code).

usage: python3 usb145_proto.py <efi> [<efi> ...]
"""
import io
import os
import re
import struct
import subprocess
import sys

# -------- GUID name table (subset of .dec declarations we care about) --------
DEC_DIRS = [
    "/root/k70/uefi/QcomPkg", "/root/k70/uefi/Silicon", "/root/k70/uefi/Platforms",
    "/root/k70/uefi/Silicium", "/root/k70/uefi/Mu_Basecore",
]
_guid_names = {}


def load_dec_names():
    pat = re.compile(r"^\s*([A-Za-z0-9_]+)\s*=\s*\{\s*(0x[0-9A-Fa-f]{1,8})\s*,\s*"
                     r"(0x[0-9A-Fa-f]{1,4})\s*,\s*(0x[0-9A-Fa-f]{1,4})\s*,\s*"
                     r"\{\s*([^}]*)\}\s*\}", re.I)
    for root in DEC_DIRS:
        if not os.path.isdir(root):
            continue
        for dirpath, _dirs, files in os.walk(root):
            for fn in files:
                if not fn.lower().endswith(".dec"):
                    continue
                p = os.path.join(dirpath, fn)
                try:
                    txt = io.open(p, "r", encoding="utf-8", errors="ignore").read()
                except OSError:
                    continue
                for line in txt.split("\n"):
                    m = pat.match(line)
                    if not m:
                        continue
                    name = m.group(1)
                    a = int(m.group(2), 16)
                    b = int(m.group(3), 16)
                    c = int(m.group(4), 16)
                    rest = [x.strip() for x in m.group(5).split(",") if x.strip()]
                    try:
                        bs = bytes(int(x, 16) for x in rest)
                    except ValueError:
                        continue
                    if len(bs) != 8:
                        continue
                    key = struct.pack("<IHH", a, b, c) + bs
                    _guid_names[key] = name


def guid_str(b):
    a, b_, c = struct.unpack("<IHH", b[:8])
    return "%08X-%04X-%04X-%s-%s" % (a, b_, c, b[8:10].hex().upper(), b[10:].hex().upper())


def gname(b):
    return _guid_names.get(b, "?")


def sections(efi):
    """return list of (name, va, raw, size) via llvm-readobj --sections"""
    out = subprocess.run(["llvm-readobj", "--sections", efi],
                         capture_output=True, text=True).stdout
    secs = []
    cur = {}
    for line in out.split("\n"):
        line = line.strip()
        if line.startswith("Name:"):
            cur = {"name": line.split(":", 1)[1].strip()}
        elif line.startswith("VirtualAddress:"):
            cur["va"] = int(line.split(":", 1)[1].strip(), 16)
        elif line.startswith("VirtualSize:"):
            cur["vsize"] = int(line.split(":", 1)[1].strip(), 16)
        elif line.startswith("RawDataSize:"):
            cur["raw"] = int(line.split(":", 1)[1].strip(), 16)
        elif line.startswith("PointerToRawData:"):
            cur["off"] = int(line.split(":", 1)[1].strip(), 16)
            secs.append(cur)
    return secs


def read_va(data, secs, va, n):
    for s in secs:
        if "va" in s and s["va"] <= va < s["va"] + max(s.get("vsize", 0), 1):
            off = s.get("off", 0) + (va - s["va"])
            return data[off:off + n]
    # fallback: identity mapping (these PEs usually have raw==va)
    return data[va:va + n]


def main(paths):
    load_dec_names()
    print("dec GUID names loaded: %d" % len(_guid_names))
    for efi in paths:
        data = open(efi, "rb").read()
        secs = sections(efi)
        asm = subprocess.run(["llvm-objdump", "-d", "--no-show-raw-insn", efi],
                             capture_output=True, text=True).stdout
        ins = []
        for L in asm.split("\n"):
            m = re.match(r"\s*([0-9a-f]+):\s+(\S+)\s*(.*)", L)
            if m:
                ins.append((int(m.group(1), 16), m.group(2), m.group(3).strip()))
        print("\n================ %s (%s, %d B)" % (os.path.basename(efi), efi, len(data)))
        # locate gBS pointer first: ldr xN,[xM,#0x6e8]?? no -- find calls via ldr [xN,#0x140]
        sites = []
        for i, (a, op, arg) in enumerate(ins):
            if op != "ldr":
                continue
            m = re.match(r"x\d+, \[(x\d+), #(0x140|0x118|0x120)\]", arg)
            if not m:
                continue
            sites.append((i, a, m.group(2)))
        print("protocol-call sites (ldr [gBS,#off]): %d" % len(sites))
        for i, a, off in sites:
            # find the following blr within 8 insns
            j = i + 1
            blr = None
            while j < min(len(ins), i + 9):
                if ins[j][1] == "blr":
                    blr = ins[j]
                    break
                j += 1
            if blr is None:
                continue
            # walk back to find x0 = adrp+add (GUID) and x2 = &out
            guid = outptr = None
            adrp = {}
            for k in range(max(0, i - 12), i):
                ka, kop, karg = ins[k]
                m2 = re.match(r"(x\d+), (0x[0-9a-f]+)$", karg)
                if kop == "adrp" and m2:
                    adrp[m2.group(1)] = int(m2.group(2), 16)
                m3 = re.match(r"(x\d+), (x\d+), #(0x[0-9a-f]+)$", karg)
                if kop == "add" and m3:
                    dst, src, imm = m3.group(1), m3.group(2), int(m3.group(3), 16)
                    if dst in adrp and src in adrp:
                        va = adrp[dst] + imm
                        if dst in ("x0", "x1", "x2"):
                            raw = read_va(data, secs, va, 16)
                            if len(raw) == 16 and raw not in (b"\x00" * 16,):
                                if dst in ("x0", "x1"):
                                    guid = raw
                                else:
                                    outptr = va
            if guid is None:
                print("  %06x ldr [gBS,#%s] -> blr %06x : GUID not resolved"
                      % (a, off, blr[0]))
                continue
            kind = {"0x140": "LocateProtocol", "0x118": "OpenProtocol",
                    "0x120": "HandleProtocol"}.get(off, off)
            print("  %06x %-14s GUID %s  %s" % (a, kind, guid_str(guid), gname(guid)))
            # show status handling after the call
            for k in range(j + 1, min(len(ins), j + 7)):
                print("        %06x %-8s %s" % (ins[k][0], ins[k][1], ins[k][2]))


if __name__ == "__main__":
    main(sys.argv[1:])
