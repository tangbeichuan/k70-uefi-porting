set +e
echo "=== 含 0xcec 的指令 ==="
grep -n '0xcec' /tmp/ufs.asm | head -10
echo "=== 含 0x1bc 字样的 ==="
grep -n '#0x1bc' /tmp/ufs.asm | head -10
echo "=== LocateProtocol 调用模式附近（ldr x8,[x8,#0x140]）==="
grep -n 'ldr	x8, \[x8, #0x140\]' /tmp/ufs.asm | head -10