#!/bin/bash
# dump disassembly ranges of interest
A=/tmp/pmic/pmic.asm
show() {
  echo "===== $1 - $2 ====="
  grep -n "^\s*$1:" "$A" | head -1
  awk -v s="$1" -v e="$2" '
    /^\s*[0-9a-f]+:/ {
      addr=$1; sub(":","",addr); a=strtonum("0x" addr);
      if (a>=strtonum("0x" s) && a<=strtonum("0x" e)) print
    }' "$A"
}
show 1e2ac 1e420
show 1f0e0 1f1d0
show 9920 99a0
show 288e0 28960
