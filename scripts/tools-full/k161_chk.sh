#!/usr/bin/env bash
set -e
E=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerMenuDxe.efi
llvm-objdump -d "$E" > /tmp/menu161.asm
echo "--- 0x40000000 immediates (a CSFTRST pulse would need one) ---"
grep -n '#0x40000000' /tmp/menu161.asm || echo "  NONE (good: no CSFTRST pulse)"
echo "--- contexts of DCTL (0xc704) accesses ---"
grep -n -A3 -B3 '#0xc704' /tmp/menu161.asm | head -80
