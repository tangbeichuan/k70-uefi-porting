#!/usr/bin/env python3
"""
patch_clock144.py -- keys144: put ClockDxe back into the FV so that it can
produce gEfiClockProtocolGuid (241AFAE6-885F-4F6C-A7EA-C28EAB79C3E5), which
UsbConfigDxe Locates at runtime (currently logs "DisableUsbClocks:
ClockProtocol unavailable").

Baseline = keys143b (NO_HAL, i.e. HALIOMMU stays out, UsbConfigDxe keeps the
0x3FA8 EFI_ERROR hardening patch).  This script ONLY touches ClockDxe:

  1. Include/DXE.inc   : uncomment the FV placement line
       # [keysNNN-drop]   INF Binaries/vermeer/QcomPkg/Drivers/ClockDxe/ClockDxe.inf
  2. Include/APRIORI.inc: uncomment / (re-)insert the dispatch-order line
     immediately BEFORE the UsbConfigDxe line, so ClockDxe is dispatched
     first and the gEfiClockProtocolGuid exists when UsbConfigDxe starts.

Idempotent.  It runs AFTER patch_usb141.py (which arranges
stub -> UsbConfigDxe -> UsbInitDxe -> UsbMsdDxe) so the insertion point is
stable, and BEFORE patch_fat137.py (which only checks LogDisk/menu).
"""
import io
import os
import sys

PKG = "/root/k70/uefi/Platforms/Xiaomi/vermeerPkg"
DXE = os.path.join(PKG, "Include", "DXE.inc")
APRIORI = os.path.join(PKG, "Include", "APRIORI.inc")
REL = "Binaries/vermeer/QcomPkg/Drivers/ClockDxe/ClockDxe.inf"
CLOCK_LINE = "  INF " + REL


def read(p):
    with io.open(p, "r", encoding="utf-8", newline="") as f:
        return f.read().split("\n")


def write(p, lines):
    with io.open(p, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(lines))


def is_inf_for(line, needle):
    s = line.strip()
    if s.startswith("#"):
        return False
    return s.upper().startswith("INF ") and needle in s


def commented_inf_for(line, needle):
    s = line.strip()
    if not s.startswith("#"):
        return False
    body = s.lstrip("#").strip()
    # strip optional [keysNNN-...] marker
    if body.startswith("["):
        end = body.find("]")
        if end < 0:
            return False
        body = body[end + 1:].strip()
    return body.upper().startswith("INF ") and needle in body


def main():
    if not os.path.exists(os.path.join("/root/k70/uefi", REL)):
        print("[clock144] FATAL: %s missing" % REL)
        return 1

    # ---------------- DXE.inc : FV placement ----------------
    lines = read(DXE)
    done = False
    for i, line in enumerate(lines):
        if is_inf_for(line, "ClockDxe/ClockDxe.inf"):
            print("[clock144] DXE.inc:%d already active -> %s" % (i + 1, line.strip()))
            done = True
            break
        if commented_inf_for(line, "ClockDxe/ClockDxe.inf"):
            print("[clock144] DXE.inc:%d uncomment: %s" % (i + 1, line.strip()))
            lines[i] = CLOCK_LINE
            done = True
            break
    if not done:
        print("[clock144] FATAL: ClockDxe line not found in DXE.inc")
        return 1
    write(DXE, lines)

    # ---------------- APRIORI.inc : dispatch order ----------------
    lines = read(APRIORI)
    cfg_idx = None
    for i, line in enumerate(lines):
        if is_inf_for(line, "UsbConfigDxe/UsbConfigDxe.inf"):
            cfg_idx = i
            break
    if cfg_idx is None:
        print("[clock144] FATAL: active UsbConfigDxe line not found in APRIORI.inc")
        return 1

    # remove any existing ClockDxe line (active or commented), keep it simple
    kept = []
    for line in lines:
        if is_inf_for(line, "ClockDxe/ClockDxe.inf"):
            continue
        if commented_inf_for(line, "ClockDxe/ClockDxe.inf"):
            continue
        kept.append(line)
    lines = kept

    # recompute cfg index after removal
    cfg_idx = None
    for i, line in enumerate(lines):
        if is_inf_for(line, "UsbConfigDxe/UsbConfigDxe.inf"):
            cfg_idx = i
            break
    if cfg_idx is None:
        print("[clock144] FATAL: UsbConfigDxe line vanished in APRIORI.inc")
        return 1

    lines.insert(cfg_idx, CLOCK_LINE)
    write(APRIORI, lines)

    # ---------------- verify ----------------
    lines = read(APRIORI)
    clock_idx = cfg_idx = None
    for i, line in enumerate(lines):
        if is_inf_for(line, "ClockDxe/ClockDxe.inf"):
            clock_idx = i
        if is_inf_for(line, "UsbConfigDxe/UsbConfigDxe.inf"):
            cfg_idx = i
    dxe_lines = read(DXE)
    dxe_ok = any(is_inf_for(l, "ClockDxe/ClockDxe.inf") for l in dxe_lines)
    if clock_idx is None or cfg_idx is None or clock_idx >= cfg_idx or not dxe_ok:
        print("[clock144] FATAL: order/placement wrong (clock=%s cfg=%s dxe=%s)"
              % (clock_idx, cfg_idx, dxe_ok))
        return 1
    print("[clock144] APRIORI.inc ClockDxe line %d < UsbConfigDxe line %d  OK"
          % (clock_idx + 1, cfg_idx + 1))
    # show the dispatch neighbourhood for the build log
    for i in range(max(0, clock_idx - 3), min(len(lines), cfg_idx + 4)):
        print("    %4d: %s" % (i + 1, lines[i].rstrip()))
    print("PATCH_CLOCK144 OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
