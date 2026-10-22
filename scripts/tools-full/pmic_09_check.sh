#!/bin/bash
cd /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/ || exit 1
for f in PmicDxeLa.efi PmicDxeLa.patched.efi; do
  echo "== $f"
  echo "--- 0x3ff0..0x4010"
  xxd -g1 -s 0x3ff0 -l 32 "$f"
  echo "--- 0x14738..0x14758"
  xxd -g1 -s 0x14738 -l 32 "$f"
done
