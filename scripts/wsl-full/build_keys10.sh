#!/usr/bin/env bash
# keys10 = full vendor stack (sheng's proven set, including EnvDxe and UFSDxe) in APRIORI order,
# minus the three drivers that are known to take the panel down (ClockDxe, DisplayDxe) and
# RamManagerDxe (needs the vendor RAM partition table and only matters for XNU).
# Purpose: let the *whole* vendor chain come up so that SMEM -> DALSYSDxe -> ae37b942 ->
# TLMM/Pmic/Buttons (input) and UFSDxe (storage) can finally dispatch.
set -e -o pipefail

UEFI=/root/k70/uefi
PKG=$UEFI/Platforms/Xiaomi/vermeerPkg
TOOLS=/mnt/d/本地项目-01/_k70port_extract
TAG=${1:-keys10}
FD_OUT=$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd

cd "$UEFI"

# --- backups so a failed experiment cannot poison the tree -----------------
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

# --- probe driver + its gated block ---------------------------------------
mkdir -p "$PKG/Drivers/VermeerKeyProbeDxe"
cp "$TOOLS/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c" "$PKG/Drivers/VermeerKeyProbeDxe/"
cp "$TOOLS/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.inf" "$PKG/Drivers/VermeerKeyProbeDxe/"
python3 "$TOOLS/wsl/gates.py" keyprobe    "$PKG/vermeer.dsc" "$PKG/vermeer.fdf"
python3 "$TOOLS/wsl/gates.py" vendorinput "$PKG/vermeer.dsc" "$PKG/vermeer.fdf"
python3 "$TOOLS/wsl/gates.py" set "$PKG/vermeer.dsc" VERMEER_KEYPROBE 1

# --- turn the full vendor stack on, keep the display destroyers out -------
python3 - "$PKG" <<'PY'
import re, sys, pathlib
pkg = pathlib.Path(sys.argv[1])
dsc = pkg / "vermeer.dsc"
s = dsc.read_text(encoding="utf-8")
s = re.sub(r"^( *VERMEER_VENDOR_HW *= *)\d+", r"\g<1>1", s, count=1, flags=re.M)
s = re.sub(r"^( *VERMEER_VENDOR_INPUT *= *)\d+", r"\g<1>0", s, count=1, flags=re.M)
s = re.sub(r"^( *VERMEER_KEYPROBE *= *)\d+", r"\g<1>1", s, count=1, flags=re.M)
dsc.write_text(s, encoding="utf-8")

for name in ("vermeer.dsc", "vermeer.fdf", "Include/DXE.inc", "Include/APRIORI.inc"):
    p = pkg / name
    if not p.exists():
        continue
    out = []
    for line in p.read_text(encoding="utf-8").splitlines(keepends=True):
        low = line.lower()
        if ("clockdxe" in low or "displaydxe" in low or "rammanagerdxe" in low) and low.lstrip().startswith("inf"):
            out.append("# [keys10] " + line)
        else:
            out.append(line)
    p.write_text("".join(out), encoding="utf-8")
PY

echo "--- gates in effect ---"
grep -n "VERMEER_VENDOR_HW\|VERMEER_KEYPROBE" "$PKG/vermeer.dsc" | head -4
echo "--- commented out ---"
grep -n "# \[keys10\]" "$PKG"/vermeer.dsc "$PKG"/vermeer.fdf "$PKG"/Include/DXE.inc "$PKG"/Include/APRIORI.inc || true

# --- build ----------------------------------------------------------------
source /root/k70/venv/bin/activate
python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -12

FD=$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
ls -l "$FD"
cp "$FD" "$FD_OUT"
sha256sum "$FD_OUT"
python3 "$TOOLS/list_fd_modules2.py" "$FD_OUT" | head -5
