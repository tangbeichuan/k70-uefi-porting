#!/usr/bin/env bash
# Build a *diagnostic* firmware variant that stops with a readable banner on screen.
#
# Rationale: on the phone the DEBUG log (drawn by FrameBufferSerialPortLib) scrolls off a
# 3200 px panel after ~50 lines, and BDS then tries to boot, fails, and resets the machine -
# so a successful boot can look almost identical to a crash.  VermeerBannerDxe prints a
# fixed banner (through DEBUG first, then through gST->ConOut) and then rewrites a heartbeat
# counter forever: if you see the banner the whole chain worked; if the counter ticks, the
# event loop is alive.
#
# The gate scaffolding stays in the tree with VERMEER_BANNER = 0, so the shipping images are
# unchanged and a rebuild from the tarball only has to flip one number.
set -uo pipefail
UEFI=/root/k70/uefi
PKG=$UEFI/Platforms/Xiaomi/vermeerPkg
DSC=$PKG/vermeer.dsc
FDF=$PKG/vermeer.fdf
SRC=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerBannerDxe
GATES=/mnt/d/本地项目-01/_k70port_extract/wsl/gates.py
OUT=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
FKEEP=$UEFI/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
mkdir -p "$OUT" "$PKG/Drivers/VermeerBannerDxe"

cp -f "$SRC/VermeerBannerDxe.c" "$SRC/VermeerBannerDxe.inf" "$PKG/Drivers/VermeerBannerDxe/"

python3 "$GATES" banner "$DSC" "$FDF"
python3 "$GATES" set "$DSC" VERMEER_BANNER 1
echo "gates: $(grep -E '^\s+VERMEER_(PAINT|BANNER|VENDOR_HW)' "$DSC" | tr -s ' ' | tr '\n' ' ')"

cd "$UEFI"
source /root/k70/venv/bin/activate
echo "=== building banner variant (VERMEER_BANNER = 1) ==="
if python3 build_uefi.py -d vermeer -m 0 -r DEBUG > /root/k70/banner-build.log 2>&1; then
  grep -E 'Success|Images Verified' /root/k70/banner-build.log | tail -3
  cp -f "$FKEEP" "$OUT/SILICIUM_UEFI-banner.fd"
  ls -l "$OUT/SILICIUM_UEFI-banner.fd"; sha256sum "$OUT/SILICIUM_UEFI-banner.fd"
else
  echo "!! banner build FAILED - see /root/k70/banner-build.log"
  grep -Ei 'error|not found|failed' /root/k70/banner-build.log | tail -10
fi

# Leave the scaffolding, reset the value: the shipping build must never contain the banner.
python3 "$GATES" set "$DSC" VERMEER_BANNER 0
echo "=== gate back to 0; rebuilding default (phone) FD ==="
python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -2
sha256sum "$FKEEP"
