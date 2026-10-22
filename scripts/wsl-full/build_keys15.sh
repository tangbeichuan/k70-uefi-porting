#!/usr/bin/env bash
# keys15 = keys13a (the best-known-good vendor stack, UFSDxe included) + VermeerDtDumpDxe,
# dispatched from APRIORI immediately after PcdDxe, i.e. before every vendor driver.
#
# Why: keys13a dies inside UFSDxe with
#   ReplaceTableEntry: splitting block entry with MMU disabled
#   ASSERT_EFI_ERROR (Status = Not Found)
#   ASSERT [UfsCoreBspLib.c +163]: !EFI_ERROR (eResult)
# UFSDxe is a Qualcomm RELEASE-ish binary that looks up
#   /soc/ufs0/{init_speed_params,perf_speed_params,timeout_values}
#   /pmic/client/ufs0_vcc, ufs0_vccq, ufs0_vdda, ufs0_vdda_core
# and it also carries "Failed to Locate DTBExtnProtocol 0x%x".  Status = Not Found is exactly
# what a lookup with no device tree returns, and our vermeer.fdf currently has BOTH
#   #INF EmbeddedPkg/Drivers/DtPlatformDxe/DtPlatformDxe.inf
#   #FILE FREEFORM = 25462CDA-... { SECTION RAW = FdtBlob/sm8550-xiaomi-vermeer.dtb }
# commented out, so the firmware very likely has no DT at all.
#
# This build answers that question on the phone itself before anything can assert: it prints the
# configuration-table list, whether an EFI_DTB_TABLE entry exists, and the first two levels of
# the tree plus any UFS-related property it finds.
set -e -o pipefail

TAG=${1:-keys15}
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

# 1) register the DT dump driver in DSC + FDF right after the key probe, 2) dispatch it early.
python3 - "$PKG" <<'PY'
import pathlib, sys

pkg = pathlib.Path(sys.argv[1])
INF = "vermeerPkg/Drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.inf"

dsc = pkg / "vermeer.dsc"
lines = dsc.read_text(encoding="utf-8").splitlines(keepends=True)
out = []
for line in lines:
    out.append(line)
    if "VermeerKeyProbeDxe.inf" in line and not line.lstrip().startswith("#"):
        out.append("  " + INF + "\n")
dsc.write_text("".join(out), encoding="utf-8")

fdf = pkg / "vermeer.fdf"
lines = fdf.read_text(encoding="utf-8").splitlines(keepends=True)
out = []
for line in lines:
    out.append(line)
    if "VermeerKeyProbeDxe.inf" in line and line.lstrip().upper().startswith("INF"):
        out.append("  INF " + INF + "\n")
fdf.write_text("".join(out), encoding="utf-8")

apriori = pkg / "Include" / "APRIORI.inc"
lines = apriori.read_text(encoding="utf-8").splitlines(keepends=True)
out = []
done = False
for line in lines:
    out.append(line)
    if (not done) and "MdeModulePkg/Universal/PCD/Dxe/Pcd.inf" in line:
        out.append("  INF " + INF + "\n")
        done = True
apriori.write_text("".join(out), encoding="utf-8")
print("dt dump registered:", done)
PY

# Same tail-drop list as keys13a (ULogDxe put back, NpaDxe kept, UFSDxe kept).
DROP='["usb","xhci","pildxe","pilproxy","spss","tzdxe","charger","chg","sdcc","featureenabler","ddrinfo","limitsdxe","gpipdxe","gpidexe","ucdxe","rngdxe","tsens","clockdxe","displaydxe","rammanagerdxe"]'
export DROP_JSON="$DROP"

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
                out.append("# [keys15-drop] " + line)
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
echo "--- dt dump + probe + UFS in FV? ---"
grep -iE 'DtDumpDxe|KeyProbeDxe|UFSDxe|ULogDxe' "/tmp/guid-$TAG.xref" || echo "  none found"
