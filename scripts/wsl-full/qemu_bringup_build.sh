#!/usr/bin/env bash
# Build a *QEMU-only* variant of the firmware so the DXE/BDS path can be exercised without
# a phone.
#
# KailuaPkg.dsc.inc hard-codes the SM8550 GIC addresses (0x17100000 / 0x17180000); QEMU's
# `virt` machine puts the GICv3 at 0x08000000 / 0x080A0000, which is why the clean build
# stops at ArmGicV3Dxe.c with EFI_NOT_FOUND (14).  This script appends a
# [PcdsFixedAtBuild.common] override gated by QEMU_BRINGUP, builds once with the gate on,
# saves that FD under a distinct name, then restores the DSC and rebuilds the phone FD.
#
# Only PCDs that ArmPkg declares *and* whose consumers are in the FDF are overridden --
# adding PcdArmArchTimerFreqInHz made the build fail with
#   "Pcd (gArmTokenSpaceGuid.PcdArmArchTimerFreqInHz) defined in DSC is not declared in
#    DEC files referenced in INF files in FDF"
set -uo pipefail
UEFI=/root/k70/uefi
DSC=$UEFI/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
DSC_BAK=/root/k70/vermeer.dsc.pre-qemu
OUT=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
FKEEP=$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
mkdir -p "$OUT"
cp -f "$DSC" "$DSC_BAK"

python3 - "$DSC" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
if 'QEMU_BRINGUP' not in s:
    block = """
# --- QEMU_BRINGUP: only for running this firmware under qemu-system-aarch64 -----------
# `virt` exposes GICv3 at 0x08000000 (distributor) / 0x080A0000 (redistributors) and uses
# PPI 29/30 for the secure/non-secure timer interrupts.
DEFINE QEMU_BRINGUP = 0
!if $(QEMU_BRINGUP) == 1
[PcdsFixedAtBuild.common]
  gArmTokenSpaceGuid.PcdGicDistributorBase|0x08000000
  gArmTokenSpaceGuid.PcdGicRedistributorsBase|0x080A0000
  gArmTokenSpaceGuid.PcdArmArchTimerSecIntrNum|29
  gArmTokenSpaceGuid.PcdArmArchTimerIntrNum|30
!endif
# -------------------------------------------------------------------------------------

"""
    anchor = '[Components]'
    assert anchor in s, 'no [Components] section'
    s = s.replace(anchor, block + anchor, 1)
    open(p, 'w').write(s)
    print('inserted QEMU_BRINGUP block')
s = re.sub(r'DEFINE QEMU_BRINGUP = \d', 'DEFINE QEMU_BRINGUP = 1', s, count=1)
open(p, 'w').write(s)
PY

cd "$UEFI"
source /root/k70/venv/bin/activate
echo "=== building QEMU variant (QEMU_BRINGUP = 1) ==="
if python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -5; then :; fi
if [ -f "$FKEEP" ] && grep -q 'Success' Build/BUILDLOG_vermeerPkg.txt; then
  cp -f "$FKEEP" "$OUT/SILICIUM_UEFI-qemu.fd"
  echo "--- qemu variant ---"
  ls -l "$OUT/SILICIUM_UEFI-qemu.fd"; sha256sum "$OUT/SILICIUM_UEFI-qemu.fd"
else
  echo "!! qemu variant build did not succeed"
fi
rm -f "$OUT/SILICIUM_UEFI-qemu.fd.tmp"

cp -f "$DSC_BAK" "$DSC"
echo "=== dsc restored; rebuilding default (phone) FD ==="
python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -3
cp -f "$FKEEP" /root/k70/phone-fd-latest.fd
sha256sum /root/k70/phone-fd-latest.fd
