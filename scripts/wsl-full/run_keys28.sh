#!/bin/bash
# keys28 = keys27 + keep the Scheduler Interface HOB (EnvDxe needs it) while still skipping the
#          faulting CreateFvList() call.
#
# Evidence (keys27 real device, 00:16):
#   Loading driver at 0x000C7091000 EntryPoint=0x000C7092000 EnvDxe.efi
#   ASSERT_EFI_ERROR (Status = Not Found)
#   ASSERT AutoGen.c +507: !EFI_ERROR (Status)
# EnvDxe.efi embeds gEfiSchedulerInterfaceHobGuid @0xe340 but does NOT embed
# gEfiFvListHobGuid -> keys24/27 dropped the whole scheduler block, so EnvDxe's
# scheduler-interface init returned EFI_NOT_FOUND and the driver failed its entry point.
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl

PP=/root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c
cp "$PP" /tmp/PlatformPei.c.bak28
trap 'cp /tmp/PlatformPei.c.bak28 "$PP"' EXIT

python3 - "$PP" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
old = (
"    // Get Scheduler Interface Protocol\n"
"    EFI_KERNEL_PROTOCOL *SchedulerProtocol = (EFI_KERNEL_PROTOCOL *)SchedulerInterfaceAddr;\n"
"\n"
"    // Create FV List\n"
"    UINTN *FvListAddr = CreateFvList (SchedulerProtocol);\n"
"    if (FvListAddr != NULL) {\n"
"      // Build FV List HOB\n"
"      BuildGuidDataHob (&gEfiFvListHobGuid, &FvListAddr, sizeof (FvListAddr));\n"
"    }\n"
)
new = (
"    // keys28: SchedulerInterfaceAddr points at a GUID table entry, not a callable\n"
"    // EFI_KERNEL_PROTOCOL, so CreateFvList() faults (keys23: Synchronous Exception at\n"
"    // 0xA7102B98).  EnvDxe only consumes the Scheduler Interface HOB itself and never looks\n"
"    // up gEfiFvListHobGuid, so publish the HOB above and skip FV-list creation entirely.\n"
)
assert old in s, "scheduler FV-list block not found"
s = s.replace(old, new, 1)
p.write_text(s, encoding="utf-8")
print("patched PlatformPei.c: Scheduler HOB kept, CreateFvList() skipped")
PY

bash build_keys25.sh keys28 2>&1 | tail -14
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys28.fd keys28 2>&1 | tail -8
echo "===== ARTIFACTS ====="
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys28*.img 2>/dev/null
sha256sum /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys28*.img 2>/dev/null
