#!/bin/bash
set -e
D=/mnt/d/本地项目-01/_tools
if [ ! -f /tmp/pmic/pmic.asm ]; then
  bash $D/pmic_01_disasm.sh >/dev/null 2>&1 || true
fi
ls -la /tmp/pmic/ 2>/dev/null | head -10
echo '########## UFSDxe 17250-17480 (raw objdump names)'
llvm-objdump -d /mnt/d/本地项目-01/_k70port_extract/fv_dump/drivers/UFSDxe.efi > /tmp/ufs.asm 2>/dev/null
python3 - <<'EOF'
import re
lo,hi=0x17250,0x174c0
for ln in open('/tmp/ufs.asm',encoding='utf-8',errors='replace'):
    m=re.match(r'\s*([0-9a-f]{4,8}):\s+([0-9a-f]{8})\s+(.*)',ln)
    if m:
        a=int(m.group(1),16)
        if lo<=a<hi: print('%08x: %s'%(a,m.group(3).strip()))
EOF
echo '########## UFSDxe: find trampolines / calls to GetNode thunks'
grep -n 'call.*0x2410c\|call.*0x24110' /tmp/ufs.asm | head
