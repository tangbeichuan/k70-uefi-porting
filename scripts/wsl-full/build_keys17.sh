#!/usr/bin/env bash
# keys17 = keys16 + the REAL UEFI-side device tree from xbl_config (qcom,kailua).
# keys16 installed the kernel-flavour vermeer DTB (no /soc/ufs0 at all).  The K70's
# xbl_config partition carries the UEFI DT that stock firmware uses, and its
# /soc/ufs0@1D80000 node holds init_speed_params / perf_speed_params / timeout_values.
# This build swaps that blob in (still DtPlatformDxe + DTDUMP probe).
#
# keys16 = keys15 + the device tree that the port had switched off.
#
# keys15 proved on the real device (photos 17:52) that the firmware has NO device tree at all:
#   [DTDUMP] cfgtable count=4
#   [DTDUMP] cfgtable[0..3] ... (none of them is EFI_DTB_TABLE)
#   [DTDUMP] no FDT table installed
#   [DTDUMP] no fdt to walk
# and UFSDxe then dies exactly like keys13a: ASSERT_EFI_ERROR (Status = Not Found) /
# UfsCoreBspLib.c +163.  A "Not Found" from a driver that looks up /soc/ufs%d/* is only
# explicable if there is no tree at all, and vermeer.fdf has both pieces commented out:
#   #INF EmbeddedPkg/Drivers/DtPlatformDxe/DtPlatformDxe.inf
#   #FILE FREEFORM = 25462CDA-221F-47DF-AC1D-259CFAA4E326 { SECTION RAW = FdtBlob/... }
# Upstream nuwaPkg (same SM8550) has both enabled - this build uncomments exactly those lines
# and dispatches DtPlatformDxe right after PcdDxe, before every vendor driver.
set -e -o pipefail

TAG=${1:-keys17}
UEFI=/root/k70/uefi
PKG=$UEFI/Platforms/Xiaomi/vermeerPkg
TOOLS=/mnt/d/本地项目-01/_k70port_extract
FD_OUT=$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd

cd "$UEFI"

cp "$PKG/vermeer.dsc" /tmp/vermeer.dsc.bak
cp "$PKG/vermeer.fdf" /tmp/vermeer.fdf.bak
cp "$PKG/Include/DXE.inc" /tmp/DXE.inc.bak
cp "$PKG/Include/APRIORI.inc" /tmp/APRIORI.inc.bak
restore() {
  cp /tmp/vermeer.dsc.bak "$PKG/vermeer.dsc"
  cp /tmp/vermeer.fdf.bak "$PKG/vermeer.fdf"
  cp /tmp/DXE.inc.bak "$PKG/Include/DXE.inc"
  cp /tmp/APRIORI.inc.bak "$PKG/Include/APRIORI.inc"
}
trap restore EXIT

mkdir -p "$PKG/Drivers/VermeerKeyProbeDxe" "$PKG/Drivers/VermeerDtDumpDxe"
cp "$TOOLS/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c" "$PKG/Drivers/VermeerKeyProbeDxe/"
cp "$TOOLS/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.inf" "$PKG/Drivers/VermeerKeyProbeDxe/"
cp "$TOOLS/port-drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.c" "$PKG/Drivers/VermeerDtDumpDxe/"
cp "$TOOLS/port-drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.inf" "$PKG/Drivers/VermeerDtDumpDxe/"

python3 "$TOOLS/wsl/gates.py" keyprobe    "$PKG/vermeer.dsc" "$PKG/vermeer.fdf"
python3 "$TOOLS/wsl/gates.py" vendorinput "$PKG/vermeer.dsc" "$PKG/vermeer.fdf"
python3 "$TOOLS/wsl/gates.py" set "$PKG/vermeer.dsc" VERMEER_KEYPROBE 1

python3 - "$PKG" <<'PY'
import pathlib, re, sys

pkg = pathlib.Path(sys.argv[1])
DUMP = "vermeerPkg/Drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.inf"
DTP  = "EmbeddedPkg/Drivers/DtPlatformDxe/DtPlatformDxe.inf"

# ---- 1) vermeer.dsc: register our dump driver + DtPlatformDxe in [Components] ----
dsc = pkg / "vermeer.dsc"
lines = dsc.read_text(encoding="utf-8").splitlines(keepends=True)
out = []
dumponce = dtponce = False
for line in lines:
    out.append(line)
    stripped = line.strip()
    if (not dumponce) and "VermeerKeyProbeDxe.inf" in line and not stripped.startswith("#"):
        out.append("  " + DUMP + "\n")
        dumponce = True
    if (not dtponce) and stripped.startswith("!include") is False and "MdeModulePkg/Core/Dxe/DxeMain.inf" in line and not stripped.startswith("#"):
        out.append("  " + DTP + "\n")
        dtponce = True
dsc.write_text("".join(out), encoding="utf-8")

# ---- 2) vermeer.fdf: register the dump driver, and UNCOMMENT DtPlatformDxe + FdtBlob ----
fdf = pkg / "vermeer.fdf"
lines = fdf.read_text(encoding="utf-8").splitlines(keepends=True)
out = []
fdfdump = False
uncommented = []
for line in lines:
    low = line.lower()
    if low.lstrip().startswith("inf") and "vermeerkeyprobedxe.inf" in low:
        out.append(line)
        if not fdfdump:
            out.append("  INF " + DUMP + "\n")
            fdfdump = True
        continue
    # uncomment the four device-tree lines the port disabled
    if low.lstrip().startswith("#") and (
        "embeddedpkg/drivers/dtplatformdxe/dtplatformdxe.inf" in low
        or "25462cda-221f-47df-ac1d-259cfaa4e326" in low
        or "section raw = vermeerpkg/fdtblob/" in low
        or "section ui = \"device tree\"" in low
    ):
        newline = re.sub(r"^(\s*)#", r"\1", line)
        out.append(newline)
        uncommented.append(newline.strip())
        continue
    # the closing brace of that FILE FREEFORM block
    if low.strip() == "#}":
        out.append(re.sub(r"^(\s*)#", r"\1", line))
        uncommented.append("}")
        continue
    out.append(line)
fdf.write_text("".join(out), encoding="utf-8")
print("fdf uncommented:")
for u in uncommented:
    print("   ", u)

# ---- 3) APRIORI: DT dump and DtPlatformDxe right after PcdDxe ----
apriori = pkg / "Include" / "APRIORI.inc"
lines = apriori.read_text(encoding="utf-8").splitlines(keepends=True)
out = []
done = False
for line in lines:
    out.append(line)
    if (not done) and "MdeModulePkg/Universal/PCD/Dxe/Pcd.inf" in line:
        out.append("  INF " + DTP + "\n")
        out.append("  INF " + DUMP + "\n")
        done = True
apriori.write_text("".join(out), encoding="utf-8")
print("apriori dt entries inserted:", done)
PY

# ---- 3b) swap the device tree blob to the real UEFI DT from xbl_config ----
KAILUA=$TOOLS/../_k70_pkg_1019/K70-UEFI-package/extracted/xbl_config_fdt_10168.dtb
[ -f "$KAILUA" ] || { echo "missing kailua DT: $KAILUA"; exit 1; }
cp "$KAILUA" "$PKG/FdtBlob/vermeer-uefi-kailua.dtb"
ls -l "$PKG/FdtBlob/"
sed -i -E 's#^([[:space:]]*SECTION RAW = ).*FdtBlob/.*\.dtb#\1vermeerPkg/FdtBlob/vermeer-uefi-kailua.dtb#' "$PKG/vermeer.fdf"
echo "--- fdf FdtBlob lines now ---"
grep -n 'FdtBlob\|Device Tree\|25462CDA' "$PKG/vermeer.fdf"

# Same vendor set as keys13a/keys15 (ULogDxe kept, NpaDxe kept, UFSDxe kept).
export DROP_JSON='["usb","xhci","pildxe","pilproxy","spss","tzdxe","charger","chg","sdcc","featureenabler","ddrinfo","limitsdxe","gpipdxe","gpidexe","ucdxe","rngdxe","tsens","clockdxe","displaydxe","rammanagerdxe"]'

python3 - "$PKG" <<'PY'
import json, os, pathlib, re, sys

pkg = pathlib.Path(sys.argv[1])
DROP = json.loads(os.environ["DROP_JSON"])

dsc = pkg / "vermeer.dsc"
s = dsc.read_text(encoding="utf-8")
s = re.sub(r"^( *VERMEER_VENDOR_HW *= *)\d+", r"\g<1>1", s, count=1, flags=re.M)
s = re.sub(r"^( *VERMEER_VENDOR_INPUT *= *)\d+", r"\g<1>0", s, count=1, flags=re.M)
dsc.write_text(s, encoding="utf-8")

kept = 0
for name in ("vermeer.dsc", "vermeer.fdf", "Include/DXE.inc", "Include/APRIORI.inc"):
    p = pkg / name
    if not p.exists():
        continue
    out = []
    for line in p.read_text(encoding="utf-8").splitlines(keepends=True):
        low = line.lower()
        if low.lstrip().startswith("inf") and "binaries/vermeer" in low:
            if any(tok in low for tok in DROP):
                out.append("# [keys16-drop] " + line)
                continue
            kept += 1
        out.append(line)
    p.write_text("".join(out), encoding="utf-8")
print("kept vendor modules:", kept)
PY

source /root/k70/venv/bin/activate
python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -8

FD=$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
[ -f "$FD" ] || { echo "build produced no FD"; exit 1; }
cp "$FD" "$FD_OUT"
cp "$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref" "/tmp/guid-$TAG.xref"
echo "=== $TAG FD ==="; ls -l "$FD_OUT"; sha256sum "$FD_OUT"
echo "--- DtPlatformDxe / DtDump / UFSDxe in FV? ---"
grep -iE 'DtPlatformDxe|DtDumpDxe|KeyProbeDxe|UFSDxe' "/tmp/guid-$TAG.xref" || echo "  none found"
echo "--- FdtBlob FFS present in FD? (FDT magic near end) ---"
python3 - "$FD" <<'PY'
import sys
d = open(sys.argv[1], 'rb').read()
print("  FDT blobs found:", d.count(b'\xd0\x0d\xfe\xed'))
import re as _re
print("  ufs0 string in FD:", b"init_speed_params" in d)
PY
