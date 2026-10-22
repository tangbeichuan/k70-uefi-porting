#!/bin/bash
# keys145 step 1: find the driver whose RVA 0xFF0 is a faulting-style
# "ldr xN,[xM,#8]" right after a LocateProtocol/OpenProtocol that can return
# EFI_NOT_FOUND (X0=0x800000000000000E, X8=0, FAR=0x8).
set +e
BIN=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
# candidates that consume E722B03F (UsbConfig protocol)
for M in UsbInitDxe UsbfnDwc3Dxe UsbDeviceDxe UsbMsdDxe UsbBusDxe UsbPwrCtrlDxe; do
  F=$BIN/$M/$M.efi
  [ -f "$F" ] || { echo "== $M: no efi"; continue; }
  AP=$(ls $BIN/$M/$M.patched.efi 2>/dev/null | head -1)
  [ -n "$AP" ] && F=$AP
  llvm-objdump -d --no-show-raw-insn "$F" > /tmp/k145_$M.asm 2>/dev/null
  echo "================ $M  ($F)"
  python3 - "$M" <<'PY'
import re,sys
M=sys.argv[1]
ins=[]
for L in open('/tmp/k145_%s.asm'%M):
    m=re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)',L)
    if m: ins.append((int(m.group(1),16),m.group(2),m.group(3).strip()))
# 1) anything at/near RVA 0xff0 that loads [.., #8]
print('  --- instructions near RVA 0xff0 (0xfc0..0x1020) ---')
for a,op,arg in ins:
    if 0xfc0<=a<=0x1020:
        mark='  <== loads #8' if (op.startswith('ldr') and re.search(r'#0x8\]',arg)) else ''
        print('   %06x %-8s %s%s'%(a,op,arg,mark))
# 2) every 'ldr xN,[xM,#8]' whose preceding 12 insns include gBS LocateProtocol/OpenProtocol
print('  --- candidate fault sites: ldr #8 within 12 insns after gBS->Locate/Open ---')
gbs=None
for i,(a,op,arg) in enumerate(ins):
    if op=='ldr' and re.search(r'ldr\s+x\d+, \[x\d+, #0x8\b',op+' '+arg):
        pass
    if op!='ldr': continue
    m=re.match(r'(x\d+), \[(x\d+), #0x8\]',arg)
    if not m: continue
    # scan back for ldr from gBS offset 0x140/0x118/0x120/0x128
    hit=None
    for j in range(i-1,max(0,i-16),-1):
        if ins[j][1]=='ldr':
            m2=re.search(r'\[x\d+, #(0x140|0x118|0x120|0x128|0x130)\]',ins[j][2])
            if m2: hit=(ins[j][0],m2.group(1)); break
    if hit:
        print('   %06x %s %s   <- after ldr [gBS,#%s] at %06x'%(a,op,arg,hit[1],hit[0]))
PY
done
