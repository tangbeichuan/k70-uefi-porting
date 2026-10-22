set +e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi
ls -l "$F"
python3 - "$F" <<'PY'
import sys,struct,re
d=open(sys.argv[1],'rb').read()
for pat in (b'IOMMU LocateProtocol failed', b'ShmConfig'):
    i=d.find(pat)
    print(pat, '->', hex(i) if i>=0 else 'not found')
i=d.find(b'IOMMU LocateProtocol failed')
print('ctx:', d[max(0,i-32):i+48])
PY
llvm-objdump -d --no-show-raw-insn "$F" > /tmp/ufs.asm 2>/dev/null
wc -l /tmp/ufs.asm
echo "=== 找 adrp/add 指向 0x1c000 附近且带 GUID 的位置（列出 .text 里所有 adrp xN, 0x1c000）==="
grep -n "adrp.*0x1c000" /tmp/ufs.asm | head
echo "=== 若字符串偏移已知，找引用它的 adrp/add ==="
python3 - "$F" <<'PY'
import sys
d=open(sys.argv[1],'rb').read()
i=d.find(b'IOMMU LocateProtocol failed')
print('string vaddr guess (file==rva):', hex(i))
PY