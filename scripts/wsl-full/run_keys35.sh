#!/bin/bash
# keys35 = keys32/keys34 baseline (real PlatformPeiLib + CompareGuid fix + probe last in APRIORI,
#           stock 192-byte BootShim) with the driver dumping the structures the HOB payloads
#           point at (Info Blk / Shim / Scheduler / DtbExtn).
set -u
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1
TAG=keys35

python3 - <<'PY'
import pathlib
src = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys25.sh')
out = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys35.sh')
s = src.read_text()
assert 'keys25' in s
s = s.replace('keys25', 'keys35')
out.write_text(s)
print('derived', out)
PY

# PlatformPei.c: keep the Scheduler-Interface HOB, drop only the CreateFvList/FvList-HOB part.
python3 - <<'PY'
import pathlib
p = pathlib.Path('/root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c')
bak = pathlib.Path('/tmp/PlatformPei.c.bak35')
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
    s = s.replace(old, new, 1)
    p.write_text(s, errors='surrogateescape')
    print('patched PlatformPei.c')
elif 'keys28+: keep the Scheduler Interface HOB' in s:
    print('PlatformPei.c already patched')
else:
    raise SystemExit('PlatformPei.c anchor not found')
PY

bash build_keys35.sh "$TAG" || exit 1
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd "$TAG" || exit 1

cp /tmp/PlatformPei.c.bak35 /root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c
echo "=== keys35 done ==="
