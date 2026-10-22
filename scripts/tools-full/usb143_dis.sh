#!/bin/bash
set -e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
llvm-objdump -d --no-show-raw-insn "$F" 2>/dev/null | grep -E '^ *(3f6[0-9a-f]|3f7[0-9a-f]|3f8[0-9a-f]|3f9[0-9a-f]|3fa[0-9a-f]|3fb[0-9a-f]|3f[c-f][0-9a-f]|40[0-1][0-9a-f]):' | head -40
