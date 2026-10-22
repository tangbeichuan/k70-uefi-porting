#!/usr/bin/env python3
"""Check which protocol GUIDs appear in a given FV/EFI file, and dump 0x7000-0x7200 of UsbConfigDxe."""
import struct
import sys
import subprocess

FV = "/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv"
GUID_NAMES = {
    "B0760469-970C-487A-A4B5-28DB7B45CEF1": "gEfiChipInfoProtocolGuid",
    "FA5F306B-F47D-4AC4-A47D-882F8204EC30": "SPMI(FA5F306B)",
    "F4E5C7D0-D239-47CB-AACD-7F66EF763238": "gEfiSMEMProtocolGuid",
    "157A5C45-21B2-43C5-BA7C-822FEE5FE599": "gEfiPlatformInfoProtocolGuid",
    "EB97088E-CFDF-49C6-BE4B-D906A5B20E86": "EB97088E(unknown)",
    "E722B03F-B250-42CE-8EBD-5BD51812D037": "E722B03F(UsbInitDxe dep)",
    "4684800A-2755-4EDC-B443-7F8CEB3239D3": "gQcomPmicVersionProtocolGuid",
    "3F6C1D92-85B4-4E27-9C63-1A8F5D2E7B04": "VermeerPmicVerStubDxe file guid",
    "CD823A4D-7DEC-4531-AE5D-4134FA4127B8": "UsbConfigDxe file guid",
    "5776232E-082D-4B75-9A0E-FE1D13F7A5D9": "PmicDxe file guid",
}

def gb(s):
    q = s.split('-')
    return struct.pack('<IHH', int(q[0], 16), int(q[1], 16), int(q[2], 16)) + bytes.fromhex(q[3] + q[4])

data = open(FV, "rb").read()
print("FV size = 0x%x" % len(data))
for g, name in GUID_NAMES.items():
    pat = gb(g)
    cnt = data.count(pat)
    print("  %-28s %-38s count=%d" % (g, name, cnt))

print()
print("=== UsbConfigDxe.patched.efi 0x7000-0x7200 ===")
out = subprocess.run(["llvm-objdump", "-d", "--no-show-raw-insn",
                      "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"],
                     capture_output=True, text=True).stdout
import re
for ln in out.splitlines():
    m = re.match(r"^\s*([0-9a-f]+):", ln)
    if m and 0x7000 <= int(m.group(1), 16) <= 0x7200:
        print(ln)
