#!/usr/bin/env bash
# Build the key-probe firmware.
#
#   build_keys.sh 0   -> probe only, no vendor drivers (zero risk: answers "does ConIn exist")
#   build_keys.sh 1   -> probe + SPMIDxe + PmicDxe + TLMMDxe + ButtonsDxe (tries to make volume-up work)
#
# Everything is gated in vermeer.dsc [Defines]; gates are reset to 0 afterwards so the
# shipping configuration is untouched.
set -e -o pipefail
cd /root/k70/uefi || exit 1
. /root/k70/venv/bin/activate

VENDOR=${1:-0}
TAG=${2:-keys${VENDOR}}
TOOLS=/mnt/d/本地项目-01/_k70port_extract
DSC=Platforms/Xiaomi/vermeerPkg/vermeer.dsc
FDF=Platforms/Xiaomi/vermeerPkg/vermeer.fdf
GATES=$TOOLS/wsl/gates.py
OUTFD=$TOOLS/qemu-fw/SILICIUM_UEFI-${TAG}.fd

# The DSC gate is a boolean switch, so anything non-zero means "vendor input on".
GATE_VAL=0
[ "$VENDOR" != "0" ] && GATE_VAL=1

echo "=== install VermeerKeyProbeDxe ==="
mkdir -p Platforms/Xiaomi/vermeerPkg/Drivers
rm -rf Platforms/Xiaomi/vermeerPkg/Drivers/VermeerKeyProbeDxe
cp -r "$TOOLS/port-drivers/VermeerKeyProbeDxe" Platforms/Xiaomi/vermeerPkg/Drivers/
ls -l Platforms/Xiaomi/vermeerPkg/Drivers/VermeerKeyProbeDxe

echo "=== gate scaffolding (idempotent) ==="
python3 "$GATES" keyprobe    "$DSC" "$FDF"
python3 "$GATES" vendorinput "$DSC" "$FDF"
python3 "$GATES" set "$DSC" VERMEER_KEYPROBE   1
python3 "$GATES" set "$DSC" VERMEER_VENDOR_INPUT "$GATE_VAL"
python3 "$GATES" set "$DSC" VERMEER_BANNER     0
python3 "$GATES" set "$DSC" VERMEER_PAINT      0
grep -n 'VERMEER_' "$DSC" | head -12

echo "=== build (VENDOR_INPUT=$VENDOR) ==="
python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -15

FD=Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
[ -f "$FD" ] || { echo "build produced no FD"; exit 1; }
cp -f "$FD" "$OUTFD"
echo
echo "=== FD ==="
ls -l "$OUTFD"; sha256sum "$OUTFD"
echo
echo "=== modules in FD ==="
python3 "$TOOLS/list_fd_modules2.py" "$OUTFD" 2>/dev/null | grep -iE 'keyprobe|spmi|pmic|button|total|Images' || true

echo "=== restore shipping gates ==="
python3 "$GATES" set "$DSC" VERMEER_KEYPROBE    0
python3 "$GATES" set "$DSC" VERMEER_VENDOR_INPUT 0
grep -n 'VERMEER_KEYPROBE\|VERMEER_VENDOR_INPUT' "$DSC"
