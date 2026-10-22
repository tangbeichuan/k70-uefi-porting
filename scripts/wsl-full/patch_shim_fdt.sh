#!/usr/bin/env bash
# keys33: capture the live device tree pointer that ABL passes to us in x0.
#
# Why: entry.S of the reference K70 XNU bring-up (ios-vermeer-lab) shows ABL enters
# the booted image with x0 = live FDT pointer, and that tree has the real board
# description (splash_region etc.).  Our BootShim throws x0 away, which is exactly why
# the firmware has no device tree and why every vendor driver that wants DT nodes
# (UFSDxe, DisplayDxe, HALIOMMU...) dies with EFI_NOT_FOUND / UfsCoreBspLib.c:163.
#
# So: stash x0 in x19 at the very first instruction, and publish {magic, x0} at
# 0xA700FFF0 (last 16 bytes of the mapped "FD Reserved" 1 MiB window) right before
# jumping into EDK2.  The DXE probe reads that slot, validates the FDT magic and walks
# the tree.
set -e
cd /root/k70/uefi || exit 1
UP=/mnt/d/本地项目-01/_k70port_extract/upstream-patches

echo "== patch upstream BootShim.S.marker (x0 -> x19 -> 0xA700FFF0) =="
python3 - "$UP/BootShim.S.marker" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text()

save = """_Start:
  /* keys33: ABL hands the booted image x0 = live device tree.  Save it before the
   * marker painting below (which uses x0) or the FD copy clobbers it. */
  mov   x19, x0
"""
if "keys33: ABL hands" not in s:
    old = "_Start:\n  mov   x4, x1\n"
    assert old in s, "unexpected _Start prologue"
    s = s.replace(old, save + "  mov   x4, x1\n", 1)

publish = """  /* keys33: publish the live FDT pointer for the DXE probe.  0xA700FFF0 is the last
   * 16 bytes of the mapped "FD Reserved" window (MemoryMapLib: 0xA7000000 + 1 MiB). */
  ldr   x11, =0xA700FFF0
  movz  x13, #0x4644, lsl #16
  movk  x13, #0x5442
  stp   x13, x19, [x11]
  dc    civac, x11
  dsb   sy
"""
if "publish the live FDT pointer" not in s:
    old = "  br    x5\n"
    assert old in s, "br x5 missing"
    s = s.replace(old, publish + "  br    x5\n", 1)

p.write_text(s)
print("patched", p)
PY

echo "== install into the checkout and rebuild both shims =="
cp "$UP/BootShim.S.marker" BootShim/BootShim.S
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

echo "== disassemble the head of the rebuilt shim to prove the patch landed =="
aarch64-linux-gnu-objdump -d BootShim/BootShim.elf 2>/dev/null | sed -n '1,40p'
