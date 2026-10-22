#!/bin/bash
# keys145 step 1c: find the exact faulting idiom: "ldr x8,[x8,#0x8]" where x8
# was just loaded from a global that a preceding gBS->LocateProtocol/OpenProtocol
# may have left NULL (X0=EFI_NOT_FOUND, X8=0, FAR=0x8).
set +e
BIN=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
for M in UsbConfigDxe UsbInitDxe UsbfnDwc3Dxe UsbDeviceDxe UsbMsdDxe UsbBusDxe UsbPwrCtrlDxe; do
  F=$(ls $BIN/$M/$M.patched.efi 2>/dev/null | head -1); [ -z "$F" ] && F=$BIN/$M/$M.efi
  [ -f "$F" ] || continue
  llvm-objdump -d --no-show-raw-insn "$F" > /tmp/k145c_$M.asm 2>/dev/null
  echo "================ $M"
  python3 - "$M" <<'PY'
import re,sys
M=sys.argv[1]
ins=[]
for L in open('/tmp/k145c_%s.asm'%M):
    m=re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)',L)
    if m: ins.append((int(m.group(1),16),m.group(2),m.group(3).strip()))
for i,(a,op,arg) in enumerate(ins):
    if op=='ldr' and re.match(r'x8, \[x8, #0x8\]$',arg):
        lo=max(0,i-14)
        print('  --- site %06x ---'%a)
        for j in range(lo,min(len(ins),i+3)):
            print('    %06x %-8s %s'%(ins[j][0],ins[j][1],ins[j][2]))
PY
done
