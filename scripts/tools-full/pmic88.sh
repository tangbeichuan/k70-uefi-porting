set +e
grep -n 'str.*\[x21, #0x88\]' /tmp/pmic.asm | head
echo "=== writes to 0x88 (any reg) ==="
grep -nE 'str\s+x[0-9]+, \[x[0-9]+, #0x88\]' /tmp/pmic.asm | head