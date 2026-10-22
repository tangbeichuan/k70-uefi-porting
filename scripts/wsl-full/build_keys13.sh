#!/usr/bin/env bash
# keys13 = keys12 with ONE variable changed, to find out why NpaDxe asserts.
#
# What keys12 proved on the real device (photo, 16:0x):
#   Memory Allocation ... (DEBUG trace) -> 22 vendor drivers loaded in APRIORI order:
#   RuntimeDxe, ArmCpuDxe, ArmGicDxe, MetronomeDxe, ArmTimerDxe, SmemDxe, DALSys, HWIODxeDriver,
#   ChipInfo, PlatformInfoDxe, ProjectInfoDxe, HALIOMMU, IPCCDxe, CmdDbDxe, PwrUtilsDxe, NpaDxe
#   -> ERROR: C9000002:V03000007 ... CB29F4D1-... (FILE_GUID of NpaDxe)
#   -> ASSERT DebugLib.c +78: Format != ((void *) 0)  -> assert handler resets the phone.
#
# The assert comes from the Qualcomm DebugLib baked into NpaDxe.efi itself (its strings contain
# "DebugLib.c" / "ASSERT %a +%d: %a" / "Format != ((void *) 0)"), not from Mu source: the 22
# "ASSERT (Format != NULL)" sites in our tree are at lines 54..625 with no 78.
#
# Hypothesis: NPA logs through ULog, keys12 deliberately dropped ULogDxe (it rebooted keys5/6),
# the log client hands a NULL format back and DebugPrint(NULL, ...) trips the assert.  keys10
# still had ULogDxe and it got PAST NpaDxe.
#
#   MODE=A -> keys12 + ULogDxe   (keeps the vendor stack intact, does NPA stop asserting?)
#   MODE=B -> keys12 - NpaDxe    (depex is TRUE so DXE just dispatches the rest; if the input
#                                 chain really needs NPA the probe chain letters simply stop
#                                 moving, which is a clean, non-fatal answer)
set -e -o pipefail

MODE=${1:?usage: build_keys13.sh A|B}
case "$MODE" in
  A|a) MODE=A; TAG=keys13a ; EXTRA_DROP=""      ; KEEP_ULOG=1 ;;
  B|b) MODE=B; TAG=keys13b ; EXTRA_DROP="npadxe"; KEEP_ULOG=0 ;;
  *) echo "MODE must be A or B"; exit 2 ;;
esac

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

mkdir -p "$PKG/Drivers/VermeerKeyProbeDxe"
cp "$TOOLS/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c" "$PKG/Drivers/VermeerKeyProbeDxe/"
cp "$TOOLS/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.inf" "$PKG/Drivers/VermeerKeyProbeDxe/"
python3 "$TOOLS/wsl/gates.py" keyprobe    "$PKG/vermeer.dsc" "$PKG/vermeer.fdf"
python3 "$TOOLS/wsl/gates.py" vendorinput "$PKG/vermeer.dsc" "$PKG/vermeer.fdf"
python3 "$TOOLS/wsl/gates.py" set "$PKG/vermeer.dsc" VERMEER_KEYPROBE 1

MODE="$MODE" python3 - "$PKG" "$MODE" <<'PY'
import os, re, sys, pathlib

pkg = pathlib.Path(sys.argv[1])
mode = sys.argv[2]

# Same tail-drop list as keys12: the PIL/USB firmware-loading tail (that is what asserted in
# keys10), ULogDxe (rebooted keys5/keys6), and the panel-touching drivers.
DROP = [
    "ulogdxe", "usb", "xhci", "pildxe", "pilproxy", "spss", "tzdxe", "charger", "chg",
    "sdcc", "featureenabler", "ddrinfo", "limitsdxe", "gpipdxe", "gpidexe", "ucdxe",
    "rngdxe", "tsens", "clockdxe", "displaydxe", "rammanagerdxe",
]

if mode == "A":
    # put ULogDxe back, everything else identical to keys12
    DROP = [t for t in DROP if t != "ulogdxe"]
elif mode == "B":
    DROP = DROP + ["npadxe"]
else:
    sys.exit("bad mode")

dsc = pkg / "vermeer.dsc"
s = dsc.read_text(encoding="utf-8")
s = re.sub(r"^( *VERMEER_VENDOR_HW *= *)\d+", r"\g<1>1", s, count=1, flags=re.M)
s = re.sub(r"^( *VERMEER_VENDOR_INPUT *= *)\d+", r"\g<1>0", s, count=1, flags=re.M)
dsc.write_text(s, encoding="utf-8")

dropped, kept = [], []
for name in ("vermeer.dsc", "vermeer.fdf", "Include/DXE.inc", "Include/APRIORI.inc"):
    p = pkg / name
    if not p.exists():
        continue
    out = []
    for line in p.read_text(encoding="utf-8").splitlines(keepends=True):
        low = line.lower()
        stripped = low.lstrip()
        if stripped.startswith("inf") and "binaries/vermeer" in low:
            if any(token in low for token in DROP):
                out.append("# [%s-drop] %s" % (mode, line))
                dropped.append(line.strip())
                continue
            kept.append(line.strip())
        out.append(line)
    p.write_text("".join(out), encoding="utf-8")

print("kept vendor modules:", len(set(kept)))
for k in sorted(set(kept)):
    print("  KEEP  ", k)
print("dropped:", len(dropped))
PY

source /root/k70/venv/bin/activate
python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -8

FD=$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
[ -f "$FD" ] || { echo "build produced no FD"; exit 1; }
cp "$FD" "$FD_OUT"
echo "=== $TAG FD ==="
ls -l "$FD_OUT"
sha256sum "$FD_OUT"
