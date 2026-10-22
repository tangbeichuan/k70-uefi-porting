#!/bin/bash
# keys24 = keys23 + stop the PEI crash.
#
# keys23 (real device, 23:49) died with:
#   MMU: enabled
#   Synchronous Exception at 0xA7102B98
# i.e. BEFORE DxeCore, inside PlatformPeim().  Cause: keys23's CompareGuid fix makes
# GetXblHobAddresses() return a NON-zero "scheduler interface" address, and BuildXblHobs then does
#
#   EFI_KERNEL_PROTOCOL *SchedulerProtocol = (EFI_KERNEL_PROTOCOL *)SchedulerInterfaceAddr;
#   UINTN *FvListAddr = CreateFvList (SchedulerProtocol);   // -> SchedulerProtocol->Lock->InitLock(...)
#
# but that address is the *GUID table entry* XBL published, not a callable protocol, so the
# indirect call faults.  Mu builds its own FV HOB anyway, so drop the FV-list path for now and
# keep only the DTB extension HOB — that is the one we need for UFS.
set -e
PP=/root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c
cp "$PP" /tmp/PlatformPei.c.bak24
trap 'cp /tmp/PlatformPei.c.bak24 "$PP"' EXIT

python3 - "$PP" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
old = "  // Check Scheduler Address\n  if (SchedulerInterfaceAddr) {"
new = ("  // keys24: GetXblHobAddresses() hands back a GUID table entry, not EFI_KERNEL_PROTOCOL;\n"
       "  // calling SchedulerProtocol->Lock->InitLock() there faults (Synchronous Exception in PEI).\n"
       "  // Mu builds its own FV HOB, so skip the FV-list path and keep only the DT extension HOB.\n"
       "  if (0) {")
assert old in s, "scheduler block not found"
s = s.replace(old, new, 1)
p.write_text(s, encoding="utf-8")
print("patched PlatformPei.c: scheduler/FV-list path disabled")
PY

bash /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys23.sh keys24
bash /mnt/d/本地项目-01/_k70port_extract/wsl/pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys24.fd keys24 2>&1 | tail -16
echo "===== ARTIFACTS ====="
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys24*.img 2>/dev/null
sha256sum /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys24*.img 2>/dev/null
