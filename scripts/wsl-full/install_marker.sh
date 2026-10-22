#!/usr/bin/env bash
# Install the bring-up marker support into the WSL checkout and build BOTH shims.
# Default (PAINT_MARKER=0) is untouched behaviour; the marker image is a separate
# diagnostic artefact, so the primary deliverable never changes.
set -e
cd /root/k70/uefi || exit 1
UP=/mnt/d/本地项目-01/_k70port_extract/upstream-patches

echo "== backup upstream BootShim sources (once) =="
[ -f BootShim/BootShim.S.upstream ]      || cp BootShim/BootShim.S      BootShim/BootShim.S.upstream
[ -f BootShim/Makefile.upstream ]        || cp BootShim/Makefile        BootShim/Makefile.upstream

echo "== install marker-enabled sources =="
cp "$UP/BootShim.S.marker"        BootShim/BootShim.S
cp "$UP/BootShim.Makefile.marker" BootShim/Makefile

echo "== patch build_uefi.py =="
python3 "$UP/patch_build_uefi_marker.py" /root/k70/uefi/build_uefi.py

echo "== build shim variants =="
mkdir -p /root/k70/shims
for m in 0 1; do
  make -s -C BootShim clean >/dev/null 2>&1 || true
  rm -f BootShim/BootShim.elf BootShim/BootShim.bin
  make -s -C BootShim REQUIRES_KERNEL_HEADER=1 FD_BASE=0xA7100000 FD_SIZE=0x300000 PAINT_MARKER=$m
  cp BootShim/BootShim.bin /root/k70/shims/BootShim-marker$m.bin
  printf '  PAINT_MARKER=%d -> %s bytes  sha256 %s\n' "$m" "$(stat -c %s BootShim/BootShim.bin)" "$(sha256sum BootShim/BootShim.bin | cut -d' ' -f1)"
done

echo "== restore the default (marker off) shim =="
cp /root/k70/shims/BootShim-marker0.bin BootShim/BootShim.bin
sha256sum BootShim/BootShim.bin
