#!/bin/bash
# keys145: locate the crashing module/site from ELR = 0xC5B4E0FF0.
# A page-aligned load base implies RVA = ELR - base, so RVA must END WITH 0xFF0.
# Find every "ldr xD,[xS,#0x8]" at an RVA = ...FF0 in every FV module, then show
# the surrounding window (LocateProtocol/OpenProtocol + error check).
set +e
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.inf
python3 - "$B" <<'PY' > /tmp/k145_files.txt
import re,sys
for m in re.finditer(r'EFI_FILE_NAME = (\S+)',open(sys.argv[1]).read()):
    print(m.group(1))
PY
echo "modules: $(wc -l < /tmp/k145_files.txt)"
echo "=== candidate fault sites at RVA ending 0xFF0 (ldr xD,[xS,#0x8]) ==="
while read -r f; do
  [ -f "$f" ] || continue
  llvm-objdump -d --no-show-raw-insn "$f" 2>/dev/null > /tmp/k145_one.asm
  python3 - "$f" <<'PY'
import re,sys
f=sys.argv[1]
name=__import__('os').path.basename(__import__('os').path.dirname(f))
ins=[]
for L in open('/tmp/k145_one.asm'):
    m=re.match(r'\s*([0-9a-f]+):\s+(\S+)\s*(.*)',L)
    if m: ins.append((int(m.group(1),16),m.group(2),m.group(3).strip()))
for i,(a,op,arg) in enumerate(ins):
    if (a & 0xFFF)!=0xFF0: continue
    if op!='ldr': continue
    if not re.match(r'x\d+, \[x\d+, #0x8\]',arg): continue
    print('==== %s  site RVA 0x%x  %s %s' % (name,a,op,arg))
    for j in range(max(0,i-12),min(len(ins),i+4)):
        print('   %06x %-8s %s'%(ins[j][0],ins[j][1],ins[j][2]))
    # ELR-implied base if this is the crash site
    elr=0xC5B4E0FF0
    print('   -> implied load base = 0x%X (page aligned: %s)'%(elr-a, (elr-a)%0x1000==0))
PY
done < /tmp/k145_files.txt
