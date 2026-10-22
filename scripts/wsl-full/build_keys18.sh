#!/usr/bin/env bash
# keys18 = keys13a-equivalent vendor set + the REAL PlatformPeiLib + an upgraded DTDUMP probe.
#
# Why this build:
#   keys17 (DtPlatformDxe right after PcdDxe) died with
#     ASSERT [DtPlatformDxe] UefiHiiServicesLib.c(82): !EFI_ERROR(Status)  (Status = Not Found)
#   i.e. that driver needs HII + variables, which APRIORI dispatches AFTER UFSDxe.  Dead end.
#
#   Reverse engineering of the vendor stack showed what really matters:
#     UFSDxe.efi  -> "Failed to Locate DTBExtnProtocol 0x%x"
#     protocol GUID = 0389B776-625F-11EB-83BE-C741A913DE34   (UFSDxe.efi @0x17250)
#     and EnvDxe.efi @0x2bf0 INSTALLS that very protocol (InstallMultipleProtocolInterfaces,
#     interface built at EnvDxe+0xe470, 0x108 bytes).
#   EnvDxe can only build it from the gEfiDtbExtensionHobGuid HOB, and that HOB is created by
#     Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c:120  PlatformPeim()
#   which our platform never links: SiliciumPkg.dsc.inc:195 maps PlatformPeiLib to the NULL
#   stub that only does BuildFvHob().  Hence: no DT extension HOB -> no DTBExtn protocol ->
#   every Qualcomm driver that wants UFS/display/IOMMU parameters gets EFI_NOT_FOUND.
#
#   keys18 maps PlatformPeiLib back to the real one and prints, before the vendor stack,
#   (a) the GUID HOBs the SEC handed over, (b) whether DTBExtn protocol exists.
set -e -o pipefail

TAG=${1:-keys18}
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
import pathlib, sys

pkg  = pathlib.Path(sys.argv[1])
DUMP = "vermeerPkg/Drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.inf"

# ---- 1) vermeer.dsc: [LibraryClasses] PlatformPeiLib -> the real Qualcomm one ----
dsc  = pkg / "vermeer.dsc"
text = dsc.read_text(encoding="utf-8")
anchor = "  ConfigurationMapLib|vermeerPkg/Library/ConfigurationMapLib/ConfigurationMapLib.inf\n"
assert anchor in text, "ConfigurationMapLib anchor not found"
if "QcomPkg/Library/PlatformPeiLib/PlatformPeiLib.inf" not in text:
    text = text.replace(
        anchor,
        anchor + "  PlatformPeiLib|QcomPkg/Library/PlatformPeiLib/PlatformPeiLib.inf\n",
        1,
    )
    dsc.write_text(text, encoding="utf-8")
    print("dsc: PlatformPeiLib -> real QcomPkg implementation")
else:
    print("dsc: PlatformPeiLib override already present")

# ---- 2) vermeer.dsc: register the dump driver ----
lines = dsc.read_text(encoding="utf-8").splitlines(keepends=True)
out, dumponce = [], False
for line in lines:
    out.append(line)
    if (not dumponce) and "VermeerKeyProbeDxe.inf" in line and not line.strip().startswith("#"):
        out.append("  " + DUMP + "\n")
        dumponce = True
dsc.write_text("".join(out), encoding="utf-8")
print("dsc: dump driver registered:", dumponce)

# ---- 3) vermeer.fdf: register the dump driver (leave DtPlatformDxe/FdtBlob commented) ----
fdf  = pkg / "vermeer.fdf"
lines = fdf.read_text(encoding="utf-8").splitlines(keepends=True)
out, fdfdump = [], False
for line in lines:
    low = line.lower()
    if low.lstrip().startswith("inf") and "vermeerkeyprobedxe.inf" in low and not fdfdump:
        out.append(line)
        out.append("  INF " + DUMP + "\n")
        fdfdump = True
        continue
    out.append(line)
fdf.write_text("".join(out), encoding="utf-8")
print("fdf: dump driver registered:", fdfdump)

# ---- 4) APRIORI: dump driver right after PcdDxe, before every vendor driver ----
apriori = pkg / "Include" / "APRIORI.inc"
lines = apriori.read_text(encoding="utf-8").splitlines(keepends=True)
out, done = [], False
for line in lines:
    out.append(line)
    if (not done) and "MdeModulePkg/Universal/PCD/Dxe/Pcd.inf" in line:
        out.append("  INF " + DUMP + "\n")
        done = True
apriori.write_text("".join(out), encoding="utf-8")
print("apriori: dump driver inserted:", done)
PY

# Same vendor set as keys13a / keys15 / keys17 (ULogDxe kept, NpaDxe kept, UFSDxe kept).
export DROP_JSON='["usb","xhci","pildxe","pilproxy","spss","tzdxe","charger","chg","sdcc","featureenabler","ddrinfo","limitsdxe","gpipdxe","gpidexe","ucdxe","rngdxe","tsens","clockdxe","displaydxe","rammanagerdxe"]'

python3 - "$PKG" <<'PY'
import json, os, pathlib, re, sys

pkg  = pathlib.Path(sys.argv[1])
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
                out.append("# [keys18-drop] " + line)
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
echo "--- probe / vendor modules in FV? ---"
grep -iE 'VermeerDtDumpDxe|VermeerKeyProbeDxe|UFSDxe|EnvDxe' "/tmp/guid-$TAG.xref" || echo "  none found"
echo "--- probe strings inside FD? ---"
python3 - "$FD" <<'PY'
import sys
d = open(sys.argv[1], 'rb').read()
for s in (b"DTBExtn protocol Status", b"DTB EXTENSION HOB", b"vermeer device-tree dump", b"Failed to Locate DTBExtnProtocol"):
    print("  ", s.decode(), "->", d.count(s))
PY
