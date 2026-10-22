#!/bin/bash
# Make build_keys17.sh from build_keys16.sh:
#   keys17 = keys16, but the DT installed is the *real UEFI-side device tree*
#   recovered from the K70's xbl_config partition (model "qcom,kailua"),
#   which is the tree that actually contains /soc/ufs0@1D80000/{init_speed_params,
#   perf_speed_params,timeout_values} — exactly what UFSDxe was failing to find.
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
cp build_keys16.sh build_keys17.sh

python3 - <<'PY'
import pathlib, re
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys17.sh')
s = p.read_text(encoding='utf-8')

# 1) default tag
s = s.replace('TAG=${1:-keys16}', 'TAG=${1:-keys17}')

# 2) header comment
s = s.replace(
"# keys16 = keys15 + the device tree that the port had switched off.",
"# keys17 = keys16 + the REAL UEFI-side device tree from xbl_config (qcom,kailua).\n"
"# keys16 installed the kernel-flavour vermeer DTB (no /soc/ufs0 at all).  The K70's\n"
"# xbl_config partition carries the UEFI DT that stock firmware uses, and its\n"
"# /soc/ufs0@1D80000 node holds init_speed_params / perf_speed_params / timeout_values.\n"
"# This build swaps that blob in (still DtPlatformDxe + DTDUMP probe).\n"
"#\n"
"# keys16 = keys15 + the device tree that the port had switched off.")

# 3) after the fdf patch, swap the FdtBlob blob
anchor = 'print("apriori dt entries inserted:", done)\nPY\n'
assert anchor in s, 'anchor missing'
inject = anchor + '''
# ---- 3b) swap the device tree blob to the real UEFI DT from xbl_config ----
KAILUA=$TOOLS/../_k70_pkg_1019/K70-UEFI-package/extracted/xbl_config_fdt_10168.dtb
[ -f "$KAILUA" ] || { echo "missing kailua DT: $KAILUA"; exit 1; }
cp "$KAILUA" "$PKG/FdtBlob/vermeer-uefi-kailua.dtb"
ls -l "$PKG/FdtBlob/"
sed -i -E 's#^([[:space:]]*SECTION RAW = ).*FdtBlob/.*\\.dtb#\\1vermeerPkg/FdtBlob/vermeer-uefi-kailua.dtb#' "$PKG/vermeer.fdf"
echo "--- fdf FdtBlob lines now ---"
grep -n 'FdtBlob\\|Device Tree\\|25462CDA' "$PKG/vermeer.fdf"
'''
s = s.replace(anchor, inject, 1)

# 4) also verify which DT got embedded
s = s.replace('print("  FDT blobs found:", d.count(b\'\\xd0\\x0d\\xfe\\xed\'))',
 'print("  FDT blobs found:", d.count(b\'\\xd0\\x0d\\xfe\\xed\'))\n'
 'import re as _re\n'
 'print("  ufs0 string in FD:", b"init_speed_params" in d)')

p.write_text(s, encoding='utf-8')
print("written build_keys17.sh")
PY

grep -n 'keys17\|kailua' build_keys17.sh | head -20
