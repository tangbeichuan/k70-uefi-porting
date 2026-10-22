#!/usr/bin/env bash
# keys140 = keys136 + FAT-formatted log disk (VermeerLogDiskDxe v2).
#
# The only change vs keys136 is the upgraded RAM log-disk driver: instead of
# exposing raw 512-byte blocks it formats a real FAT volume with a
# BOOTLOG.TXT inside, so a connected PC can mount the drive and copy the log
# instead of photographing the screen.
#
# Unchanged on purpose: BlockIO media parameters (1 MiB, 512 B blocks, 2048
# blocks), the "[UI] BlockIO devices: 1" menu line, and every patch in the
# keys136 order - patch_usb126.py must stay, it is what re-inserts the
# LogDisk INF into APRIORI.inc right before the menu (without it BlockIO
# drops to 0).  patch_fat137.py verifies all of that and fails the build.
#
# keys136 lineage: keys13a - UFSDxe (the module the real-device log died in).
set -e -o pipefail

TAG=${1:-keys140}
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

python3 /mnt/d/本地项目-01/_tools/patch_menu101.py  # re-apply after gates.py
python3 /mnt/d/本地项目-01/_tools/patch_copy123.py && python3 /mnt/d/本地项目-01/_tools/patch_extn136.py
#
python3 "$TOOLS/wsl/gates.py" vendorinput "$PKG/vermeer.dsc" "$PKG/vermeer.fdf"
python3 "$TOOLS/wsl/gates.py" set "$PKG/vermeer.dsc" VERMEER_KEYPROBE 1

python3 - "$PKG" <<'PY'
import re, sys, pathlib

pkg = pathlib.Path(sys.argv[1])

# keys13a list, with ULogDxe kept back in (that is what fixed NpaDxe) and UFSDxe added to the
# drop list.  Everything else is untouched, so this is still a one-module experiment vs keys13a.
DROP = [
    # keys140: keep the USB *device* stack (UsbInit/UsbDevice/UsbfnDwc3/UsbMsd/UsbPwrCtrl) so the gadget can expose a RAM disk to the PC.
    # Only the host-side drivers stay dropped.
    "usbbus", "usbkb", "usbmassstorage", "usbconfig", "usbmouse", "usbnetwork",
    "xhci", "pildxe", "pilproxy", "spss", "tzdxe", "charger", "chg",
    "sdcc", "featureenabler", "ddrinfo", "limitsdxe", "gpipdxe", "gpidexe", "ucdxe",
    "rngdxe", "tsens", "clockdxe", "displaydxe", "rammanagerdxe",
    "ufsdxe",
]

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
        if low.lstrip().startswith("inf") and "binaries/vermeer" in low:
            if any(token in low for token in DROP):
                out.append("# [keys140-drop] " + line)
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

python3 /mnt/d/本地项目-01/_tools/patch_usb126.py && python3 /mnt/d/本地项目-01/_tools/patch_usb130.py && python3 /mnt/d/本地项目-01/_tools/patch_pmicstub127.py
python3 /mnt/d/本地项目-01/_tools/patch_fat137.py
source /root/k70/venv/bin/activate
python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -6

FD=$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
[ -f "$FD" ] || { echo "build produced no FD"; exit 1; }
cp "$FD" "$FD_OUT"
cp "$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref" "/tmp/guid-$TAG.xref"
echo "=== $TAG FD ==="; ls -l "$FD_OUT"; sha256sum "$FD_OUT"
echo "--- UFSDxe in FV? (should be nothing) ---"
grep -i 'UFSDxe' "/tmp/guid-$TAG.xref" || echo "  OK: no UFSDxe"
echo "--- NpaDxe / ULogDxe / ButtonsDxe in FV? ---"
grep -iE ' (NpaDxe|ULogDxe|ButtonsDxe|SPMIDxe)$' "/tmp/guid-$TAG.xref"
