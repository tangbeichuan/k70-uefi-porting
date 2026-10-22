#!/usr/bin/env bash
# keys37 = keys25 lineage but PlatformPeiLib stays NULL (no DTBExtn HOB -> EnvDxe cannot
#          dereference the bogus interface) + probe dispatched last, UI demo only.
#
# Evidence from keys22 (real device):
#   [DTDUMP] dtb ext addr = 0xA703A0C8   (inside FD Reserved, so it IS readable)
#   [DTDUMP] entry[0..3]  = 0x10001 0xA7014290 0xA702540C 0xA70253C8
#   [DTDUMP] as guid      = 00010001-0000-0000-9042-01A700000000  (match DTBExtnHob=NO)
#   → the 8 bytes PlatformPei put in gEfiDtbExtensionHobGuid are NOT the DTB extension entry.
#
# Root cause is in our own source, not in the vendor blobs:
#   Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/XblProtocols.c:91
#     if (CompareGuid ((EFI_GUID *)AdrpRegValue[TargetRegister], ProtocolGuid) != 0) {
#       GuidMatched = TRUE; continue;         // <-- matched: address NOT stored
#     }
#     ProtocolAddress = AdrpRegValue[TargetRegister];   // <-- non-matching address stored
#   CompareGuid() returns TRUE when the GUIDs ARE equal (BaseMemoryLib/MemLibGuid.c), so this
#   stores the address of a GUID that does NOT match — exactly what the device showed.
#
# keys23 rewrites that hunk to return on match, and also adds a brute-force GUID scan of the
# FD Reserved window to VermeerDtDumpDxe so we can see what XBL really published.
set -e -o pipefail

TAG=${1:-keys37}
UEFI=/root/k70/uefi
PKG=$UEFI/Platforms/Xiaomi/vermeerPkg
TOOLS=/mnt/d/本地项目-01/_k70port_extract
FD_OUT=$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd
XBL=$UEFI/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/XblProtocols.c

cd "$UEFI"

cp "$PKG/vermeer.dsc" /tmp/vermeer.dsc.bak
cp "$PKG/vermeer.fdf" /tmp/vermeer.fdf.bak
cp "$PKG/Include/DXE.inc" /tmp/DXE.inc.bak
cp "$PKG/Include/APRIORI.inc" /tmp/APRIORI.inc.bak
cp "$XBL" /tmp/XblProtocols.c.bak
restore() {
  cp /tmp/vermeer.dsc.bak "$PKG/vermeer.dsc"
  cp /tmp/vermeer.fdf.bak "$PKG/vermeer.fdf"
  cp /tmp/DXE.inc.bak "$PKG/Include/DXE.inc"
  cp /tmp/APRIORI.inc.bak "$PKG/Include/APRIORI.inc"
  cp /tmp/XblProtocols.c.bak "$XBL"
}
trap restore EXIT

# ---- patch the CompareGuid inversion in GetXblHobAddresses -------------------------------
python3 - "$XBL" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8")

old_decl = "  BOOLEAN              GuidMatched      = FALSE;\n"
if old_decl in s:
    s = s.replace(old_decl, "", 1)

pat = re.compile(
    r"      // Compare Protocol GUIDs\n"
    r"      if \(CompareGuid \(\(EFI_GUID \*\)AdrpRegValue\[TargetRegister\], ProtocolGuid\) != 0\) \{\n"
    r"        GuidMatched = TRUE;\n"
    r"        continue;\n"
    r"      \}\n"
    r"\n"
    r"      // Set Protocol Address\n"
    r"      ProtocolAddress = AdrpRegValue\[TargetRegister\];\n"
)
new = (
    "      // keys23: CompareGuid() returns TRUE when the GUIDs are equal, so stop right here.\n"
    "      if (CompareGuid ((EFI_GUID *)AdrpRegValue[TargetRegister], ProtocolGuid)) {\n"
    "        return AdrpRegValue[TargetRegister];\n"
    "      }\n"
)
s2, n = pat.subn(new, s)
assert n == 1, "expected exactly one CompareGuid hunk, replaced %d" % n
s2 = s2.replace("  return GuidMatched == TRUE ? ProtocolAddress : 0;", "  return ProtocolAddress;", 1)
p.write_text(s2, encoding="utf-8")
print("patched XblProtocols.c: CompareGuid inversion fixed")
PY

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

# ---- 3) vermeer.fdf: register the dump driver ----
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

# ---- 4) APRIORI: dump driver right after PcdDxe ----
apriori = pkg / "Include" / "APRIORI.inc"
lines = apriori.read_text(encoding="utf-8").splitlines(keepends=True)
out, done = [], False
for line in lines:
    out.append(line)
    if (not done) and "RscDxe/RscDxe.inf" in line:
        out.append("  INF " + DUMP + "\n")
        done = True
apriori.write_text("".join(out), encoding="utf-8")
print("apriori: dump driver inserted:", done)
PY

# Same vendor set as keys13a / keys15 / keys18 / keys22.
python3 - "$PKG" <<'PYX'
import pathlib, sys
dsc = pathlib.Path(sys.argv[1]) / "vermeer.dsc"
orig = dsc.read_text(encoding="utf-8")
keep = [l for l in orig.splitlines() if "PlatformPeiLib|QcomPkg/Library/PlatformPeiLib/PlatformPeiLib.inf" not in l]
new = "\n".join(keep) + "\n"
dsc.write_text(new, encoding="utf-8")
print("dsc: PlatformPeiLib back to NULL :", orig != new)
PYX

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
                out.append("# [keys23-drop] " + line)
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
echo "--- xbl patch present in the tree? ---"
grep -n "keys23" "$XBL" || echo "  (tree restored already, check /tmp/XblProtocols.c.bak vs build log)"
