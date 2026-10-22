#!/usr/bin/env python3
"""keys146: keys145 lineage (ClockDxe + HALIOMMU + teardown NULL guard) PLUS a
real fix for the broken EFI_ERROR test at UsbConfigDxe RVA 0x3FA8.

Background (verified against keys145 FV payload and the pristine Binaries copy):

    3f98  blr  x8                    ; gBS->LocateProtocol (HAL IOMMU 54B6D3B4)
    3f9c  mov  w8, w0                ; 32-bit: EFI_NOT_FOUND 0x800000000000000E
    3fa0  stur w8, [x29, #-0x24]     ;   becomes w8 = 0x0000000E (bit63 lost)
    3fa8  tbz  w8, #0x1f, 0x3fe8     ; keys143's "hardening": tests bit31 of w8,
                                     ; but 0x0E has bit31 = 0 -> STILL takes the
                                     ; success path when LocateProtocol failed.
    3fb0  ... vendor "no IOMMU" branch: clear gIommu, DebugPrint, b 0x41c4
    3fe8  ldr  x8, [gIommu]          ; success path (only reachable from 3fa8)
    3ff0  ldr  x8, [x8, #0x8]        ; keys144 crash: gIommu == NULL -> FAR=0x8
    4000  blr  x8                    ; keys145 crash: [gIommu+8] == ASCII
                                     ; "transact" -> pc = 0x746361736E617274

keys144 crashed at 0x3FF0 because LocateProtocol had FAILED (HALIOMMU absent) and
the 0x3FA8 "fix" still fell through to the success path.  keys145 restored the
producer, so LocateProtocol now returns EFI_SUCCESS, but the value stored in
gIommu is such that [gIommu+8] reads ASCII "transact" -- i.e. the interface
pointer the DXE core hands back is not the HALIOMMU protocol interface
(HALIOMMU's own static interface is at .data VA 0xd0b8: UINT32 version
0x00010002 at +0, then 17 relocated function pointers; .reloc type 10 covers
exactly 0xd0c0..0xd140, so [interface+8] *should* be HAL_base+0x1720).

Rather than guess at the corrupt pointer, keys146 takes the vendor's own
"IOMMU unavailable" branch unconditionally: 0x3FA8 becomes

    3fa8  b 0x3fb0                   ; always: clear gIommu, print, skip init

The vendor designed 0x3FB0 for exactly this situation (it clears the global,
prints a diagnostic and jumps to 0x41C4 which returns EFI_SUCCESS), and every
later IOMMU user is guarded by the flag byte at .data 0x13780 / 0x13781, which
therefore stays 0: the 0x4080/0x4108 map path and the 0x5364 teardown path both
check the flag before dereferencing gIommu/gIommuCtx.  The keys145 guard at
0x53CC (cbz x8,0x53f0) is kept as belt-and-braces.

Expected new debug line on hardware:
    Failed to open HAL IOMMU protocol Status = (0x0)
(Status is 0x0 because LocateProtocol actually succeeded - the line is our
forced-fallback marker, not a real locator failure.)

File offset == RVA for this image (.text VA=0x1000 raw=0x1000).
run146.sh backs the .efi up to /tmp/...bak146 and restores it after the build.
"""
import os
import sys

UCFG = "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"

# (offset, expected current u32, patched u32, comment)
PATCHES = [
    (0x3FA8, 0x36F80208, 0x14000002,
     "tbz w8,#0x1f,0x3fe8  ->  b 0x3fb0 (force vendor no-IOMMU path)"),
]

# must already be present from patch_usb145
EXPECT_53CC = 0xB4000128   # cbz x8,0x53f0
EXPECT_53D0 = 0xF9400508
EXPECT_3FE8 = 0x90000088   # adrp x8,0x13000 (success-path entry, untouched)

_fail = []


def die(msg):
    _fail.append(msg)
    print("PATCH_USB146 FATAL: " + msg)


def main():
    print("=== patch_usb146: force the vendor no-IOMMU branch (real EFI_ERROR fix) ===")
    if not os.path.exists(UCFG):
        die("UsbConfigDxe.patched.efi missing")
        sys.exit(1)
    data = bytearray(open(UCFG, "rb").read())

    # sanity: keys145's guard must be in place (we keep it, never undo it)
    for off, want, note in ((0x53CC, EXPECT_53CC, "keys145 teardown guard"),
                            (0x53D0, EXPECT_53D0, "keys145 teardown guard"),
                            (0x3FE8, EXPECT_3FE8, "success-path entry")):
        cur = int.from_bytes(data[off:off + 4], "little")
        if cur != want:
            die("0x%04X unexpected 0x%08X (want 0x%08X, %s) - run patch_usb145 first"
                % (off, cur, want, note))

    for off, old, new, note in PATCHES:
        cur = int.from_bytes(data[off:off + 4], "little")
        if cur == old:
            data[off:off + 4] = new.to_bytes(4, "little")
            print("  UsbConfigDxe 0x%04x: 0x%08X -> 0x%08X  (%s)" % (off, old, new, note))
        elif cur == new:
            print("  UsbConfigDxe 0x%04x: already patched (0x%08X)" % (off, new))
        else:
            die("UsbConfigDxe 0x%04x unexpected: 0x%08X (want 0x%08X)"
                % (off, cur, old))

    if _fail:
        print("PATCH_USB146 FAILED")
        sys.exit(1)
    open(UCFG, "wb").write(bytes(data))
    print("PATCH_USB146 OK")
    print("  NOTE: forced fallback keeps flag .data 0x13780/0x13781 == 0, so the")
    print("        0x4080 map path and the 0x5364 teardown path stay disabled.")


if __name__ == "__main__":
    main()
