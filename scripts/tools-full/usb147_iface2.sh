#!/bin/bash
set -u
LOG=/mnt/d/本地项目-01/_tools/usb147_iface2.log
: > "$LOG"
EFI=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
llvm-objdump -d --no-show-raw-insn "$EFI" > /tmp/ucfg_if2.asm
echo "== add of 0x488 / 0x470 / 0x510 / 0x514 near usbconfig struct ==" >> "$LOG"
grep -n -E '#0x488|#0x470|#0x510|#0x514|#0x4c8' /tmp/ucfg_if2.asm | head -40 >> "$LOG"
echo "== all str with #0x88] [x,#0x8c] [x,#0x90] in 0x3c00-0x4300 range ==" >> "$LOG"
awk -F: '{a=strtonum("0x"$1); if (a>=0x3c00 && a<=0x4400) print}' /tmp/ucfg_if2.asm > /tmp/range_ucfg.txt
grep -E '#0x88\]|#0x8c\]|#0x90\]|#0x80\]' /tmp/range_ucfg.txt >> "$LOG"
echo "== 0x8800-0x8900 ctx build (iface fields?) ==" >> "$LOG"
awk -F: '{a=strtonum("0x"$1); if (a>=0x8800 && a<=0x8900) print}' /tmp/ucfg_if2.asm >> "$LOG"
echo "== 0x1400-0x1600 (0x149c getter) ==" >> "$LOG"
awk -F: '{a=strtonum("0x"$1); if (a>=0x1400 && a<=0x1560) print}' /tmp/ucfg_if2.asm >> "$LOG"
echo "== search 0xA600000 immediate uses ==" >> "$LOG"
grep -n '0xa600000' /tmp/ucfg_if2.asm | head -30 >> "$LOG"
cat "$LOG"
