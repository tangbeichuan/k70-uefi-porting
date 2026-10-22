#!/usr/bin/env bash
# Audit the PCDs the vermeer firmware actually trusts, and check whether the shipping build
# really has the QEMU overrides compiled out. Read-only.
set +e
UEFI=/root/k70/uefi
DSC=$UEFI/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
KAILUA=$UEFI/Silicon/Qualcomm/KailuaPkg/KailuaPkg.dsc.inc
MEMLIB=$UEFI/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c

echo "===== 1. gating in the as-built dsc (is the QEMU block inert?) ====="
grep -n 'QEMU_BRINGUP\|VERMEER_BANNER\|VERMEER_PAINT\|VERMEER_VENDOR_HW\|!if\|!endif\|\[PcdsFixedAtBuild' "$DSC"

echo
echo "===== 2. every PCD line in the dsc, with line numbers ====="
grep -n 'g[A-Za-z]*TokenSpaceGuid\.' "$DSC"

echo
echo "===== 3. PCDs inherited from KailuaPkg.dsc.inc ====="
grep -n 'g[A-Za-z]*TokenSpaceGuid\.' "$KAILUA"

echo
echo "===== 4. who consumes PcdSystemMemorySize / PcdSystemMemoryBase ====="
grep -rn 'PcdSystemMemorySize\|PcdSystemMemoryBase' "$UEFI/ArmPkg" "$UEFI/Platforms/Xiaomi/vermeerPkg" "$UEFI/Silicon/Qualcomm/KailuaPkg" 2>/dev/null | head -30

echo
echo "===== 5. who consumes PcdFdBaseAddress / PcdFdSize ====="
grep -rn 'PcdFdBaseAddress\|PcdFdSize' "$UEFI/Platforms/Xiaomi/vermeerPkg" "$UEFI/Silicon/Qualcomm/KailuaPkg" 2>/dev/null | head -20

echo
echo "===== 6. how the DRAM size reaches the firmware ====="
grep -rn 'dram\|DRAM\|MemorySize\|TotalDramSize' "$MEMLIB" | head -20
echo "--- MemoryMapLib region count ---"
grep -c '^ *{' "$MEMLIB"

echo
echo "===== 7. does anything read the DTB for memory? ====="
grep -rln 'DtPlatformDxe\|FdtLib' "$UEFI/Platforms/Xiaomi/vermeerPkg" 2>/dev/null
echo "(DtPlatformDxe is gated off in the shipping fdf; check the fdf)"
grep -n 'DtPlatformDxe\|FdtBlob\|DtPlatform' "$UEFI/Platforms/Xiaomi/vermeerPkg/vermeer.fdf"

echo
echo "===== 8. EFI_FIRMWARE_VOLUME / FD defines in the fdf ====="
grep -n 'FD_BASE\|FD_SIZE\|FD_BLOCKS\|BlockSize\|FvNameGuid' "$UEFI/Platforms/Xiaomi/vermeerPkg/vermeer.fdf"

echo
echo "===== 9. PCD database actually baked into the shipping FD ====="
python3 - "$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd" <<'PY'
import sys, struct
p = sys.argv[1]
d = open(p,'rb').read()
# find the PCD DXE module by GUID is hard; instead search .text of PcdDxe? Simpler: report
# whether the QEMU GIC address 0x08000000/0x080A0000 appears as a little-endian qword pair.
for name, val in (('QEMU GICD 0x08000000', 0x08000000), ('QEMU GICR 0x080A0000', 0x080A0000),
                  ('phone GICD 0x17100000', 0x17100000), ('phone GICR 0x17180000', 0x17180000)):
    b = struct.pack('<Q', val)
    print(f'  {name:24s} occurrences in FD: {d.count(b)}')
PY
