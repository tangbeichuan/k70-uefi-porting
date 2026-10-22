#!/usr/bin/env python3
"""
usb145_proto2.py -- improved LocateProtocol/OpenProtocol/HandleProtocol site
enumerator for the USB chain: resolves the GUID operand through either
  adrp xN, page ; add xN, xN, #off        (GUID in .data at VA)
  adrp xN, page ; ldr xN, [xN, #off]      (pointer to GUID stored in .data)
and prints the 8 instructions after the call so the status handling is visible.

usage: python3 usb145_proto2.py <efi> [...]
"""
import os
import re
import struct
import subprocess
import sys

GBS_METHODS = {"0x140": "LocateProtocol", "0x118": "OpenProtocol",
               "0x120": "HandleProtocol", "0x128": "LocateHandleBuffer",
               "0x108": "HandleProtocol?"}


def guid_str(b):
    a, b_, c = struct.unpack("<IHH", b[:8])
    return "%08X-%04X-%04X-%s-%s" % (a, b_, c, b[8:10].hex().upper(), b[10:].hex().upper())


def main(paths):
    for efi in paths:
        data = open(efi, "rb").read()
        asm = subprocess.run(["llvm-objdump", "-d", "--no-show-raw-insn", efi],
                             capture_output=True, text=True).stdout
        ins = []
        for L in asm.split("\n"):
            m = re.match(r"\s*([0-9a-f]+):\s+(\S+)\s*(.*)", L)
            if m:
                ins.append((int(m.group(1), 16), m.group(2), m.group(3).strip()))
        print("\n================ %s (%d B, %d ins)" % (os.path.basename(efi), len(data), len(ins)))
        for i, (a, op, arg) in enumerate(ins):
            if op != "ldr":
                continue
            m = re.match(r"x\d+, \[x\d+, #(0x140|0x118|0x120)\]", arg)
            if not m:
                continue
            off = m.group(1)
            # find blr within next 8 insns
            j, blr = i + 1, None
            while j < min(len(ins), i + 9):
                if ins[j][1] == "blr":
                    blr = ins[j]
                    break
                j += 1
            if blr is None:
                continue
            # register-based GUID tracking: adrp / add / ldr pairs before the site
            adrp = {}
            guid = None
            for k in range(max(0, i - 16), i):
                ka, kop, karg = ins[k]
                m2 = re.match(r"(x\d+), (0x[0-9a-f]+)$", karg)
                if kop == "adrp" and m2:
                    adrp[m2.group(1)] = int(m2.group(2), 16)
                    continue
                m3 = re.match(r"(x\d+), (x\d+), #(0x[0-9a-f]+)$", karg)
                if kop == "add" and m3 and m3.group(1) in ("x0", "x1"):
                    base = adrp.get(m3.group(2))
                    if base is not None:
                        va = base + int(m3.group(3), 16)
                        g = data[va:va + 16]
                        if len(g) == 16:
                            guid = g
                    continue
                m4 = re.match(r"(x\d+), \[(x\d+), #(0x[0-9a-f]+)\]$", karg)
                if kop == "ldr" and m4 and m4.group(1) in ("x0", "x1"):
                    base = adrp.get(m4.group(2))
                    if base is not None:
                        va = base + int(m4.group(3), 16)
                        ptr = struct.unpack("<Q", data[va:va + 8])[0]
                        g = data[ptr:ptr + 16]
                        if len(g) == 16 and g not in (b"\x00" * 16,):
                            guid = g
            kind = GBS_METHODS.get(off, off)
            gs = guid_str(guid) if guid else "(unresolved)"
            print("  %06x %-14s %s" % (a, kind, gs))
            for k in range(j + 1, min(len(ins), j + 9)):
                print("        %06x %-8s %s" % (ins[k][0], ins[k][1], ins[k][2]))


if __name__ == "__main__":
    main(sys.argv[1:])
