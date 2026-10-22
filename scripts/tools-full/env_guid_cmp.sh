#!/usr/bin/env bash
set -u
python3 - <<'PY'
import struct
def guid(b):
    d1,d2,d3 = struct.unpack('<IHH', b[:8])
    return f"{d1:08X}-{d2:04X}-{d3:04X}-{b[8]:02X}{b[9]:02X}-{''.join(f'{x:02X}' for x in b[10:16])}"

ufs = '/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi'
env = '/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/EnvDxe/EnvDxe.efi'
u = open(ufs,'rb').read()
e = open(env,'rb').read()

print("UFSDxe @0x1c278:", u[0x1c278:0x1c288].hex(), "=", guid(u[0x1c278:0x1c288]))
print("EnvDxe @0x0e1c8:", e[0x0e1c8:0x0e1d8].hex(), "=", guid(e[0x0e1c8:0x0e1d8]))
print("EnvDxe @0x0e098:", e[0x0e098:0x0e0a8].hex(), "=", guid(e[0x0e098:0x0e0a8]))
print("EnvDxe @0x0e118 (gate HOB):", e[0x0e118:0x0e128].hex(), "=", guid(e[0x0e118:0x0e128]))
print()
print("known: gEfiDtbExtensionHobGuid   = 3A06E1E8-61F6-11EB-BBED-4B476E2FF6A7")
print("known: gEfiShimLibraryHobGuid    = ?")
print("known: gEfiInfoBlkHobGuid        = ?")
print("known: gEfiProdmodeHobGuid       = ?")
print("known: gEfiSchedulerInterfaceHobGuid / gEfiFvListHobGuid = ?")
PY
echo "=== QcomPkg.dec HOB guids ==="
grep -nE 'HobGuid' /root/k70/uefi/Silicon/Qualcomm/QcomPkg/QcomPkg.dec
