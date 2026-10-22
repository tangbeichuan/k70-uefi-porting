#!/bin/bash
# keys34 = keys31 with a SAFE interface hunt: keys30/31 died on the stock NoMap window
# (0x80000000+0x01200000 has a reservation HOB but no MMU mapping => FAR=0x80000000,
# ESR=0x96000006 translation fault).  keys34 scans only mapped board windows instead,
# and the most promising one is called "XBL DT" : 0x81A00000 + 0x40000.
#
# Facts driving this build (see keys23..keys29 on-device results):
#  * UEFI-side device trees DO exist, but they live in the xbl_config partition, not in
#    xbl/uefi/vendor_boot:  xbl_config_fdt_cb20.dtb (13893 B) and xbl_config_fdt_10168.dtb
#    (57171 B) both contain /soc/ufs0@1D80000 + init_speed_params/perf_speed_params/timeout_values.
#  * EnvDxe does NOT implement DTBExtn: it CopyMem()s 0x108 bytes from the DTBExtension HOB value
#    into its own .bss template (file offset 0xe470 is all zeros) and re-installs it.  The HOB we
#    get points at a GUID table, so the installed "interface" is garbage.
#  * Therefore the real interface (word0 == 0x10005, non-null subtable at +0x58) must be living in
#    memory owned by XBL, outside the 0xA7000000..0xA7FFFFFF window we scanned so far.
#
# keys34 therefore: dump the memory map (Reserved/RT/ACPI/Persistent only), then scan those
# regions (<= 32 MiB each, 8-byte steps) for 0x10005 with a subtable pointer, then halt so the
# screen keeps the result.  Legacy probe stages are compiled but skipped at runtime.
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl

PP=/root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c
cp "$PP" /tmp/PlatformPei.c.bak34
trap 'cp /tmp/PlatformPei.c.bak34 "$PP"' EXIT

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
"    // EFI_KERNEL_PROTOCOL, so CreateFvList() faults.  EnvDxe needs the Scheduler Interface\n"
"    // HOB itself but never gEfiFvListHobGuid, so skip FV-list creation.\n"
)
assert old in s, "scheduler FV-list block not found"
p.write_text(s.replace(old, new, 1), encoding="utf-8")
print("patched PlatformPei.c: Scheduler HOB kept, CreateFvList() skipped")
PY

# probe early (position 2, right after PcdDxe) so we never depend on UFSDxe surviving
sed -e 's|"RscDxe/RscDxe.inf" in line|"MdeModulePkg/Universal/PCD/Dxe/Pcd.inf" in line|' build_keys25.sh > build_keys34.sh
grep -n 'Pcd.inf" in line' build_keys34.sh

bash build_keys34.sh keys34 2>&1 | tail -14
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys34.fd keys34 2>&1 | tail -8
echo "===== ARTIFACTS ====="
sha256sum /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys34*.img 2>/dev/null
