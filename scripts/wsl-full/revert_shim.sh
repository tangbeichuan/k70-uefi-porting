#!/usr/bin/env bash
# keys34: put the UNPATCHED BootShim back.
#
# keys33 hung right after "MMU: enabled" (PEI -> DxeCore never printed "Loading DxeCore"),
# and the only thing keys33 changed outside the DXE driver was the shim: it saved x0 into
# x19 and published {magic, x0} into 0xA700FFF0 -- the tail of the "FD Reserved" window that
# PlatformPeiLib *scans* for the XBL HOB function table.  Clobbering bytes in that window is
# the prime suspect for a PEI-phase hang, so keys34 goes back to the stock shim and keeps the
# experiment inside DXE: the handler now only walks the GUID HOB list and prints every
# 64-bit word (plus an FDT-magic check for words pointing into the mapped Kernel window).
set -e
cd /root/k70/uefi || exit 1
UP=/mnt/d/本地项目-01/_k70port_extract/upstream-patches

echo "== restore stock BootShim.S (no x0 capture, no slot store) =="
cp "$UP/BootShim.S.orig" BootShim/BootShim.S
grep -n 'keys33' BootShim/BootShim.S && { echo 'ERROR: patched source still in place'; exit 1; } || true

mkdir -p /root/k70/shims
for m in 0 1; do
  make -s -C BootShim clean >/dev/null 2>&1 || true
  rm -f BootShim/BootShim.elf BootShim/BootShim.bin
  make -s -C BootShim REQUIRES_KERNEL_HEADER=1 FD_BASE=0xA7100000 FD_SIZE=0x300000 PAINT_MARKER=$m
  cp BootShim/BootShim.bin /root/k70/shims/BootShim-marker$m.bin
  printf '  PAINT_MARKER=%d -> %s bytes  sha256 %s\n' "$m" \
    "$(stat -c %s BootShim/BootShim.bin)" "$(sha256sum BootShim/BootShim.bin | cut -d' ' -f1)"
done
cp /root/k70/shims/BootShim-marker0.bin BootShim/BootShim.bin
echo "== shims restored =="
