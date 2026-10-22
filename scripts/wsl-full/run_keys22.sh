#!/bin/bash
# keys22 = keys21 + struct-aware DTB-ext audit:
#   * prints the 4 x 64-bit words at the ext address
#   * checks whether those bytes ARE gEfiDtbExtensionHobGuid (XblProtocols parses ADRP+ADD,
#     so the "address" is very likely a {GUID,value} entry, not a device tree)
#   * if it is, treats word2/word3 as the device tree pointer and validates FDT magic
#   * falls back to probing 0xA7000000 / 0xA7100000 / 0xA7FF0000
#   * halts the CPU so the screen keeps the text
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
echo "===== BUILD keys22 ====="
bash build_keys18.sh keys22 2>&1 | tail -30
echo "===== PACK keys22 ====="
ls -l /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys22.fd
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys22.fd keys22 2>&1 | tail -20
echo "===== ARTIFACTS ====="
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys22*.img 2>/dev/null
sha256sum /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys22*.img 2>/dev/null
