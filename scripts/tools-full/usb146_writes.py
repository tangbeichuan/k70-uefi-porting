#!/usr/bin/env python3
"""usb146_writes.py -- find code that writes the interesting globals.

Part A (HALIOMMUDxe): every instruction sequence that addresses 0xd0b8..0xd150
(the HAL IOMMU protocol interface struct) - loads AND stores - plus every gBS
InstallMultipleProtocolInterfaces / UninstallProtocolInterface call site and
every reference to GUID 54B6D3B4 (0xd068).

Part B (UsbConfigDxe): every store whose destination could be 0x13768 (gIommu),
0x13770 (gIommuCtx) or 0x13780..0x13781 flags.
"""
import re
import subprocess
import sys

HAL = "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi"
UCFG = "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"

LINE = re.compile(r"^\s*([0-9a-f]+):\s+([0-9a-f]+)\s+\t?(\S+)\s*(.*)$")


def dis(path):
    out = subprocess.run(["llvm-objdump", "-d", "--no-show-raw-insn", path],
                         capture_output=True, text=True).stdout
    ins = []
    for ln in out.splitlines():
        m = LINE.match(ln)
        if m:
            ins.append((int(m.group(1), 16), m.group(3), m.group(4).strip()))
    return ins


def reg_follow(ins, i, reg, n=6):
    """walk backwards from index i to find the adrp/add chain defining reg."""
    for j in range(i - 1, max(-1, i - n - 1), -1):
        addr, mn, ops = ins[j]
        if mn == "adrp" and ops.startswith(reg + ","):
            return j, addr
        if mn == "add" and ops.startswith(reg + "," + reg + ","):
            continue
    return None, None


def imm(op):
    m = re.search(r"#(0x[0-9a-f]+|\d+)", op)
    return int(m.group(1), 0) if m else None


def base_of(ins, i):
    """For instruction i with ops like 'x8, [x8, #0x768]', return (reg, offset,
    adrp page) after walking back adrp/add chains for the base register."""
    addr, mn, ops = ins[i]
    m = re.match(r"(\w+),\s*\[(\w+)(?:,\s*#(0x[0-9a-f]+|\d+))?\]!", ops)
    if m:
        dst, base, off = m.group(1), m.group(2), int(m.group(3), 0) if m.group(3) else 0
    else:
        m = re.match(r"(\w+),\s*\[(\w+)(?:,\s*#(0x[0-9a-f]+|\d+))?\]", ops)
        if not m:
            return None
        dst, base, off = m.group(1), m.group(2), int(m.group(3), 0) if m.group(3) else 0
    page = 0
    for j in range(i - 1, max(-1, i - 30), -1):
        a, mn2, ops2 = ins[j]
        if mn2 == "adrp" and ops2.startswith(base + ","):
            page = imm(ops2)
            break
        if mn2 in ("ldr", "str", "mov", "add") and re.search(r"\b" + base + r",", ops2):
            if mn2 == "mov":
                break
            if mn2 == "add" and ops2.startswith(base + "," + base + ","):
                v = imm(ops2)
                if v is not None:
                    page += v
                break
            if mn2 == "adrp":
                continue
            break
    if page:
        return page + off
    return None


def scan(path, label, targets):
    ins = dis(path)
    print("==", label, path, len(ins), "insns")
    for i, (addr, mn, ops) in enumerate(ins):
        if mn not in ("ldr", "str", "ldrb", "strb", "ldur", "stur", "ldrh", "strh",
                      "ldrsw", "ldp", "stp"):
            continue
        t = base_of(ins, i)
        if t is None:
            continue
        for name, lo, hi in targets:
            if lo <= t <= hi:
                print("  %08x  %-6s %-40s -> %s+0x%x" % (addr, mn, ops, name, t - lo))
    # Install/Uninstall protocol calls: gBS +0x148 / +0x150 / +0x88(HandleProtocol) etc.
    print("  -- gBS call-ish sites (ldr x?,[x?,#0x1xx] then blr) --")
    for i, (addr, mn, ops) in enumerate(ins):
        if mn != "ldr":
            continue
        t = base_of(ins, i)
        if t is None:
            continue
        if 0x140 <= t <= 0x1b0:
            print("  %08x  %-6s %-40s (gBS+0x%x)" % (addr, mn, ops, t))


scan(HAL, "HALIOMMUDxe",
     [("iface", 0xd0b8, 0xd150), ("GUID54B6D3B4", 0xd068, 0xd078),
      ("GUID_DTBEXTN", 0xd098, 0xd0a0)])
print()
scan(UCFG, "UsbConfigDxe",
     [("gIommu", 0x13768, 0x13770), ("gIommuCtx", 0x13770, 0x13778),
      ("gIommuBuf", 0x13778, 0x13780), ("flags", 0x13780, 0x13782),
      ("gSdt", 0x137c8, 0x137d0), ("gClock", 0x137d8, 0x137e0)])
