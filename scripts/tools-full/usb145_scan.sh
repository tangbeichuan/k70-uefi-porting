#!/bin/bash
# keys145 step 1b: scan EVERY module in the current FV for a faulting-style
# instruction at RVA 0xFF0 ("ldr xD,[xS,#0x8]"), since ELR = <aligned base>+0xFF0
# and X20 = 0xC64F0000 looks like that base.
set +e
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.inf
python3 - "$B" <<'PY' > /tmp/k145_files.txt
import re,sys
for m in re.finditer(r'EFI_FILE_NAME = (\S+)',open(sys.argv[1]).read()):
    print(m.group(1))
PY
wc -l /tmp/k145_files.txt
echo "=== modules with 'ldr x?,[x?,#0x8]' exactly at RVA 0xff0 ==="
while read -r f; do
  [ -f "$f" ] || continue
  llvm-objdump -d --no-show-raw-insn "$f" 2>/dev/null > /tmp/k145_one.asm
  line=$(grep -E '^\s+ff0:' /tmp/k145_one.asm | head -1)
  echo "$line" | grep -qE 'ldr\s+x[0-9]+, \[x[0-9]+, #0x8\]' || continue
  name=$(basename "$(dirname "$f")")
  echo "  $name"
  echo "    $line"
done < /tmp/k145_files.txt
