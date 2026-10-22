set +e
echo "=== QcomPkg.dec 里 IOMMU 相关 GUID ==="
grep -n -i 'iommu' /root/k70/uefi/Silicon/Qualcomm/QcomPkg/QcomPkg.dec | head
echo "=== HALIOMMU 安装协议的 GUID（Instal… 前 adrp/add 到 .rdata）==="
python3 - <<'PY'
import subprocess,re,io
d=open('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi','rb').read()
asm=subprocess.run(['llvm-objdump','-d','--no-show-raw-insn','/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi'],capture_output=True,text=True).stdout.splitlines()
# 找所有 adrp x,0x1?000 后紧跟 add #imm 的“取地址”序列，收集偏移
cands=[]
for i,l in enumerate(asm):
    m=re.search(r'adrp\s+(x\d+), (0x[0-9a-f]+)', l)
    if not m: continue
    reg,base=m.group(1),int(m.group(2),16)
    for j in range(i+1,min(i+4,len(asm))):
        m2=re.search(r'add\s+'+reg+r', '+reg+r', #(0x[0-9a-f]+)', asm[j])
        if m2:
            off=base+int(m2.group(1),16)
            if 0x1c000<=off<0x20000: cands.append((l.split(':')[0].strip(),off))
            break
seen=set()
for pc,off in cands:
    if off in seen: continue
    seen.add(off)
    g=d[off:off+16]
    if len(g)==16:
        import uuid
        u=uuid.UUID(bytes_le=g)
        print(pc, hex(off), u)
PY