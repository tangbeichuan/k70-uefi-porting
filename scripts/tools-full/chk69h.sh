set +e
cd /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
ls
echo "=== FVMAIN.Fv.txt 里 HALIOMMU / PmicDxe ==="
grep -inE 'HALIOMMU|PmicDxe' FVMAIN.Fv.txt 2>/dev/null | head
echo "=== 模块名列表前 40 行 ==="
head -40 FVMAIN.Fv.txt 2>/dev/null