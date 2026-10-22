#!/usr/bin/env bash
# Build a QEMU-only variant of the firmware that ALSO routes DEBUG output to a real PL011
# UART, so the QEMU run can be captured as plain text instead of being OCR'd off a 43 MiB
# framebuffer dump.
#
# Why this is worth doing: on the phone the only output channel is the framebuffer, and the
# QEMU run currently dies somewhere after ArmGicDxe with an exception dump. Reading that
# dump as pixels is workable but slow; with -serial file: the same log becomes a text file.
#
# The stock platform uses FrameBufferSerialPortLib (SiliciumPkg.dsc.inc:162). QEMU `virt`
# has a PL011 at 0x09000000 with a 24 MHz clock, so PL011SerialPortLib + PL011UartLib +
# PL011UartClockLib from ArmPlatformPkg (inside Mu_Basecore) is all that is needed.
set -uo pipefail
UEFI=/root/k70/uefi
DSC=$UEFI/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
DSC_BAK=/root/k70/vermeer.dsc.pre-qemu-serial
OUT=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
FKEEP=$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
mkdir -p "$OUT"
cp -f "$DSC" "$DSC_BAK"

# The stock memory map maps only Qualcomm MMIO.  Once the MMU is on, the PL011 at
# 0x09000000 (and QEMU's GIC) are unmapped, so the serial log stops right after
# "MMU: HOBs built, enabling".  Add those two windows behind the same gate.
MMAPC=$UEFI/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
MMAPC_BAK=/root/k70/MemoryMapLib.c.pre-qemu
cp -f "$MMAPC" "$MMAPC_BAK"
python3 - "$MMAPC" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
if 'QEMU GIC' not in s:
    extra = """#if defined (QEMU_BRINGUP)
  //
  // QEMU `virt` only (see the QEMU_BRINGUP gate in vermeer.dsc): its GICv3 and PL011 UART
  // are at different addresses than SM8550's.  Without these two windows the post-MMU
  // serial log and every GIC access disappear, which is exactly what the first run showed.
  //
  {"QEMU GIC",            0x08000000, 0x00100000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},
  {"QEMU PL011 UART",     0x09000000, 0x00100000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},
#endif
"""
    anchor = '\n};\n\nVOID\nGetMemoryMap'
    assert anchor in s, 'could not find the end of gMemoryDescriptor'
    s = s.replace(anchor, '\n' + extra + '};\n\nVOID\nGetMemoryMap', 1)
    open(p, 'w').write(s)
    print('inserted QEMU MMIO windows into MemoryMapLib.c')
PY

python3 - "$DSC" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()

if 'QEMU_BRINGUP' not in s:
    block = """
# --- QEMU_BRINGUP: only for running this firmware under qemu-system-aarch64 -----------
# `virt` exposes GICv3 at 0x08000000 (distributor) / 0x080A0000 (redistributors), uses
# PPI 29/30 for the secure/non-secure timer interrupts, and a PL011 UART at 0x09000000
# clocked at 24 MHz.  None of this is true on the phone, so it is all behind the gate.
DEFINE QEMU_BRINGUP = 0

!if $(QEMU_BRINGUP) == 1
[PcdsFixedAtBuild.common]
  gArmTokenSpaceGuid.PcdGicDistributorBase|0x08000000
  gArmTokenSpaceGuid.PcdGicRedistributorsBase|0x080A0000
  gArmTokenSpaceGuid.PcdArmArchTimerSecIntrNum|29
  gArmTokenSpaceGuid.PcdArmArchTimerIntrNum|30
  gEfiMdeModulePkgTokenSpaceGuid.PcdSerialRegisterBase|0x09000000
  gArmPlatformTokenSpaceGuid.PL011UartClkInHz|24000000
  gEfiMdePkgTokenSpaceGuid.PcdUartDefaultBaudRate|115200
  gEfiMdeModulePkgTokenSpaceGuid.PcdSerialBaudRate|115200
  gEfiMdeModulePkgTokenSpaceGuid.PcdSerialUseHardwareFlowControl|FALSE
  gEfiMdePkgTokenSpaceGuid.PcdUartDefaultReceiveFifoDepth|0

# a second [LibraryClasses] section later in the file overrides the earlier binding
[LibraryClasses]
  SerialPortLib|ArmPlatformPkg/Library/PL011SerialPortLib/PL011SerialPortLib.inf
  PL011UartLib|ArmPlatformPkg/Library/PL011UartLib/PL011UartLib.inf
  PL011UartClockLib|ArmPlatformPkg/Library/PL011UartClockLib/PL011UartClockLib.inf

# the memory map carries two extra QEMU-only mappings behind this same gate
[BuildOptions]
  *_*_AARCH64_CC_FLAGS = -DQEMU_BRINGUP=1
!endif
# -------------------------------------------------------------------------------------

"""
    anchor = '[Components]'
    assert anchor in s, 'no [Components] section'
    s = s.replace(anchor, block + anchor, 1)
    open(p, 'w').write(s)
    print('inserted QEMU_BRINGUP block (PCDs + PL011 serial)')

s = re.sub(r'DEFINE QEMU_BRINGUP = \d', 'DEFINE QEMU_BRINGUP = 1', s, count=1)
open(p, 'w').write(s)
PY

cd "$UEFI"
source /root/k70/venv/bin/activate
echo "=== building QEMU variant with PL011 serial (QEMU_BRINGUP = 1) ==="
python3 build_uefi.py -d vermeer -m 0 -r DEBUG > /root/k70/qemu-serial-build.log 2>&1
rc=$?
echo "build rc=$rc"
grep -Ei '^ERROR|error [0-9]{4}|not declared|Success' /root/k70/qemu-serial-build.log | tail -8
if [ $rc -eq 0 ] && [ -f "$FKEEP" ]; then
  cp -f "$FKEEP" "$OUT/SILICIUM_UEFI-qemu-serial.fd"
  echo "--- qemu+serial variant ---"
  ls -l "$OUT/SILICIUM_UEFI-qemu-serial.fd"
  sha256sum "$OUT/SILICIUM_UEFI-qemu-serial.fd"
else
  echo "!! qemu+serial build failed; DSC left in place for inspection"
  exit 1
fi

cp -f "$DSC_BAK" "$DSC"
cp -f "$MMAPC_BAK" "$MMAPC"
echo "=== dsc + memory map restored; rebuilding default (phone) FD ==="
python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -3
cp -f "$FKEEP" /root/k70/phone-fd-latest.fd
sha256sum /root/k70/phone-fd-latest.fd
