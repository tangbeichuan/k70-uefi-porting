set +e
cd /root/k70/uefi/Platforms/Xiaomi/vermeerPkg
cp Include/APRIORI.inc /tmp/APRIORI.inc.bak69
python3 - <<'PY'
import io
p='Include/APRIORI.inc'
s=io.open(p,encoding='utf-8',errors='replace').read().splitlines(keepends=True)
out=[];n=0
for line in s:
    low=line.lower()
    if low.lstrip().startswith('inf') and ('halionmudxe' in low or 'pmicdxela' in low):
        out.append('# [manual69] '+line); n+=1
    else:
        out.append(line)
io.open(p,'w',encoding='utf-8').write(''.join(out))
print('commented',n)
PY
grep -n -i 'halio\|pmicdxela' Include/APRIORI.inc | head
cd /root/k70/uefi
source /root/k70/venv/bin/activate
python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -4
echo "=== FVMAIN 里还有 HALIOMMU(9A00771F) 吗 ==="
grep -ic '9A00771F' Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt
grep -ic 'PmicDxe\|6D4A9CF7' Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt
sha256sum Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd