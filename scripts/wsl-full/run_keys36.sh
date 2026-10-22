#!/bin/bash
# keys36 = keys35 的驱动，但探针回到 APRIORI 第 2 位（紧跟 PcdDxe、在 EnvDxe 之前），
#          这样 EnvDxe 再崩也不影响我们把 HOB payload 指向的页 dump 出来。
set -u
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1
TAG=keys36

sed 's|"RscDxe/RscDxe.inf" in line|"MdeModulePkg/Universal/PCD/Dxe/Pcd.inf" in line|; s|keys35|keys36|g' \
  build_keys35.sh > build_keys36.sh
grep -n 'Pcd.inf\|RscDxe' build_keys36.sh | head -5

python3 - <<'PY'
import pathlib
p = pathlib.Path('/root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c')
bak = pathlib.Path('/tmp/PlatformPei.c.bak36')
s = p.read_text(errors='surrogateescape')
bak.write_text(s, errors='surrogateescape')
old = """    // Get Scheduler Interface Protocol
    EFI_KERNEL_PROTOCOL *SchedulerProtocol = (EFI_KERNEL_PROTOCOL *)SchedulerInterfaceAddr;

    // Create FV List
    UINTN *FvListAddr = CreateFvList (SchedulerProtocol);
    if (FvListAddr != NULL) {
      // Build FV List HOB
      BuildGuidDataHob (&gEfiFvListHobGuid, &FvListAddr, sizeof (FvListAddr));
    }
"""
new = """    // keys28+: keep the Scheduler Interface HOB (EnvDxe needs it) but never call into the
    // scheduler.  CreateFvList() dereferences the address as an EFI_KERNEL_PROTOCOL, and what
    // XblProtocols.parse hands back is a rodata address, not a live protocol object.
"""
if old in s:
    p.write_text(s.replace(old, new, 1), errors='surrogateescape')
    print('patched PlatformPei.c')
elif 'keys28+: keep the Scheduler Interface HOB' in s:
    print('PlatformPei.c already patched')
else:
    raise SystemExit('PlatformPei.c anchor not found')
PY

bash build_keys36.sh "$TAG" || exit 1
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd "$TAG" || exit 1
cp /tmp/PlatformPei.c.bak36 /root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c
echo "=== keys36 done ==="
