#!/bin/bash
# keys29 = keys28 + probe runs BEFORE EnvDxe (right after PcdDxe) and additionally scans the
#           mapped FD window for a 0x10005-worded interface candidate.
#
# keys28 (real device, 00:20) crashed inside EnvDxe:
#   Synchronous Exception at 0x0000000C7097088
#   PC 0x0000C7097088 (0x0000C7091000+0x00006088) [0] EnvDxe.dll   <- ldr x8,[x8] after ldr x8,[x8,#0x58]
#   PC 0x0000C70938F8 (…+0x00002BF8)              [0] EnvDxe.dll   <- inside DTBExtn install
# Install (EnvDxe+0x2ba8) does CopyMem(dst=0xe470, src=*(HOB+0x18), 0x108) then
# InstallMultipleProtocolInterfaces: it expects the HOB value to point at a 0x108-byte interface
# whose word0 == 0x10005.  Our HOB carries the address of a GUID table entry, so the installed
# "interface" is garbage and the first indirect use faults.
#
# So before anyone uses it we want to know whether a real interface (word0 == 0x10005) exists in
# the window at all.  Probe therefore goes back to position 2 (after PcdDxe) and halts.
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl

PP=/root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c
cp "$PP" /tmp/PlatformPei.c.bak29
trap 'cp /tmp/PlatformPei.c.bak29 "$PP"' EXIT

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
"    // keys28+: SchedulerInterfaceAddr points at a GUID table entry, not a callable\n"
"    // EFI_KERNEL_PROTOCOL, so CreateFvList() faults (keys23).  EnvDxe needs the Scheduler\n"
"    // Interface HOB itself but never gEfiFvListHobGuid, so skip FV-list creation.\n"
)
assert old in s, "scheduler FV-list block not found"
p.write_text(s.replace(old, new, 1), encoding="utf-8")
print("patched PlatformPei.c: Scheduler HOB kept, CreateFvList() skipped")
PY

# probe back to position 2: derive from build_keys25.sh (which has the RscDxe anchor)
sed -e 's|"RscDxe/RscDxe.inf" in line|"MdeModulePkg/Universal/PCD/Dxe/Pcd.inf" in line|' build_keys25.sh > build_keys29.sh
grep -n 'Pcd.inf" in line' build_keys29.sh

bash build_keys29.sh keys29 2>&1 | tail -12
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys29.fd keys29 2>&1 | tail -8
echo "===== ARTIFACTS ====="
sha256sum /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys29*.img 2>/dev/null
