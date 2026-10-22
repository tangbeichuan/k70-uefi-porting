#!/usr/bin/env bash
# keys12 = "front half" of the vendor stack only.
#
# keys10 (full stack) proved that the front of the chain loads: Env, Smem, HWIO, ChipInfo,
# PlatformInfo, ProjectInfo, HALIOMMU, IPCC, GLink, CmdDb, PwrUtils, Npa, Rpmh, Vcs, ICB,
# ShmBridge, Scm, TLMM, I2C, SPMI all appeared in the "Loading driver" list, and the boot
# then died on ASSERT [UefiLoaderImplLib.c:163] - that library belongs to the PIL / USB
# firmware-loading tail, which we do not need for input.
#
# So keep only what input actually needs, drop the tail (USB, xHCI, PIL, SPSS, TZ applet,
# charger, SDCC, sensors, DDR info) and drop ULogDxe (it is what rebooted keys5 and keys6).
set -e -o pipefail

UEFI=/root/k70/uefi
PKG=$UEFI/Platforms/Xiaomi/vermeerPkg
TOOLS=/mnt/d/本地项目-01/_k70port_extract
TAG=${1:-keys12}
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

python3 - "$PKG" <<'PY'
import re, sys, pathlib

pkg = pathlib.Path(sys.argv[1])

# Modules kept out on purpose.  Everything here either belongs to the firmware-loading tail
# that asserted in keys10, or is known to reboot the device (ULogDxe), or takes the panel down.
DROP = (
    "ulogdxe", "usb", "xhci", "pildxe", "pilproxy", "spss", "tzdxe", "charger", "chg",
    "sdcc", "featureenabler", "ddrinfo", "limitsdxe", "gpipdxe", "gpidexe", "ucdxe",
    "rngdxe", "tsens", "clockdxe", "displaydxe", "rammanagerdxe",
)

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
                out.append("# [keys12-drop] " + line)
                dropped.append(line.strip())
                continue
            kept.append(line.strip())
        out.append(line)
    p.write_text("".join(out), encoding="utf-8")

print("kept vendor modules:", len(set(kept)))
for k in sorted(set(kept)):
    print("  KEEP  ", k)
print("dropped:", len([d for d in dropped]))
PY

source /root/k70/venv/bin/activate
python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -8

FD=$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
[ -f "$FD" ] || { echo "build produced no FD"; exit 1; }
cp "$FD" "$FD_OUT"
ls -l "$FD_OUT"
sha256sum "$FD_OUT"
