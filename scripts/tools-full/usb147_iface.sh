#!/bin/bash
# Inspect QcomUsbConfigProtocol interface struct (UsbConfigDxe) fields +0x88/+0x8c and .data layout
set -u
EFI=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
LOG=/mnt/d/本地项目-01/_tools/usb147_iface.log
: > "$LOG"
echo "== PE sections ==" >> "$LOG"
llvm-readobj --sections "$EFI" 2>/dev/null | grep -E 'Name:|VirtualAddress:|RawDataOffset|RawDataSize|SectionData' >> "$LOG" | head -0
llvm-readobj --sections "$EFI" | awk '/Name:/{n=$2} /VirtualAddress:/{v=$2} /RawDataOffset|PointerToRawData:/{r=$2} /RawDataSize|SizeOfRawData:/{s=$2} /Characteristics \[/{getline; getline; getline; getline; getline; getline; getline; getline; getline; } { }' >> "$LOG" 2>/dev/null
# simpler: use objdump -h
llvm-objdump -h "$EFI" >> "$LOG"
echo "== raw .data 0x133c0-0x13560 ==" >> "$LOG"
python3 - "$EFI" >> "$LOG" <<'PY'
import sys
p=open(sys.argv[1],'rb').read()
# parse PE sections via objdump -h is messy; assume .data VA 0x13000 raw 0x13000 for UsbConfigDxe (verified earlier)
base=0x133c0
for off in range(base,0x13580,16):
    chunk=p[off:off+16]
    print(f"{off:06x}: "+" ".join(f"{b:02x}" for b in chunk)+"  "+"".join(chr(b) if 32<=b<127 else '.' for b in chunk))
PY
echo "== instrs touching #0x88]/#0x8c]/#0x90] ==" >> "$LOG"
llvm-objdump -d --no-show-raw-insn "$EFI" > /tmp/ucfg_iface.asm
grep -n -B2 -A2 -E '#0x8[89c]\]|#0x90\]' /tmp/ucfg_iface.asm | head -120 >> "$LOG"
echo "== adrp 0x13000 followed by add #0x480..#0x4a0 ==" >> "$LOG"
grep -A1 'adrp.*0x13000' /tmp/ucfg_iface.asm | grep -E 'add.*#0x4[0-9a-f][0-9a-f]' | head -40 >> "$LOG"
cat "$LOG"
